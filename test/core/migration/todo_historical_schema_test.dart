import 'dart:io';
import 'package:daily/core/migration/todo_database_migration_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'historical_event_schema.dart';

void main() {
  test(
    'invalid old values fail without replacing the original database',
    () async {
      final dir = await Directory.systemTemp.createTemp('daily-failed-repair-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/daily.sqlite');
      final raw = sqlite3.open(file.path);
      createHistoricalEventSchema(raw, 9);
      raw.execute('PRAGMA ignore_check_constraints=ON');
      raw.execute('UPDATE event_records SET completed=2');
      raw.execute('ALTER TABLE event_records DROP COLUMN lms_metadata');
      raw.close();
      final originalBytes = await file.readAsBytes();
      final service = TodoDatabaseMigrationService(
        databaseFile: () async => file,
        hasLinkedGoogleAccount: () => false,
        loadRemoteEvents: () async => throw StateError('No cloud expected'),
        backupMigratedEvents: () async => throw StateError('No cloud expected'),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.migrateIfNeeded(),
        throwsA(isA<TodoMigrationException>()),
      );
      expect(await file.readAsBytes(), originalBytes);
      expect(await File('${file.path}.todo-migration').exists(), false);
    },
  );

  for (final version in [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
    for (final remote in ['offline', 'empty', 'winner']) {
      test(
        'historical schema $version with $remote reads and saves after repair',
        () async {
          final dir = await Directory.systemTemp.createTemp(
            'daily-historical-',
          );
          addTearDown(() => dir.delete(recursive: true));
          final file = File('${dir.path}/daily.sqlite');
          final raw = sqlite3.open(file.path);
          createHistoricalEventSchema(raw, version == 9 ? 4 : version);
          if (version == 9) raw.execute('PRAGMA user_version=9');
          raw.close();
          var downloads = 0, uploads = 0;
          final winner = CalendarEvent(
            id: 'remote',
            title: 'Remote',
            startAt: DateTime(2026, 1, 2),
            endAt: DateTime(2026, 1, 2, 1),
            allDay: false,
            category: EventCategory.basic,
            colorValue: 0xff2563eb,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          );
          final service = TodoDatabaseMigrationService(
            databaseFile: () async => file,
            hasLinkedGoogleAccount: () => remote != 'offline',
            loadRemoteEvents: () async {
              downloads++;
              return remote == 'winner' ? [winner] : [];
            },
            backupMigratedEvents: () async {
              uploads++;
            },
          );
          addTearDown(service.dispose);
          final result = await service.migrateIfNeeded();
          expect(result.migrated, true);
          final snapshot = sqlite3.open(result.snapshotPath!);
          expect(
            snapshot.select('PRAGMA user_version').single.values.single,
            version,
          );
          expect(
            snapshot.select('SELECT title FROM event_records').single['title'],
            'Stored',
          );
          snapshot.close();
          final db = AppDatabase.forTesting(NativeDatabase(file));
          try {
            final repo = DriftEventRepository(db);
            final kept = (await repo.findById('kept'))!;
            expect(kept.memo, 'memo');
            expect(kept.location, 'room');
            expect(
              (await db
                      .customSelect(
                        "SELECT category FROM event_records WHERE id='kept'",
                      )
                      .getSingle())
                  .read<String>('category'),
              'personal',
            );
            expect(kept.recurrence.interval, 2);
            expect(
              kept.reminderMinutesBeforeList,
              version >= 4 ? [15, 30] : [15],
            );
            expect(kept.completed, version >= 7 && version != 9);
            expect(kept.alarmEnabled, version >= 5 && version != 9);
            await repo.save(kept.copyWith(title: 'Updated'));
            expect((await repo.findById('kept'))!.title, 'Updated');
            await repo.save(winner.copyWith(id: 'new-defaults'));
            final columns = await db
                .customSelect('PRAGMA table_info(event_records)')
                .get();
            expect(columns.length, db.eventRecords.$columns.length);
            await expectLater(
              db.customStatement('UPDATE event_records SET completed=2'),
              throwsA(isA<SqliteException>()),
            );
            if (version >= 8 && version != 9) {
              expect((await repo.deletionRecords()).single.id, 'old-deletion');
            }
            expect(
              await repo.findById('remote'),
              version < 8 && remote == 'winner' ? isNotNull : isNull,
            );
          } finally {
            await db.close();
          }
          if (version >= 8 || remote == 'offline') {
            expect(downloads, 0);
            expect(uploads, 0);
          } else {
            expect(downloads, 1);
            expect(uploads, 1);
          }
          expect((await service.migrateIfNeeded()).migrated, false);
        },
      );
    }
  }
}
