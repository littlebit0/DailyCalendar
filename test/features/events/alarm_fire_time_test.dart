import 'dart:io';

import 'package:daily/core/alarms/native_alarm_service.dart';
import 'package:daily/core/sync/sync_version.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/alarm_triggers.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CalendarEvent event({
    DateTime? startAt,
    bool allDay = false,
    int allDayAlarmMinutes = 9 * 60,
    int alarmMinutesBefore = 0,
    DateTime? alarmCustomAt,
    List<int>? minutesList,
    List<DateTime>? customList,
  }) {
    final start = startAt ?? DateTime(2026, 11, 10, 14, 0);
    return CalendarEvent(
      id: '22222222-2222-4222-8222-222222222222',
      title: '회의',
      startAt: start,
      endAt: start.add(Duration(hours: allDay ? 24 : 1)),
      allDay: allDay,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
      alarmEnabled: true,
      allDayAlarmMinutes: allDayAlarmMinutes,
      alarmMinutesBefore: alarmMinutesBefore,
      alarmCustomAt: alarmCustomAt,
      alarmMinutesBeforeList: minutesList,
      alarmCustomAtList: customList,
    );
  }

  group('alarmFireAt', () {
    test('legacy defaults keep the previous fire times', () {
      expect(event().alarmFireAt, DateTime(2026, 11, 10, 14, 0));
      expect(
        event(
          startAt: DateTime(2026, 11, 10),
          allDay: true,
          allDayAlarmMinutes: 7 * 60 + 30,
        ).alarmFireAt,
        DateTime(2026, 11, 10, 7, 30),
      );
    });

    test('relative alarms follow a changed start, custom alarms do not', () {
      final relative = event(alarmMinutesBefore: 30);
      expect(relative.alarmFireAt, DateTime(2026, 11, 10, 13, 30));
      final moved = relative.copyWith(startAt: DateTime(2026, 11, 12, 9, 0));
      expect(moved.alarmFireAt, DateTime(2026, 11, 12, 8, 30));

      final customAt = DateTime(2026, 11, 9, 20, 15);
      final custom = event(alarmMinutesBefore: 30, alarmCustomAt: customAt);
      expect(custom.alarmFireAt, customAt);
      expect(
        custom.copyWith(startAt: DateTime(2026, 12, 1, 9)).alarmFireAt,
        customAt,
      );
      expect(
        custom.copyWith(clearAlarmCustomAt: true).alarmFireAt,
        DateTime(2026, 11, 10, 13, 30),
      );
    });

    test('offsets cross day, month and year boundaries', () {
      expect(
        event(
          startAt: DateTime(2027, 1, 1, 0, 10),
          alarmMinutesBefore: 1440,
        ).alarmFireAt,
        DateTime(2026, 12, 31, 0, 10),
      );
      // All-day offsets are measured from the all-day alarm clock time.
      expect(
        event(
          startAt: DateTime(2026, 12, 1),
          allDay: true,
          allDayAlarmMinutes: 9 * 60,
          alarmMinutesBefore: 600,
        ).alarmFireAt,
        DateTime(2026, 11, 30, 23, 0),
      );
    });

    test('offsets are elapsed minutes before the start', () {
      final start = DateTime(2026, 3, 8, 3, 30);
      final fireAt = event(startAt: start, alarmMinutesBefore: 120).alarmFireAt;
      expect(start.difference(fireAt), const Duration(minutes: 120));
    });

    test('draft applies and clears alarm timing', () {
      final source = event(alarmCustomAt: DateTime(2026, 11, 9, 8));
      final draft = EventDraft(
        title: source.title,
        startAt: source.startAt,
        endAt: source.endAt,
        alarmEnabled: true,
        alarmMinutesBefore: 10,
      );
      final applied = draft.applyTo(source);
      expect(applied.alarmCustomAt, isNull);
      expect(applied.alarmMinutesBefore, 10);
      final created = draft
          .copyWith(alarmCustomAt: DateTime(2026, 11, 9, 7))
          .toEvent(id: 'x', now: DateTime(2026, 11, 1), deviceId: 'd');
      expect(created.alarmCustomAt, DateTime(2026, 11, 9, 7));
    });
  });

  test('sync fingerprint omits default alarm timing', () {
    final values = eventVersionValues(event());
    expect(values, isNot(contains('alarmMinutesBefore')));
    expect(values, isNot(contains('alarmCustomAt')));
    final custom = eventVersionValues(
      event(alarmMinutesBefore: 5, alarmCustomAt: DateTime.utc(2026, 11, 9)),
    );
    expect(custom['alarmMinutesBefore'], 5);
    expect(custom['alarmCustomAt'], '2026-11-09T00:00:00.000Z');
  });

  test('drift repository persists alarm timing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftEventRepository(database);
    final saved = event(
      alarmMinutesBefore: 45,
      alarmCustomAt: DateTime(2026, 11, 9, 21, 5),
    );
    await repository.save(saved);
    final loaded = (await repository.findById(saved.id))!;
    expect(loaded.alarmMinutesBefore, 45);
    expect(loaded.alarmCustomAt, DateTime(2026, 11, 9, 21, 5));
  });

  test('native alarm receives the selected relative fire time', () async {
    const channel = MethodChannel('daily/alarm_fire_time_test');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    Object? fireAt;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'authorizationState') return 'authorized';
          fireAt = ((call.arguments as Map)['fireAtMillisecondsList'] as List).single;
          return true;
        });
    final start = DateTime.now().add(const Duration(days: 2));
    await NativeAlarmService(
      channel: channel,
    ).scheduleEventAlarm(event(startAt: start, alarmMinutesBefore: 60));
    expect(
      fireAt,
      start.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  });

  group('several alarm times (#784)', () {
    test('fire times are sorted, deduplicated and the earliest is legacy', () {
      final customAt = DateTime(2026, 11, 10, 12);
      final multi = event(
        minutesList: [30, 0, 10, 30],
        customList: [customAt, DateTime(2026, 11, 10, 13, 50), customAt],
      );
      expect(multi.alarmMinutesBeforeList, [0, 10, 30]);
      expect(multi.alarmFireTimes, [
        customAt,
        DateTime(2026, 11, 10, 13, 30),
        DateTime(2026, 11, 10, 13, 50),
        DateTime(2026, 11, 10, 14),
      ]);
      expect(multi.alarmFireAt, customAt);
      expect(multi.alarmCustomAt, customAt);
      expect(multi.hasMultipleAlarmTimes, isTrue);

      // Moving the start keeps custom times and makes a relative one earliest.
      final moved = multi.copyWith(startAt: DateTime(2026, 11, 10, 9));
      expect(moved.alarmCustomAt, isNull);
      expect(moved.alarmMinutesBefore, 30);
      expect(moved.alarmCustomAtList, multi.alarmCustomAtList);
      expect(moved.alarmFireAt, DateTime(2026, 11, 10, 8, 30));
    });

    test('a legacy single trigger change replaces the list', () {
      final multi = event(minutesList: [0, 10]);
      final single = multi.copyWith(alarmMinutesBefore: 5);
      expect(single.alarmMinutesBeforeList, [5]);
      expect(single.hasMultipleAlarmTimes, isFalse);
      expect(event(minutesList: const []).alarmMinutesBeforeList, [0]);
    });

    test('single alarms keep their sync fingerprint keys', () {
      final legacy = eventVersionValues(event(alarmMinutesBefore: 10));
      final viaList = eventVersionValues(event(minutesList: [10]));
      expect(viaList, legacy);
      expect(legacy, isNot(contains('alarmMinutesBeforeList')));
      final multi = eventVersionValues(event(minutesList: [0, 10]));
      expect(multi['alarmMinutesBeforeList'], [0, 10]);
      expect(multi['alarmMinutesBefore'], 10);
    });

    test('drift repository persists every alarm time', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final customAt = DateTime(2026, 11, 9, 21, 5);
      final saved = event(minutesList: [0, 15], customList: [customAt]);
      await repository.save(saved);
      final loaded = (await repository.findById(saved.id))!;
      expect(loaded.alarmMinutesBeforeList, [0, 15]);
      expect(loaded.alarmCustomAtList, [customAt]);
      expect(loaded.alarmCustomAt, customAt);

      // Single alarms leave the list columns empty.
      await repository.save(event(alarmMinutesBefore: 20));
      final row = await database
          .customSelect(
            'SELECT alarm_minutes_before_list, alarm_custom_at_list '
            'FROM event_records',
          )
          .getSingle();
      expect(row.data.values, everyElement(isNull));
      expect(
        (await repository.findById(saved.id))!.alarmMinutesBeforeList,
        [20],
      );
    });

    test('a native start_at update keeps every stored alarm time', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final customAt = DateTime(2026, 11, 10, 13);
      // 14:00 start: the 13:00 custom time is the stored representative.
      final saved = event(minutesList: [30], customList: [customAt]);
      await repository.save(saved);
      expect(saved.alarmCustomAt, customAt);
      // Siri moves only start_at/end_at, leaving the legacy alarm columns.
      final moved = DateTime(2026, 11, 10, 12);
      await database.customStatement(
        'UPDATE event_records SET start_at = ?, end_at = ? WHERE id = ?',
        [
          moved.millisecondsSinceEpoch ~/ 1000,
          moved.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          saved.id,
        ],
      );
      final loaded = (await repository.findById(saved.id))!;
      expect(loaded.alarmMinutesBeforeList, [30]);
      expect(loaded.alarmCustomAtList, [customAt]);
      expect(loaded.alarmFireTimes, [DateTime(2026, 11, 10, 11, 30), customAt]);
      expect(loaded.alarmMinutesBefore, 30);
      expect(loaded.alarmCustomAt, isNull);
    });

    test('schema 12 databases upgrade and keep their single alarm', () async {
      final directory = await Directory.systemTemp.createTemp('daily-alarm-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/daily.sqlite');
      final old = AppDatabase.forTesting(NativeDatabase(file));
      await DriftEventRepository(
        old,
      ).save(event(alarmMinutesBefore: 45, alarmCustomAt: DateTime(2026, 11, 9)));
      for (final column in ['alarm_minutes_before_list', 'alarm_custom_at_list']) {
        await old.customStatement('ALTER TABLE event_records DROP COLUMN $column');
      }
      await old.customStatement('PRAGMA user_version = 12');
      await old.close();

      // Opening twice also covers a retry after an interrupted upgrade.
      for (var attempt = 0; attempt < 2; attempt++) {
        final database = AppDatabase.forTesting(NativeDatabase(file));
        final loaded = (await DriftEventRepository(
          database,
        ).findById('22222222-2222-4222-8222-222222222222'))!;
        final version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        await database.close();
        expect(
          version.read<int>('user_version'),
          AppDatabase.currentSchemaVersion,
        );
        expect(loaded.alarmCustomAtList, [DateTime(2026, 11, 9)]);
        expect(loaded.alarmMinutesBeforeList, isEmpty);
        expect(loaded.alarmMinutesBefore, 45);
      }
    });

    test('stored lists contradicted by a legacy-only edit are dropped', () {
      final kept = acceptedAlarmLists(
        legacyMinutes: 30,
        legacyCustomAt: null,
        minutes: '[0,30]',
        customs: '[]',
      );
      expect(kept.minutes, [0, 30]);
      final edited = acceptedAlarmLists(
        legacyMinutes: 60,
        legacyCustomAt: null,
        minutes: [0, 30],
        customs: const [],
      );
      expect(edited.minutes, isNull);
      expect(edited.customs, isNull);
      // The legacy custom time is still one of the lists' times even when a
      // relative trigger is earliest on the reading device (another time
      // zone for an all-day event, or a moved start).
      final customAt = DateTime.utc(2026, 11, 10, 16);
      final otherZone = acceptedAlarmLists(
        legacyMinutes: 0,
        legacyCustomAt: customAt,
        minutes: [0],
        customs: [customAt.toIso8601String()],
      );
      expect(otherZone.minutes, [0]);
      expect(otherZone.customs, [customAt.toLocal()]);
      final customEdited = acceptedAlarmLists(
        legacyMinutes: 0,
        legacyCustomAt: customAt.add(const Duration(hours: 1)),
        minutes: [0],
        customs: [customAt.toIso8601String()],
      );
      expect(customEdited.customs, isNull);
      expect(
        acceptedAlarmLists(
          legacyMinutes: 0,
          legacyCustomAt: null,
          minutes: 'not json',
          customs: null,
        ).minutes,
        isNull,
      );
    });

    test('native alarms get every future time and reconcile gets all', () async {
      const channel = MethodChannel('daily/alarm_multi_test');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'authorizationState') return 'authorized';
            calls.add(call);
            return true;
          });
      final start = DateTime.now().add(const Duration(hours: 1));
      final service = NativeAlarmService(channel: channel);
      // 120 minutes before has already passed.
      final multi = event(startAt: start, minutesList: [0, 10, 120]);
      await service.scheduleEventAlarm(multi);
      await service.reconcileEventAlarm(multi);
      await service.cancelEventAlarm(multi.id);
      expect(calls.map((call) => call.method), [
        'schedule',
        'reconcile',
        'cancel',
      ]);
      int ms(int minutes) => start
          .subtract(Duration(minutes: minutes))
          .millisecondsSinceEpoch;
      expect((calls[0].arguments as Map)['fireAtMillisecondsList'], [
        ms(10),
        ms(0),
      ]);
      expect((calls[1].arguments as Map)['fireAtMillisecondsList'], [
        ms(120),
        ms(10),
        ms(0),
      ]);
      expect((calls[2].arguments as Map)['eventId'], multi.id);

      calls.clear();
      await service.scheduleEventAlarm(event(startAt: start, minutesList: [120]));
      expect(calls, isEmpty);
    });
  });
}
