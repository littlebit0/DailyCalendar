import 'package:daily/core/alarms/native_alarm_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('daily/alarm_kit_test');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      setUp(() => debugDefaultTargetPlatformOverride = platform);
      test(
        'schedules a single event with its title, memo, and fire time',
        () async {
          MethodCall? call;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (methodCall) async {
                if (methodCall.method == 'authorizationState') {
                  return 'authorized';
                }
                call = methodCall;
                return null;
              });
          final start = DateTime.now().add(const Duration(hours: 2));
          final event = _event(startAt: start, alarmEnabled: true);

          await NativeAlarmService(channel: channel).scheduleEventAlarm(event);

          expect(call?.method, 'schedule');
          expect(call?.arguments, {
            'eventId': event.id,
            'title': '회의',
            'memo': '자료 지참',
            'fireAtMilliseconds': start.millisecondsSinceEpoch,
            'snoozeMinutes': 10,
          });
        },
      );

      test('does not schedule an alarm for a recurring event', () async {
        var called = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (methodCall) async {
              called = true;
              return null;
            });

        await NativeAlarmService(channel: channel).scheduleEventAlarm(
          _event(
            startAt: DateTime.now().add(const Duration(hours: 2)),
            alarmEnabled: true,
            recurring: true,
          ),
        );

        expect(called, isFalse);
      });

      test('uses the selected alarm time for an all-day event', () async {
        MethodCall? scheduleCall;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (methodCall) async {
              if (methodCall.method == 'authorizationState') {
                return 'authorized';
              }
              scheduleCall = methodCall;
              return null;
            });
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

        await NativeAlarmService(channel: channel).scheduleEventAlarm(
          _event(
            startAt: start,
            alarmEnabled: true,
            allDay: true,
            allDayAlarmMinutes: 7 * 60 + 30,
          ),
        );

        final expected = DateTime(start.year, start.month, start.day, 7, 30);
        expect(
          (scheduleCall?.arguments
              as Map<Object?, Object?>)['fireAtMilliseconds'],
          expected.millisecondsSinceEpoch,
        );
      });
    });
  }

  test('uses the native alarm channel on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methods.add(methodCall.method);
          if (methodCall.method == 'authorizationState') {
            return 'authorized';
          }
          return null;
        });

    await NativeAlarmService(channel: channel).scheduleEventAlarm(
      _event(
        startAt: DateTime.now().add(const Duration(hours: 2)),
        alarmEnabled: true,
      ),
    );

    expect(methods, ['authorizationState', 'schedule']);
  });
}

CalendarEvent _event({
  required DateTime startAt,
  required bool alarmEnabled,
  bool recurring = false,
  bool allDay = false,
  int allDayAlarmMinutes = 9 * 60,
}) {
  return CalendarEvent(
    id: '11111111-1111-4111-8111-111111111111',
    title: '회의',
    memo: '자료 지참',
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    allDay: allDay,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: startAt,
    updatedAt: startAt,
    alarmEnabled: alarmEnabled,
    allDayAlarmMinutes: allDayAlarmMinutes,
    recurrence: recurring
        ? const RecurrenceRule(frequency: RecurrenceFrequency.weekly)
        : const RecurrenceRule(),
  );
}
