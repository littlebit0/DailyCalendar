import 'dart:io';

import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/migration/todo_database_migration_service.dart';
import 'package:daily/core/sync/sync_version.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/domain/event_deletion.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late File databaseFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('daily-todo-migration-');
    databaseFile = File('${directory.path}/daily.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  for (final hasLmsColumns in [false, true]) {
    test('schema 8 adds LMS columns locally without cloud work '
        '(existing metadata: $hasLmsColumns)', () async {
      final timestamp = DateTime.utc(2026, 9, 26, 0, 0, 0, 123, 456);
      final synced = _event(id: 'synced').copyWith(
        memo: '개인 메모',
        location: '강의실',
        url: 'https://example.com/personal',
        weather: '맑음',
        createdAt: timestamp.subtract(const Duration(days: 1)),
        updatedAt: timestamp,
        completed: true,
        reminderMinutesBeforeList: [10, 30],
        alarmEnabled: true,
        showDday: true,
        deviceId: 'existing-device',
      );
      final events = [
        synced,
        synced.copyWith(id: 'pending', syncStatus: 'pending'),
        synced.copyWith(
          id: 'soft-deleted',
          syncStatus: 'pending',
          deletedAt: timestamp.add(const Duration(microseconds: 7)),
        ),
        if (hasLmsColumns)
          synced.copyWith(
            id: 'lms:known-source',
            lms: LmsEventMetadata(
              schoolId: 'smu',
              ownerId: 'owner@example.com',
              lmsUserId: 'student-1',
              courseId: 'course-1',
              courseTitle: '수업',
              activityType: 'assignment',
              activityId: 'activity-1',
              sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=1',
              dueAt: timestamp,
              submissionStatus: '제출 완료',
            ),
          ),
      ];
      final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      final repository = DriftEventRepository(database);
      for (final event in events) {
        await repository.save(event);
      }
      await database.close();

      final before = sqlite3.open(databaseFile.path);
      late final List<Map<String, Object?>> eventRows;
      late final List<Map<String, Object?>> deletionRows;
      try {
        before.execute(
          'INSERT INTO sync_event_deletions '
          '(id, deleted_at, pending, lms_owner_id) VALUES (?, ?, ?, ?)',
          [
            hasLmsColumns ? 'lms:compact-pending' : 'compact-pending',
            timestamp.toIso8601String(),
            1,
            hasLmsColumns ? 'owner@example.com' : null,
          ],
        );
        before.execute(
          'INSERT INTO sync_event_deletions '
          '(id, deleted_at, pending) VALUES (?, ?, 0)',
          ['compact-synced', timestamp.toIso8601String()],
        );
        if (!hasLmsColumns) {
          before.execute('ALTER TABLE event_records DROP COLUMN lms_metadata');
          before.execute(
            'ALTER TABLE sync_event_deletions DROP COLUMN lms_owner_id',
          );
        }
        before.execute('PRAGMA user_version = 8');
        eventRows = _storedRows(before, 'event_records');
        deletionRows = _storedRows(before, 'sync_event_deletions');
      } finally {
        before.close();
      }

      var restoreCalls = 0;
      var deletionCalls = 0;
      var backupCalls = 0;
      final stages = <TodoMigrationStage>[];
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => databaseFile,
        hasLinkedGoogleAccount: () => true,
        loadRemoteEvents: () async {
          restoreCalls++;
          return null;
        },
        remoteDeletionRecords: () {
          deletionCalls++;
          return const [];
        },
        backupMigratedEvents: () async {
          backupCalls++;
          throw StateError('Cloud unavailable during additive migration');
        },
      );
      addTearDown(service.dispose);
      service.progress.addListener(
        () => stages.add(service.progress.value.stage),
      );

      final result = await service.migrateIfNeeded();

      expect(result.migrated, isTrue);
      expect(result.backupPending, isFalse);
      expect(restoreCalls, 0);
      expect(deletionCalls, 0);
      expect(backupCalls, 0);
      expect(stages, contains(TodoMigrationStage.snapshotting));
      expect(stages, contains(TodoMigrationStage.validating));
      expect(stages, isNot(contains(TodoMigrationStage.restoring)));
      expect(stages, isNot(contains(TodoMigrationStage.backingUp)));

      final snapshot = sqlite3.open(result.snapshotPath!);
      addTearDown(snapshot.close);
      expect(_userVersion(snapshot), 8);
      expect(_storedRows(snapshot, 'event_records'), eventRows);
      expect(_storedRows(snapshot, 'sync_event_deletions'), deletionRows);

      final migrated = sqlite3.open(databaseFile.path);
      addTearDown(migrated.close);
      expect(_userVersion(migrated), AppDatabase.currentSchemaVersion);
      expect(_hasColumn(migrated, 'lms_metadata'), isTrue);
      expect(
        migrated
            .select('PRAGMA table_info(sync_event_deletions)')
            .any((row) => row['name'] == 'lms_owner_id'),
        isTrue,
      );
      expect(
        _storedRows(
          migrated,
          'event_records',
          omit: hasLmsColumns ? const [] : ['lms_metadata'],
        ),
        eventRows,
      );
      expect(
        _storedRows(
          migrated,
          'sync_event_deletions',
          omit: hasLmsColumns ? const [] : ['lms_owner_id'],
        ),
        deletionRows,
      );
      expect(
        migrated.select('SELECT sync_status FROM event_records WHERE id = ?', [
          'synced',
        ]).single['sync_status'],
        'synced',
      );
      if (!hasLmsColumns) {
        expect(
          migrated.select(
            'SELECT id FROM event_records WHERE lms_metadata IS NOT NULL',
          ),
          isEmpty,
        );
        expect(
          migrated.select(
            'SELECT id FROM sync_event_deletions WHERE lms_owner_id IS NOT NULL',
          ),
          isEmpty,
        );
      }
      expect((await service.migrateIfNeeded()).migrated, isFalse);
      expect(restoreCalls + deletionCalls + backupCalls, 0);
    });
  }

  test(
    'migrates existing events to incomplete Todo items with a snapshot',
    () async {
      await _createSchemaSixDatabase(databaseFile, [_event(id: 'local')]);
      var backupCalls = 0;
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => databaseFile,
        hasLinkedGoogleAccount: () => false,
        loadRemoteEvents: () async => null,
        backupMigratedEvents: () async => backupCalls += 1,
      );
      addTearDown(service.dispose);

      final result = await service.migrateIfNeeded();

      expect(result.migrated, isTrue);
      expect(result.backupPending, isFalse);
      expect(result.snapshotPath, isNotNull);
      expect(await File(result.snapshotPath!).exists(), isTrue);
      expect(backupCalls, 0);
      final raw = sqlite3.open(databaseFile.path);
      addTearDown(raw.close);
      expect(_userVersion(raw), AppDatabase.currentSchemaVersion);
      expect(_hasColumn(raw, 'completed'), isTrue);
      final row = raw.select(
        'SELECT completed, sync_status FROM event_records WHERE id = ?',
        ['local'],
      ).single;
      expect(row['completed'], 0);
      expect(row['sync_status'], 'pending');
    },
  );

  test(
    'merges a newer remote event before migration and backs it up',
    () async {
      final local = _event(id: 'shared', syncStatus: 'synced');
      await _createSchemaSixDatabase(databaseFile, [local]);
      var backupCalls = 0;
      final remote = local.copyWith(
        title: '원격 최신 일정',
        updatedAt: local.updatedAt.add(const Duration(hours: 1)),
        completed: true,
        syncStatus: 'synced',
      );
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => databaseFile,
        hasLinkedGoogleAccount: () => true,
        loadRemoteEvents: () async => [remote],
        backupMigratedEvents: () async => backupCalls += 1,
      );
      addTearDown(service.dispose);

      final result = await service.migrateIfNeeded();

      expect(result.backupPending, isFalse);
      expect(backupCalls, 1);
      final raw = sqlite3.open(databaseFile.path);
      addTearDown(raw.close);
      final row = raw.select(
        'SELECT title, completed, sync_status FROM event_records WHERE id = ?',
        ['shared'],
      ).single;
      expect(row['title'], '원격 최신 일정');
      expect(row['completed'], 1);
      expect(row['sync_status'], 'pending');
    },
  );

  test(
    'migration carries compact remote deletions without resurrecting rows',
    () async {
      final local = _event(id: 'deleted-remotely', syncStatus: 'pending');
      await _createSchemaSixDatabase(databaseFile, [local]);
      final deletion = EventDeletion(
        id: local.id,
        deletedAt: local.updatedAt.add(const Duration(days: 1)),
        pending: false,
      );
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => databaseFile,
        hasLinkedGoogleAccount: () => true,
        loadRemoteEvents: () async => [],
        remoteDeletionRecords: () => [deletion],
        backupMigratedEvents: () async {},
      );
      addTearDown(service.dispose);
      final result = await service.migrateIfNeeded();
      expect(result.migrated, isTrue);
      final raw = sqlite3.open(databaseFile.path);
      addTearDown(raw.close);
      expect(raw.select('SELECT * FROM event_records'), isEmpty);
      expect(
        raw.select('SELECT id FROM sync_event_deletions').single['id'],
        local.id,
      );
      final snapshot = sqlite3.open(result.snapshotPath!);
      addTearDown(snapshot.close);
      expect(
        snapshot.select('SELECT id FROM event_records').single['id'],
        local.id,
      );
    },
  );

  test(
    'migration uses the normal deterministic rule for equal timestamps',
    () async {
      final local = _event(id: 'tie').copyWith(title: 'A');
      final remote = local.copyWith(title: 'Z');
      expect(compareEventVersions(remote, local), greaterThan(0));
      await _createSchemaSixDatabase(databaseFile, [local]);
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => databaseFile,
        hasLinkedGoogleAccount: () => true,
        loadRemoteEvents: () async => [remote],
        backupMigratedEvents: () async {},
      );
      addTearDown(service.dispose);
      await service.migrateIfNeeded();
      final raw = sqlite3.open(databaseFile.path);
      addTearDown(raw.close);
      expect(
        raw.select('SELECT title FROM event_records').single['title'],
        'Z',
      );
    },
  );

  test('newer remote changes replace older pending local changes', () async {
    final local = _event(id: 'pending-local', syncStatus: 'pending');
    await _createSchemaSixDatabase(databaseFile, [local]);
    final remote = local.copyWith(
      title: '원격 일정',
      updatedAt: local.updatedAt.add(const Duration(days: 1)),
      completed: true,
      syncStatus: 'synced',
    );
    final service = TodoDatabaseMigrationService(
      databaseFile: () async => databaseFile,
      hasLinkedGoogleAccount: () => true,
      loadRemoteEvents: () async => [remote],
      backupMigratedEvents: () async {},
    );
    addTearDown(service.dispose);

    await service.migrateIfNeeded();

    final raw = sqlite3.open(databaseFile.path);
    addTearDown(raw.close);
    final row = raw.select(
      'SELECT title, completed FROM event_records WHERE id = ?',
      ['pending-local'],
    ).single;
    expect(row['title'], remote.title);
    expect(row['completed'], 1);
  });

  test(
    'blocks startup and preserves the original when remote restore fails',
    () async {
      await _createSchemaSixDatabase(databaseFile, [_event(id: 'preserved')]);
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => databaseFile,
        hasLinkedGoogleAccount: () => true,
        loadRemoteEvents: () async => null,
        backupMigratedEvents: () async {},
      );
      addTearDown(service.dispose);

      await expectLater(
        service.migrateIfNeeded(),
        throwsA(
          isA<TodoMigrationException>().having(
            (error) => error.stage,
            'stage',
            TodoMigrationStage.restoring,
          ),
        ),
      );

      final raw = sqlite3.open(databaseFile.path);
      addTearDown(raw.close);
      expect(_userVersion(raw), 6);
      expect(_hasColumn(raw, 'completed'), isFalse);
      expect(
        raw.select('SELECT title FROM event_records WHERE id = ?', [
          'preserved',
        ]).single['title'],
        '기존 일정',
      );
    },
  );

  test(
    'keeps migrated rows pending when immediate cloud backup fails',
    () async {
      await _createSchemaSixDatabase(databaseFile, [
        _event(id: 'backup-retry', syncStatus: 'synced'),
      ]);
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => databaseFile,
        hasLinkedGoogleAccount: () => true,
        loadRemoteEvents: () async => const [],
        backupMigratedEvents: () async => throw StateError('offline'),
      );
      addTearDown(service.dispose);

      final result = await service.migrateIfNeeded();

      expect(result.migrated, isTrue);
      expect(result.backupPending, isTrue);
      final raw = sqlite3.open(databaseFile.path);
      addTearDown(raw.close);
      expect(
        raw.select('SELECT sync_status FROM event_records WHERE id = ?', [
          'backup-retry',
        ]).single['sync_status'],
        'pending',
      );
    },
  );
}

Future<void> _createSchemaSixDatabase(
  File file,
  List<CalendarEvent> events,
) async {
  final database = AppDatabase.forTesting(NativeDatabase(file));
  final repository = DriftEventRepository(database);
  for (final event in events) {
    await repository.save(event);
  }
  await database.close();

  final raw = sqlite3.open(file.path);
  try {
    raw.execute('ALTER TABLE event_records DROP COLUMN completed');
    raw.execute('PRAGMA user_version = 6');
  } finally {
    raw.close();
  }
}

CalendarEvent _event({required String id, String syncStatus = 'synced'}) {
  final now = DateTime(2026, 8, 21, 9);
  return CalendarEvent(
    id: id,
    title: '기존 일정',
    startAt: now,
    endAt: now.add(const Duration(hours: 1)),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: now,
    updatedAt: now,
    syncStatus: syncStatus,
  );
}

int _userVersion(Database database) {
  return database.select('PRAGMA user_version').single.values.single as int;
}

bool _hasColumn(Database database, String column) {
  return database
      .select('PRAGMA table_info(event_records)')
      .any((row) => row['name'] == column);
}

List<Map<String, Object?>> _storedRows(
  Database database,
  String table, {
  List<String> omit = const [],
}) => [
  for (final row in database.select('SELECT * FROM $table ORDER BY id'))
    Map<String, Object?>.from(row)..removeWhere((key, _) => omit.contains(key)),
];
