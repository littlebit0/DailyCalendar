import 'package:daily/core/alarms/alarm_service.dart';
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

  test(
    'startup reconciliation reaches native state for past source without cancel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'authorizationState') return 'authorized';
            if (call.method == 'reconcile') return true;
            return null;
          });
      final service = NativeAlarmService(channel: channel);
      final source = _event(
        startAt: DateTime.now().subtract(const Duration(minutes: 5)),
        alarmEnabled: true,
      );
      await reconcileEventAlarm(service, source);
      expect(methods, ['authorizationState', 'reconcile']);
      methods.clear();
      await reconcileEventAlarm(service, source.copyWith(completed: true));
      expect(methods, ['cancel']);
      methods.clear();
      await reconcileEventAlarm(service, source.copyWith(alarmEnabled: false));
      expect(methods, ['cancel']);
    },
  );

  for (final state in [
    'unsupported',
    'denied',
    'notDetermined',
    'authorized',
  ]) {
    for (final outcome in ['success', 'no-op', 'failure']) {
      test(
        'only confirmed alarm suppresses fallback $state $outcome',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          var replaced = 0;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'authorizationState') return state;
                if (call.method == 'schedule') {
                  if (outcome == 'failure') {
                    throw PlatformException(code: 'schedule_failed');
                  }
                  return outcome == 'success';
                }
                return null;
              });
          final service = NativeAlarmService(
            channel: channel,
            onAlarmScheduled: (_) async => replaced++,
          );
          final action = service.scheduleEventAlarm(
            _event(
              startAt: DateTime.now().add(const Duration(hours: 2)),
              alarmEnabled: true,
            ),
          );
          if (state == 'authorized' && outcome == 'failure') {
            await expectLater(action, throwsA(isA<PlatformException>()));
          } else {
            await action;
          }
          expect(
            replaced,
            state == 'authorized' && outcome == 'success' ? 1 : 0,
          );
        },
      );
    }
  }

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
