import 'dart:io';

import 'package:daily/features/events/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schema 9 preserves events and adds sync metadata without fabricated times',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'daily-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/daily.sqlite');

      final oldDatabase = AppDatabase.forTesting(NativeDatabase(file));
      await oldDatabase.customStatement(
        '''
      INSERT INTO event_records (
        id, title, start_at, end_at, color_value, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
        [
          'kept-event',
          '보존할 일정',
          DateTime(2026, 7, 30).millisecondsSinceEpoch ~/ 1000,
          DateTime(2026, 7, 30, 1).millisecondsSinceEpoch ~/ 1000,
          0xff2563eb,
          DateTime(2026, 7, 29).millisecondsSinceEpoch ~/ 1000,
          DateTime(2026, 7, 29).millisecondsSinceEpoch ~/ 1000,
        ],
      );
      await oldDatabase.customStatement(
        'ALTER TABLE event_records ADD COLUMN sensitive INTEGER NOT NULL DEFAULT 0',
      );
      await oldDatabase.customStatement(
        'UPDATE event_records SET sensitive = 1 WHERE id = ?',
        ['kept-event'],
      );
      await oldDatabase.customStatement('PRAGMA user_version = 5');
      await oldDatabase.close();

      final database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(database.close);
      final columns = await database
          .customSelect('PRAGMA table_info(event_records)')
          .get();
      final names = columns.map((row) => row.read<String>('name')).toSet();
      final event = await database
          .customSelect('SELECT id, title, completed FROM event_records')
          .getSingle();
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();

      expect(names, isNot(contains('sensitive')));
      expect(event.read<String>('id'), 'kept-event');
      expect(event.read<String>('title'), '보존할 일정');
      expect(event.read<int>('completed'), 0);
      expect(
        version.read<int>('user_version'),
        AppDatabase.currentSchemaVersion,
      );
      expect(names, contains('sync_timestamp_details'));
      expect(names, contains('lms_metadata'));
      expect(
        await database.customSelect('SELECT * FROM sync_event_deletions').get(),
        isEmpty,
      );
    },
  );
}
