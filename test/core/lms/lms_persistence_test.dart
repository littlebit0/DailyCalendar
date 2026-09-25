import 'dart:convert';
import 'dart:io';

import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/migration/todo_database_migration_service.dart';
import 'package:daily/core/sync/sync_version.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_deletion.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

LmsEventMetadata _metadata() => LmsEventMetadata(
  schoolId: 'smu',
  ownerId: ' Student@Example.COM ',
  lmsUserId: '42',
  courseId: '123',
  courseTitle: '자료구조',
  activityType: 'assignment',
  activityId: '456',
  sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=456',
  openAt: DateTime.parse('2026-09-01T09:00:00+09:00'),
  dueAt: DateTime.utc(2026, 9, 3),
  submissionStatus: '제출 완료',
  progressPercent: 100,
);

CalendarEvent _event() => CalendarEvent(
  id: 'lms:assignment',
  title: '과제',
  memo: '개인 메모',
  startAt: DateTime.utc(2026, 9, 3),
  endAt: DateTime.utc(2026, 9, 3, 1),
  allDay: false,
  category: EventCategory.basic,
  colorValue: EventCategory.basic.colorValue,
  reminderMinutesBeforeList: const [10, 60],
  createdAt: DateTime.utc(2026, 9, 1, 0, 0, 0, 123),
  updatedAt: DateTime.utc(2026, 9, 1, 0, 0, 0, 456),
  lms: _metadata(),
);

void main() {
  test(
    'metadata has stable normalized source identity and no fetch timestamp',
    () {
      final source = _metadata();
      final restored = LmsEventMetadata.fromJson(
        jsonDecode(jsonEncode(source.toJson())) as Map<String, Object?>,
      );
      expect(restored, source);
      expect(source.ownerId, 'student@example.com');
      expect(source.openAt, DateTime.utc(2026, 9, 1));
      expect(source.toJson(), isNot(contains('fetchedAt')));
      expect(source.copyWith().fingerprint, source.fingerprint);
      expect(source.copyWith(submissionStatus: '미제출'), isNot(source));
      expect(
        source.copyWith(clearSubmissionStatus: true).submissionStatus,
        isNull,
      );
      expect(source.copyWith(clearDueAt: true).dueAt, isNull);
      expect(source.belongsToOwner(' STUDENT@example.com '), isTrue);
      expect(source.belongsToOwner(null), isFalse);
    },
  );

  test('invalid source identity, URL, date and progress fail closed', () {
    for (final patch in <Map<String, Object?>>[
      {'ownerId': ''},
      {'lmsUserId': ''},
      {'activityType': 'unknown'},
      {'sourceUrl': 'https://user:password@example.com/'},
      {'sourceUrl': 'javascript:alert(1)'},
      {'dueAt': 'not-a-date'},
      {'progressPercent': -1},
      {'progressPercent': 101},
      {'progressPercent': '100'},
    ]) {
      expect(
        () => LmsEventMetadata.fromJson({..._metadata().toJson(), ...patch}),
        throwsFormatException,
      );
    }
  });

  test(
    'LMS ownership never changes personal completion or personal fields',
    () {
      final original = _event();
      final changed = original.copyWith(
        title: '서버 수정',
        lms: original.lms!.copyWith(progressPercent: 50),
      );
      expect(changed.memo, original.memo);
      expect(changed.category, original.category);
      expect(
        changed.reminderMinutesBeforeList,
        original.reminderMinutesBeforeList,
      );
      expect(changed.completed, isFalse);
      expect(changed.isVisibleToOwner('student@example.com'), isTrue);
      expect(changed.isVisibleToOwner('other@example.com'), isFalse);
      expect(changed.isVisibleToOwner(null), isFalse);
      expect(
        changed
            .copyWith(clearLms: true)
            .isVisibleToOwner('student@example.com'),
        isFalse,
      );
      final personal = original.copyWith(id: 'personal', clearLms: true);
      expect(personal.isVisibleToOwner(null), isTrue);
      expect(eventVersionValues(personal), isNot(contains('lms')));
      expect(
        compareEventVersions(original, original.copyWith(clearLms: true)),
        greaterThan(0),
      );
      expect(compareEventVersions(original, changed), isNot(0));
    },
  );

  group('SQLite LMS storage', () {
    late AppDatabase database;
    late DriftEventRepository repository;
    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftEventRepository(database);
    });
    tearDown(() => database.close());

    test('persists source state and exact event timestamp precision', () async {
      final original = _event();
      await repository.save(original);
      final restored = (await repository.findById(original.id))!;
      expect(restored.lms, original.lms);
      expect(restored.completed, isFalse);
      expect(eventVersionValues(restored), eventVersionValues(original));
    });

    test(
      'midnight LMS deadline belongs only to its day in range and watch queries',
      () async {
        final due = DateTime.utc(2026, 9, 3);
        final point = _event().copyWith(startAt: due, endAt: due);
        final previousDay = due.subtract(const Duration(days: 1));
        final nextDay = due.add(const Duration(days: 1));
        await repository.save(point);
        expect(point.overlaps(due, nextDay), isTrue);
        expect(point.overlaps(previousDay, due), isFalse);
        expect(point.copyWith(clearLms: true).overlaps(due, nextDay), isFalse);
        expect(
          (await repository.eventsInRange(
            due,
            nextDay,
          )).map((event) => event.id),
          [point.id],
        );
        expect(await repository.eventsInRange(previousDay, due), isEmpty);
        expect(
          (await repository.watchEventsInRange(due, nextDay).first).map(
            (event) => event.id,
          ),
          [point.id],
        );
      },
    );

    test(
      'compaction retains deletion owner and rejects another owner tombstone',
      () async {
        final original = _event();
        await repository.save(original);
        await repository.mergeDeletionRecords([
          EventDeletion(
            id: original.id,
            deletedAt: DateTime.utc(2026, 10),
            lmsOwnerId: 'other@example.com',
          ),
        ]);
        expect(await repository.findById(original.id), isNotNull);
        expect(await repository.deletionRecords(), isEmpty);
        await repository.save(
          original.copyWith(deletedAt: DateTime.utc(2026, 9, 5)),
        );
        await repository.compactDeletedEvents(DateTime.utc(2026, 10));
        expect(await repository.findById(original.id), isNull);
        final marker = (await repository.deletionRecords()).single;
        expect(marker.lmsOwnerId, 'student@example.com');
        expect(
          EventDeletion.fromJson(marker.toJson()).lmsOwnerId,
          marker.lmsOwnerId,
        );
        expect(marker.isVisibleToOwner('other@example.com'), isFalse);
        await repository.mergeDeletionRecords([
          EventDeletion(
            id: original.id,
            deletedAt: DateTime.utc(2026, 11),
            pending: false,
          ),
        ]);
        expect(
          (await repository.deletionRecords()).single.lmsOwnerId,
          marker.lmsOwnerId,
        );
        await repository.mergeSyncRecords(
          [original],
          [],
          resolve: (_, remote) => remote,
        );
        expect(await repository.findById(original.id), isNull);
        expect((await repository.deletionRecords()).single.pending, isTrue);
      },
    );
  });

  for (final safeMigration in [false, true]) {
    test(
      'schema 8 migration preserves personal rows and tombstones (safe=$safeMigration)',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'daily-lms-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/daily.sqlite');
        final oldDatabase = AppDatabase.forTesting(NativeDatabase(file));
        final oldRepository = DriftEventRepository(oldDatabase);
        final personal = _event().copyWith(
          id: 'personal',
          clearLms: true,
          completed: true,
        );
        await oldRepository.save(personal);
        await oldRepository.mergeDeletionRecords([
          EventDeletion(
            id: 'deleted-personal',
            deletedAt: DateTime.utc(2026, 9, 2),
          ),
        ]);
        await oldDatabase.close();
        final raw = sqlite3.open(file.path);
        raw.execute('ALTER TABLE event_records DROP COLUMN lms_metadata');
        raw.execute(
          'ALTER TABLE sync_event_deletions DROP COLUMN lms_owner_id',
        );
        raw.execute('PRAGMA user_version = 8');
        raw.close();
        if (safeMigration) {
          final migration = TodoDatabaseMigrationService(
            databaseFile: () async => file,
            hasLinkedGoogleAccount: () => true,
            loadRemoteEvents: () async =>
                throw StateError('Schema 8 must not restore remote events'),
            backupMigratedEvents: () async =>
                throw StateError('Schema 8 must not back up unchanged events'),
          );
          addTearDown(migration.dispose);
          expect((await migration.migrateIfNeeded()).migrated, isTrue);
        }
        final upgraded = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(upgraded.close);
        final repository = DriftEventRepository(upgraded);
        expect(
          eventVersionValues((await repository.findById(personal.id))!),
          eventVersionValues(personal),
        );
        expect((await repository.deletionRecords()).single.toJson(), {
          'id': 'deleted-personal',
          'deletedAt': '2026-09-02T00:00:00.000Z',
        });
        if (safeMigration) {
          expect(await repository.findById('lms:assignment'), isNull);
        }
        await repository.save(_event());
        expect((await repository.findById('lms:assignment'))!.lms, _metadata());
      },
    );
  }
}
