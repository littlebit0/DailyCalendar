import 'dart:io';
import '../../../core/diagnostics/startup_timing.dart';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/sync/sync_version.dart';
import '../domain/calendar_event.dart';
import 'event_mapper.dart';

part 'app_database.g.dart';

class EventRecords extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get memo => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get weather => text().nullable()();
  TextColumn get lmsMetadata => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().withDefault(const Constant('basic'))();
  IntColumn get colorValue => integer()();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  TextColumn get reminderMinutesBeforeList =>
      text().withDefault(const Constant('[]'))();
  TextColumn get recurrenceFrequency =>
      text().withDefault(const Constant('none'))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();
  IntColumn get recurrenceCount => integer().nullable()();
  IntColumn get recurrenceAnchorDay => integer().nullable()();
  // RFC 5545 BYDAY/BYMONTHDAY/BYMONTH/BYSETPOS conditions as JSON.
  TextColumn get recurrenceDetails => text().nullable()();
  TextColumn get recurrenceExcludedDates =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncTimestampDetails => text().nullable()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  BoolColumn get showDday => boolean().withDefault(const Constant(false))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  BoolColumn get alarmEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get allDayAlarmMinutes =>
      integer().withDefault(const Constant(9 * 60))();
  IntColumn get alarmMinutesBefore =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get alarmCustomAt => dateTime().nullable()();
  // Schema 13: JSON lists of every alarm trigger (minutes, UTC ISO times).
  // Null keeps the single legacy trigger above, which always holds the
  // earliest one for older app versions.
  TextColumn get alarmMinutesBeforeList => text().nullable()();
  TextColumn get alarmCustomAtList => text().nullable()();
  BoolColumn get showOvernightOnFollowingDays =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [EventRecords])
class AppDatabase extends _$AppDatabase {
  static const currentSchemaVersion = 15;
  static const createDeletionTable = '''
    CREATE TABLE IF NOT EXISTS sync_event_deletions (
      id TEXT PRIMARY KEY NOT NULL,
      deleted_at TEXT NOT NULL,
      pending INTEGER NOT NULL DEFAULT 1,
      lms_owner_id TEXT
    )
  ''';
  // Schema 14: device-local copy of Drive v2 event files, keyed by Drive file
  // id and the content md5. Never uploaded; a listed md5 that matches lets
  // sync reuse the body instead of downloading it again.
  static const createRemoteEventFileTable = '''
    CREATE TABLE IF NOT EXISTS sync_remote_event_files (
      file_id TEXT PRIMARY KEY NOT NULL,
      md5_checksum TEXT NOT NULL,
      body TEXT NOT NULL
    )
  ''';

  final _openClock = Stopwatch()..start();
  final bool _recordStartupTiming;

  /// [legacyShowOvernightOnFollowingDays] is the removed app-wide setting
  /// (#696). Upgrading from schema 13 or older copies it into every existing
  /// event so their display does not change.
  AppDatabase({this.legacyShowOvernightOnFollowingDays = true})
    : _recordStartupTiming = true,
      super(_openConnection());

  AppDatabase.forTesting(
    super.executor, {
    this.legacyShowOvernightOnFollowingDays = true,
  }) : _recordStartupTiming = true;

  final bool legacyShowOvernightOnFollowingDays;

  AppDatabase.forMigration(
    super.executor, {
    this.legacyShowOvernightOnFollowingDays = true,
  }) : _recordStartupTiming = false;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (_) async {
        _openClock.stop();
        if (_recordStartupTiming) {
          StartupTiming.mark(
            StartupStage.database,
            durationUs: _openClock.elapsedMicroseconds,
          );
        }
      },
      onCreate: (migrator) async {
        await migrator.createAll();
        await customStatement(createDeletionTable);
        await customStatement(createRemoteEventFileTable);
      },
      onUpgrade: (migrator, from, to) async {
        // user_version is written only after this callback, so an interrupted
        // upgrade seeds again before any new event can exist.
        await repairEventSchema(
          migrator,
          rebuild: from < 6,
          seedOvernightDisplay: from < 15,
        );
      },
    );
  }

  Future<void> repairCurrentEventSchema({bool rebuild = false}) =>
      transaction(() => repairEventSchema(Migrator(this), rebuild: rebuild));

  // Shared by Drift upgrades and the bootstrap's snapshot-based repair. Add
  // only missing columns: stored categories, alarms and recurrence stay intact.
  Future<void> repairEventSchema(
    Migrator migrator, {
    bool rebuild = false,
    bool seedOvernightDisplay = false,
  }) async {
    final columns = await customSelect(
      'PRAGMA table_info(event_records)',
    ).get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    for (final column in eventRecords.$columns) {
      if (!names.contains(column.$name)) {
        await migrator.addColumn(eventRecords, column);
      }
    }
    // Schema 15 (#791) moved the app-wide choice onto each event.
    if (seedOvernightDisplay ||
        !names.contains('show_overnight_on_following_days')) {
      await _seedOvernightDisplay();
    }
    if (!names.contains('reminder_minutes_before_list')) {
      await customStatement(
        "UPDATE event_records SET reminder_minutes_before_list = '[' || reminder_minutes_before || ']' WHERE reminder_minutes_before IS NOT NULL",
      );
    }
    // Schema 6 removed the old sensitive column and establishes the current
    // defaults/constraints. Repair mislabeled current databases the same way.
    if (rebuild) {
      await migrator.alterTable(TableMigration(eventRecords));
    }
    await customStatement(createDeletionTable);
    await customStatement(createRemoteEventFileTable);
    final deletionColumns = await customSelect(
      'PRAGMA table_info(sync_event_deletions)',
    ).get();
    if (!deletionColumns.any(
      (row) => row.read<String>('name') == 'lms_owner_id',
    )) {
      await customStatement(
        'ALTER TABLE sync_event_deletions ADD COLUMN lms_owner_id TEXT',
      );
    }
  }

  Future<void> _seedOvernightDisplay() async {
    final shown = legacyShowOvernightOnFollowingDays;
    // Off enters each event's fingerprint: re-sign the precise timestamps
    // verified before the change so they are not dropped to whole seconds.
    final details = shown
        ? const <String, String>{}
        : {
            for (final row in await (select(
              eventRecords,
            )..where((row) => row.syncTimestampDetails.isNotNull())).get())
              row.id: encodeSyncTimestamps(
                _verifiedTimestamps(
                  row,
                ).copyWith(showOvernightOnFollowingDays: false),
              ),
          };
    await customStatement(
      'UPDATE event_records SET show_overnight_on_following_days = ?',
      [shown ? 1 : 0],
    );
    for (final entry in details.entries) {
      await customStatement(
        'UPDATE event_records SET sync_timestamp_details = ? WHERE id = ?',
        [entry.value, entry.key],
      );
    }
  }

  // The stored details were signed before seeding (on), or by an interrupted
  // seed (off); whichever verifies restores the sub-second timestamps.
  static CalendarEvent _verifiedTimestamps(EventRecord row) {
    for (final shown in const [true, false]) {
      final event = row
          .copyWith(showOvernightOnFollowingDays: shown)
          .toDomain();
      if (event.createdAt != row.createdAt ||
          event.updatedAt != row.updatedAt ||
          event.deletedAt != row.deletedAt) {
        return event;
      }
    }
    return row.toDomain();
  }

  Future<File> databaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'daily.sqlite'));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'daily.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
