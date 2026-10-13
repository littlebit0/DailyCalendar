import 'dart:io';
import '../../../core/diagnostics/startup_timing.dart';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [EventRecords])
class AppDatabase extends _$AppDatabase {
  static const currentSchemaVersion = 9;
  static const createDeletionTable = '''
    CREATE TABLE IF NOT EXISTS sync_event_deletions (
      id TEXT PRIMARY KEY NOT NULL,
      deleted_at TEXT NOT NULL,
      pending INTEGER NOT NULL DEFAULT 1,
      lms_owner_id TEXT
    )
  ''';

  final _openClock = Stopwatch()..start();
  final bool _recordStartupTiming;

  AppDatabase() : _recordStartupTiming = true, super(_openConnection());

  AppDatabase.forTesting(super.executor) : _recordStartupTiming = true;

  AppDatabase.forMigration(super.executor) : _recordStartupTiming = false;

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
      },
      onUpgrade: (migrator, from, to) async {
        await repairEventSchema(migrator, rebuild: from < 6);
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
