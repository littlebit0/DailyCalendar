import 'dart:io';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../core/migration/historical_event_schema.dart';

void main() {
  for (final version in [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
    test(
      'normal Drift upgrades explicit schema $version without losing stored values',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'daily-drift-history-',
        );
        final file = File('${dir.path}/daily.sqlite');
        addTearDown(() => dir.delete(recursive: true));
        final raw = sqlite3.open(file.path);
        createHistoricalEventSchema(raw, version);
        raw.close();
        final db = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final repo = DriftEventRepository(db);
          final event = (await repo.findById('kept'))!;
          expect(event.title, 'Stored');
          final row = await db
              .customSelect('SELECT * FROM event_records')
              .getSingle();
          expect(row.read<String>('category'), 'personal');
          expect(
            row.read<String>('reminder_minutes_before_list'),
            version >= 4 ? '[15,30]' : '[15]',
          );
          expect(event.completed, version >= 7);
          await repo.save(event.copyWith(title: 'Saved'));
          expect((await repo.findById('kept'))!.title, 'Saved');
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            AppDatabase.currentSchemaVersion,
          );
        } finally {
          await db.close();
        }
      },
    );
  }
}
