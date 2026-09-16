import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../features/events/data/app_database.dart';
import '../../features/events/data/event_mapper.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_deletion.dart';
import '../sync/sync_version.dart';

enum TodoMigrationStage {
  checking,
  restoring,
  snapshotting,
  migrating,
  validating,
  backingUp,
  complete,
  failed,
}

class TodoMigrationProgress {
  const TodoMigrationProgress(this.stage, this.message);

  final TodoMigrationStage stage;
  final String message;
}

class TodoMigrationResult {
  const TodoMigrationResult({
    required this.migrated,
    required this.backupPending,
    this.snapshotPath,
  });

  final bool migrated;
  final bool backupPending;
  final String? snapshotPath;
}

class TodoMigrationException implements Exception {
  const TodoMigrationException({
    required this.stage,
    required this.message,
    this.cause,
    this.snapshotPath,
  });

  final TodoMigrationStage stage;
  final String message;
  final Object? cause;
  final String? snapshotPath;

  @override
  String toString() => message;
}

class TodoDatabaseMigrationService {
  TodoDatabaseMigrationService({
    required Future<File> Function() databaseFile,
    required bool Function() hasLinkedGoogleAccount,
    required Future<List<CalendarEvent>?> Function() loadRemoteEvents,
    required Future<void> Function() backupMigratedEvents,
    List<EventDeletion> Function()? remoteDeletionRecords,
  }) : _databaseFile = databaseFile,
       _hasLinkedGoogleAccount = hasLinkedGoogleAccount,
       _loadRemoteEvents = loadRemoteEvents,
       _backupMigratedEvents = backupMigratedEvents,
       _remoteDeletionRecords = remoteDeletionRecords ?? (() => const []);

  final Future<File> Function() _databaseFile;
  final bool Function() _hasLinkedGoogleAccount;
  final Future<List<CalendarEvent>?> Function() _loadRemoteEvents;
  final Future<void> Function() _backupMigratedEvents;
  final List<EventDeletion> Function() _remoteDeletionRecords;

  final progress = ValueNotifier<TodoMigrationProgress>(
    const TodoMigrationProgress(TodoMigrationStage.checking, '업데이트 확인 중'),
  );

  Future<TodoMigrationResult> migrateIfNeeded() async {
    File? workingFile;
    String? snapshotPath;
    var stage = TodoMigrationStage.checking;
    try {
      _report(stage, '업데이트 확인 중');
      final databaseFile = await _databaseFile();
      if (!await databaseFile.exists()) {
        return const TodoMigrationResult(migrated: false, backupPending: false);
      }

      final original = sqlite3.open(databaseFile.path);
      late final int originalVersion;
      late final Map<String, CalendarEvent> localStates;
      try {
        originalVersion = _userVersion(original);
        if (originalVersion >= AppDatabase.currentSchemaVersion) {
          return const TodoMigrationResult(
            migrated: false,
            backupPending: false,
          );
        }
        if (!_hasEventTable(original)) {
          return const TodoMigrationResult(
            migrated: false,
            backupPending: false,
          );
        }
        localStates = _readLocalStates(original);
      } finally {
        original.close();
      }

      stage = TodoMigrationStage.restoring;
      _report(stage, '최신 백업을 복원하고 있습니다.');
      final remoteEvents = _hasLinkedGoogleAccount()
          ? await _loadRemoteEvents()
          : const <CalendarEvent>[];
      if (_hasLinkedGoogleAccount() && remoteEvents == null) {
        throw const TodoMigrationException(
          stage: TodoMigrationStage.restoring,
          message: 'Google Drive 복원 정보를 확인하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요.',
        );
      }
      final remoteWinners = _remoteWinners(
        localStates,
        remoteEvents ?? const <CalendarEvent>[],
      );
      final deletions = _hasLinkedGoogleAccount()
          ? _remoteDeletionRecords()
          : const <EventDeletion>[];
      final removedIds = <String>{};

      stage = TodoMigrationStage.snapshotting;
      _report(stage, '안전 스냅샷을 만들고 있습니다.');
      final migrationDirectory = Directory(
        p.join(databaseFile.parent.path, 'Daily Migration Backups'),
      );
      await migrationDirectory.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      final snapshotFile = File(
        p.join(migrationDirectory.path, 'daily-before-todo-$stamp.sqlite'),
      );
      await _createConsistentSnapshot(databaseFile, snapshotFile);
      snapshotPath = snapshotFile.path;

      workingFile = File('${databaseFile.path}.todo-migration');
      if (await workingFile.exists()) {
        await workingFile.delete();
      }
      await snapshotFile.copy(workingFile.path);

      stage = TodoMigrationStage.migrating;
      _report(stage, '일정을 Todo 형식으로 업데이트하고 있습니다.');
      final working = sqlite3.open(workingFile.path);
      try {
        working.execute('BEGIN IMMEDIATE');
        try {
          if (!_hasColumn(working, 'event_records', 'completed')) {
            working.execute(
              'ALTER TABLE event_records '
              'ADD COLUMN completed INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (!_hasColumn(working, 'event_records', 'sync_timestamp_details')) {
            working.execute(
              'ALTER TABLE event_records ADD COLUMN sync_timestamp_details TEXT',
            );
          }
          for (final event in remoteWinners) {
            _upsertRemoteWinner(working, event);
          }
          working.execute(AppDatabase.createDeletionTable);
          for (final deletion in deletions) {
            final candidates = working.select(
              'SELECT * FROM event_records WHERE id = ?',
              [deletion.id],
            );
            if (candidates.isEmpty ||
                !eventChangedAt(
                  _readEventRow(candidates.single),
                ).isAfter(deletion.deletedAt)) {
              working.execute('DELETE FROM event_records WHERE id = ?', [
                deletion.id,
              ]);
              removedIds.add(deletion.id);
            }
            working.execute(
              'INSERT OR REPLACE INTO sync_event_deletions (id, deleted_at, pending) VALUES (?, ?, 0)',
              [deletion.id, deletion.deletedAt.toUtc().toIso8601String()],
            );
          }
          // A schema-changing release backs up every event after validation.
          working.execute("UPDATE event_records SET sync_status = 'pending'");
          working.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          working.execute('COMMIT');
        } on Object {
          working.execute('ROLLBACK');
          rethrow;
        }

        stage = TodoMigrationStage.validating;
        _report(stage, '업데이트 결과를 확인하고 있습니다.');
        _validateMigratedDatabase(
          working,
          localIds: localStates.keys.where((id) => !removedIds.contains(id)),
          remoteIds:
              remoteEvents
                  ?.map((event) => event.id)
                  .where((id) => !removedIds.contains(id)) ??
              const [],
        );
      } finally {
        working.close();
      }

      await _replaceDatabaseAtomically(databaseFile, workingFile);
      workingFile = null;

      var backupPending = false;
      if (_hasLinkedGoogleAccount()) {
        stage = TodoMigrationStage.backingUp;
        _report(stage, '업데이트된 일정을 백업하고 있습니다.');
        try {
          await _backupMigratedEvents();
        } on Object {
          // Every row remains pending, so lifecycle sync can retry safely.
          backupPending = true;
        }
      }

      _report(TodoMigrationStage.complete, '업데이트가 완료되었습니다.');
      return TodoMigrationResult(
        migrated: true,
        backupPending: backupPending,
        snapshotPath: snapshotPath,
      );
    } on TodoMigrationException {
      _report(TodoMigrationStage.failed, '업데이트를 완료하지 못했습니다.');
      rethrow;
    } on Object catch (error) {
      _report(TodoMigrationStage.failed, '업데이트를 완료하지 못했습니다.');
      throw TodoMigrationException(
        stage: stage,
        message: '데이터 업데이트 중 문제가 발생했습니다. 기존 데이터는 변경하지 않았습니다.',
        cause: error,
        snapshotPath: snapshotPath,
      );
    } finally {
      if (workingFile != null && await workingFile.exists()) {
        await workingFile.delete();
      }
    }
  }

  void dispose() => progress.dispose();

  void _report(TodoMigrationStage stage, String message) {
    progress.value = TodoMigrationProgress(stage, message);
  }

  int _userVersion(Database database) {
    return database.select('PRAGMA user_version').single.values.single as int;
  }

  bool _hasEventTable(Database database) {
    return database
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'event_records' LIMIT 1",
        )
        .isNotEmpty;
  }

  bool _hasColumn(Database database, String table, String column) {
    return database
        .select('PRAGMA table_info($table)')
        .any((row) => row['name'] == column);
  }

  Map<String, CalendarEvent> _readLocalStates(Database database) => {
    for (final row in database.select('SELECT * FROM event_records'))
      row['id'] as String: _readEventRow(row),
  };

  CalendarEvent _readEventRow(Map<String, Object?> row) => EventRecord(
    id: row['id'] as String,
    title: row['title'] as String,
    memo: row['memo'] as String?,
    location: row['location'] as String?,
    url: row['url'] as String?,
    weather: row['weather'] as String?,
    startAt: _dateFromSql(row['start_at'])!,
    endAt: _dateFromSql(row['end_at'])!,
    allDay: row['all_day'] == 1,
    category: row['category'] as String? ?? 'basic',
    colorValue: row['color_value'] as int,
    reminderMinutesBefore: row['reminder_minutes_before'] as int?,
    reminderMinutesBeforeList:
        row['reminder_minutes_before_list'] as String? ??
        jsonEncode(
          row['reminder_minutes_before'] == null
              ? []
              : [row['reminder_minutes_before']],
        ),
    recurrenceFrequency: row['recurrence_frequency'] as String? ?? 'none',
    recurrenceInterval: row['recurrence_interval'] as int? ?? 1,
    recurrenceUntil: _dateFromSql(row['recurrence_until']),
    recurrenceCount: row['recurrence_count'] as int?,
    recurrenceExcludedDates:
        row['recurrence_excluded_dates'] as String? ?? '[]',
    createdAt: _dateFromSql(row['created_at'])!,
    updatedAt: _dateFromSql(row['updated_at'])!,
    deletedAt: _dateFromSql(row['deleted_at']),
    syncTimestampDetails: row['sync_timestamp_details'] as String?,
    deviceId: row['device_id'] as String? ?? '',
    syncStatus: row['sync_status'] as String? ?? 'pending',
    showDday: row['show_dday'] == 1,
    completed: row['completed'] == 1,
    alarmEnabled: row['alarm_enabled'] == 1,
    allDayAlarmMinutes: row['all_day_alarm_minutes'] as int? ?? 540,
  ).toDomain();

  List<CalendarEvent> _remoteWinners(
    Map<String, CalendarEvent> localStates,
    List<CalendarEvent> remoteEvents,
  ) => [
    for (final remote in remoteEvents)
      if (localStates[remote.id] == null ||
          compareEventVersions(remote, localStates[remote.id]!) > 0)
        remote,
  ];

  Future<void> _createConsistentSnapshot(
    File sourceFile,
    File targetFile,
  ) async {
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    final source = sqlite3.open(sourceFile.path);
    final target = sqlite3.open(targetFile.path);
    try {
      await source.backup(target, nPage: -1).drain<void>();
    } finally {
      target.close();
      source.close();
    }
  }

  void _upsertRemoteWinner(Database database, CalendarEvent event) {
    final normalized = event.normalizeAllDayBounds();
    database.execute(
      '''
      INSERT INTO event_records (
        id, title, memo, location, url, weather, start_at, end_at, all_day,
        category, color_value, reminder_minutes_before,
        reminder_minutes_before_list, recurrence_frequency,
        recurrence_interval, recurrence_until, recurrence_count,
        recurrence_excluded_dates, created_at, updated_at, deleted_at,
        device_id, sync_status, show_dday, completed, alarm_enabled,
        all_day_alarm_minutes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        memo = excluded.memo,
        location = excluded.location,
        url = excluded.url,
        weather = excluded.weather,
        start_at = excluded.start_at,
        end_at = excluded.end_at,
        all_day = excluded.all_day,
        category = excluded.category,
        color_value = excluded.color_value,
        reminder_minutes_before = excluded.reminder_minutes_before,
        reminder_minutes_before_list = excluded.reminder_minutes_before_list,
        recurrence_frequency = excluded.recurrence_frequency,
        recurrence_interval = excluded.recurrence_interval,
        recurrence_until = excluded.recurrence_until,
        recurrence_count = excluded.recurrence_count,
        recurrence_excluded_dates = excluded.recurrence_excluded_dates,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at,
        device_id = excluded.device_id,
        sync_status = excluded.sync_status,
        show_dday = excluded.show_dday,
        completed = excluded.completed,
        alarm_enabled = excluded.alarm_enabled,
        all_day_alarm_minutes = excluded.all_day_alarm_minutes
      ''',
      [
        normalized.id,
        normalized.title,
        normalized.memo,
        normalized.location,
        normalized.url,
        normalized.weather,
        _dateToSql(normalized.startAt),
        _dateToSql(normalized.endAt),
        normalized.allDay ? 1 : 0,
        _storedCategory(normalized),
        normalized.colorValue,
        normalized.reminderMinutesBefore,
        jsonEncode(normalized.reminderMinutesBeforeList),
        normalized.recurrence.frequency.name,
        normalized.recurrence.interval,
        normalized.recurrence.until == null
            ? null
            : _dateToSql(normalized.recurrence.until!),
        normalized.recurrence.count,
        jsonEncode(
          normalized.recurrence.excludedDates
              .map((date) => DateTime(date.year, date.month, date.day))
              .map((date) => date.toIso8601String())
              .toList(),
        ),
        _dateToSql(normalized.createdAt),
        _dateToSql(normalized.updatedAt),
        normalized.deletedAt == null ? null : _dateToSql(normalized.deletedAt!),
        normalized.deviceId,
        'pending',
        normalized.showDday ? 1 : 0,
        normalized.completed ? 1 : 0,
        normalized.alarmEnabled ? 1 : 0,
        normalized.allDayAlarmMinutes,
      ],
    );
    database.execute(
      'UPDATE event_records SET sync_timestamp_details = ? WHERE id = ?',
      [encodeSyncTimestamps(normalized), normalized.id],
    );
  }

  void _validateMigratedDatabase(
    Database database, {
    required Iterable<String> localIds,
    required Iterable<String> remoteIds,
  }) {
    if (_userVersion(database) != AppDatabase.currentSchemaVersion ||
        !_hasColumn(database, 'event_records', 'completed')) {
      throw StateError('Todo schema validation failed.');
    }
    final expectedIds = {...localIds, ...remoteIds};
    final actualIds = database
        .select('SELECT id FROM event_records')
        .map((row) => row['id'] as String)
        .toSet();
    if (!actualIds.containsAll(expectedIds)) {
      throw StateError('Todo event integrity validation failed.');
    }
    final invalidCompletion = database.select(
      'SELECT id FROM event_records WHERE completed NOT IN (0, 1) LIMIT 1',
    );
    if (invalidCompletion.isNotEmpty) {
      throw StateError('Todo completion validation failed.');
    }
  }

  Future<void> _replaceDatabaseAtomically(
    File databaseFile,
    File workingFile,
  ) async {
    final replacedFile = File('${databaseFile.path}.before-todo-replace');
    if (await replacedFile.exists()) {
      await replacedFile.delete();
    }
    await _removeSidecar(databaseFile.path, '-wal');
    await _removeSidecar(databaseFile.path, '-shm');
    await databaseFile.rename(replacedFile.path);
    try {
      await workingFile.rename(databaseFile.path);
      await replacedFile.delete();
    } on Object {
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
      await replacedFile.rename(databaseFile.path);
      rethrow;
    }
  }

  Future<void> _removeSidecar(String databasePath, String suffix) async {
    final sidecar = File('$databasePath$suffix');
    if (await sidecar.exists()) {
      await sidecar.delete();
    }
  }

  int _dateToSql(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

  DateTime? _dateFromSql(Object? value) {
    if (value is! int) return null;
    final milliseconds = value.abs() > 100000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  String _storedCategory(CalendarEvent event) {
    return event.category.id == 'basic' || event.category.id == 'holiday'
        ? event.category.id
        : event.category.label;
  }
}
