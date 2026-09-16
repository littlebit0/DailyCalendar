import 'dart:convert';

import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/settings_sync_document.dart';
import 'package:daily/core/sync/sync_version.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_deletion.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CalendarEvent event({
  String id = 'e',
  DateTime? changed,
  DateTime? end,
  bool deleted = false,
  RecurrenceRule recurrence = const RecurrenceRule(),
}) {
  final time = changed ?? DateTime.utc(2026, 9, 10);
  return CalendarEvent(
    id: id,
    title: 'Meeting',
    startAt: DateTime(2026, 9, 10),
    endAt: end ?? DateTime(2026, 9, 11),
    allDay: true,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: time,
    deletedAt: deleted ? time : null,
    deviceId: 'device',
    recurrence: recurrence,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final first = DateTime.utc(2026, 9, 10, 3, 0, 0, 0, 100);
  final second = first.add(const Duration(microseconds: 100));

  test('UTC equivalent instants do not conflict because of timezone', () {
    final a = event(changed: DateTime.parse('2026-09-10T12:00:00+09:00'));
    final b = event(changed: DateTime.parse('2026-09-10T03:00:00Z'));
    expect(compareEventVersions(a, b), 0);
  });

  test('mutation time wins regardless of pending status or device', () {
    final a = event(
      changed: first,
    ).copyWith(syncStatus: 'pending', deviceId: 'z');
    final b = event(
      changed: second,
    ).copyWith(syncStatus: 'synced', deviceId: 'a');
    expect(compareEventVersions(a, b), lessThan(0));
  });

  test('ties are deterministic and deletion wins exact mutation ties', () {
    final a = event(changed: first).copyWith(title: 'A');
    final b = a.copyWith(title: 'B');
    expect(compareEventVersions(a, b), -compareEventVersions(b, a));
    expect(
      compareEventVersions(a.copyWith(deletedAt: first), b),
      greaterThan(0),
    );
  });

  test('independent category properties and settings merge commutatively', () {
    final before = {
      'themeMode': 'system',
      'categories': [
        {'id': 'work', 'label': 'Work', 'colorValue': 1, 'locked': false},
      ],
    };
    final base = SettingsSyncDocument.legacy(before);
    final a = base.recordChanges(
      before: before,
      after: {
        'themeMode': 'dark',
        'categories': [
          {'id': 'work', 'label': 'Office', 'colorValue': 1, 'locked': false},
        ],
      },
      changedAt: first,
      deviceId: 'a',
    );
    final b = base.recordChanges(
      before: before,
      after: {
        'themeMode': 'system',
        'categories': [
          {'id': 'work', 'label': 'Work', 'colorValue': 2, 'locked': false},
        ],
      },
      changedAt: second,
      deviceId: 'b',
    );
    final merged = a.merge(b);
    expect(merged.sameAs(b.merge(a)), isTrue);
    expect(merged.merge(a).sameAs(merged), isTrue);
    final values = merged.values(before);
    expect(values['themeMode'], 'dark');
    expect((values['categories'] as List).single, {
      'id': 'work',
      'label': 'Office',
      'colorValue': 2,
      'locked': false,
    });
    expect(
      base.fields.values.every((value) => value.changedAt == null),
      isTrue,
    );
  });

  test(
    'deleted category and day order cannot return from a stale document',
    () {
      final before = {
        'categories': [
          {'id': 'work', 'label': 'Work', 'colorValue': 1},
        ],
        'calendarManualEventOrders': {
          '2026-09-10': {
            'ids': ['a', 'b'],
          },
        },
      };
      final base = SettingsSyncDocument.legacy(before);
      final removed = base.recordChanges(
        before: before,
        after: {'categories': [], 'calendarManualEventOrders': {}},
        changedAt: first,
        deviceId: 'a',
      );
      final values = removed.merge(base).values(before);
      expect(values['categories'], isEmpty);
      expect(values['calendarManualEventOrders'], isEmpty);
    },
  );

  test(
    'settings edits retain their original mutation time through restore',
    () async {
      SharedPreferences.setMockInitialValues({'deviceId': 'a'});
      final prefs = await SharedPreferences.getInstance();
      var now = first;
      final repository = SettingsRepository(preferences: prefs, now: () => now);
      await repository.save(
        repository.load().copyWith(themeMode: AppThemeMode.dark),
      );
      final changed = repository.settingsSyncDocument().fields['themeMode']!;
      expect(changed.changedAt, first);
      now = second;
      await repository.save(repository.load(), markSyncPending: false);
      expect(
        repository.settingsSyncDocument().fields['themeMode']!.changedAt,
        first,
      );
      expect(
        jsonDecode(prefs.getString('settingsSyncDocument.v1')!),
        isNotEmpty,
      );
    },
  );

  for (final days in [0, 1, 5]) {
    test('only user-deleted expired event bodies compact ($days days)', () {
      final end = DateTime(2026, 9, 11 + days);
      expect(
        canCompactDeletedEvent(event(end: end), DateTime(2026, 10)),
        isFalse,
      );
      expect(
        canCompactDeletedEvent(event(end: end, deleted: true), end),
        isTrue,
      );
      expect(
        canCompactDeletedEvent(
          event(end: end, deleted: true),
          end.subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });
  }

  test('recurrence retention respects inclusive until and finite count', () {
    final until = event(
      deleted: true,
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        until: DateTime(2026, 9, 20),
      ),
    );
    expect(canCompactDeletedEvent(until, DateTime(2026, 9, 20)), isFalse);
    expect(canCompactDeletedEvent(until, DateTime(2026, 9, 21)), isTrue);
    final count = event(
      deleted: true,
      recurrence: const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        count: 3,
      ),
    );
    expect(canCompactDeletedEvent(count, DateTime(2026, 9, 24)), isFalse);
    expect(canCompactDeletedEvent(count, DateTime(2026, 9, 25)), isTrue);
    final forever = event(
      deleted: true,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
    );
    expect(canCompactDeletedEvent(forever, DateTime(2030)), isFalse);
  });

  group('real SQLite', () {
    late AppDatabase database;
    late DriftEventRepository repository;
    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftEventRepository(database);
    });
    tearDown(() => database.close());

    test('microsecond mutation time survives a database round trip', () async {
      await repository.save(event(changed: first));
      expect((await repository.findById('e'))!.updatedAt, first);
      await repository.save(event(changed: second, deleted: true));
      final saved = (await repository.findById('e'))!;
      expect(saved.updatedAt, second);
      expect(saved.deletedAt, second);
    });

    test('native writes invalidate stale timestamp precision', () async {
      await repository.save(event(changed: first));
      await database.customStatement(
        "UPDATE event_records SET title = 'Native edit' WHERE id = 'e'",
      );
      final saved = (await repository.findById('e'))!;
      expect(saved.title, 'Native edit');
      expect(saved.updatedAt.microsecond, 0);
    });

    test(
      'compaction and ledger prevent resurrection while preserving history',
      () async {
        await repository.save(event(deleted: true, changed: first));
        await repository.save(event(id: 'history'));
        await repository.compactDeletedEvents(DateTime(2026, 9, 12));
        expect(await repository.findById('e'), isNull);
        expect(await repository.findById('history'), isNotNull);
        final deletion = (await repository.deletionRecords()).single;
        expect(deletion.toJson().keys.toSet(), {'id', 'deletedAt'});
        expect(deletion.deletedAt, first);
        await repository.mergeSyncRecords(
          [event(changed: first)],
          [],
          resolve: (_, remote) => remote,
        );
        expect(await repository.findById('e'), isNull);
        await repository.markDeletionSynced(deletion);
        expect(await repository.deletionRecords(pendingOnly: true), isEmpty);
        await repository.mergeSyncRecords(
          [event(changed: second)],
          [],
          resolve: (_, remote) => remote,
        );
        expect((await repository.findById('e'))!.updatedAt, second);
      },
    );

    test(
      'an older incoming deletion never replaces a newer deletion ledger',
      () async {
        await repository.mergeDeletionRecords([
          EventDeletion(id: 'e', deletedAt: second),
        ]);
        await repository.save(event(changed: first));
        await repository.mergeDeletionRecords([
          EventDeletion(
            id: 'e',
            deletedAt: first.subtract(const Duration(days: 1)),
          ),
        ]);
        expect(await repository.findById('e'), isNull);
        expect((await repository.deletionRecords()).single.deletedAt, second);
      },
    );

    test('logout removes both event rows and local deletion ledger', () async {
      await repository.save(event());
      await repository.mergeDeletionRecords([
        EventDeletion(id: 'old', deletedAt: first),
      ]);
      await repository.clearAll();
      expect(await repository.allEventsForSync(), isEmpty);
      expect(await repository.deletionRecords(), isEmpty);
    });

    test(
      'stale remote deletes and rows queue the newer local winner',
      () async {
        await repository.save(
          event(changed: second).copyWith(syncStatus: 'synced'),
        );
        await repository.mergeSyncRecords([], [
          EventDeletion(id: 'e', deletedAt: first, pending: false),
        ], resolve: (_, remote) => remote);
        expect((await repository.pendingSyncEvents()).single.updatedAt, second);
        final deletion = EventDeletion(id: 'e', deletedAt: second);
        await repository.mergeDeletionRecords([deletion]);
        await repository.markDeletionSynced(deletion);
        await repository.mergeSyncRecords(
          [event(changed: first)],
          [],
          resolve: (_, remote) => remote,
        );
        expect(await repository.findById('e'), isNull);
        expect(
          (await repository.deletionRecords(
            pendingOnly: true,
          )).single.deletedAt,
          second,
        );
      },
    );
  });
}
