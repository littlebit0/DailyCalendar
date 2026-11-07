import 'package:daily/core/alarms/native_alarm_service.dart';
import 'package:daily/core/sync/sync_version.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
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
          fireAt = (call.arguments as Map)['fireAtMilliseconds'];
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
}
