import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/events/domain/calendar_event.dart';
import 'alarm_service.dart';

class NativeAlarmService implements AlarmService {
  NativeAlarmService({MethodChannel? channel})
    : _channel =
          channel ??
          MethodChannel(
            defaultTargetPlatform == TargetPlatform.android
                ? 'daily/android_alarms'
                : 'daily/alarm_kit',
          );

  final MethodChannel _channel;

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AlarmAuthorizationState> authorizationState() async {
    if (!_isSupportedPlatform) {
      return AlarmAuthorizationState.unsupported;
    }
    final value = await _channel.invokeMethod<String>('authorizationState');
    return _stateFromName(value);
  }

  @override
  Future<AlarmAuthorizationState> requestAuthorization() async {
    if (!_isSupportedPlatform) {
      return AlarmAuthorizationState.unsupported;
    }
    final value = await _channel.invokeMethod<String>('requestAuthorization');
    return _stateFromName(value);
  }

  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async {
    if (!_isSupportedPlatform ||
        !event.alarmEnabled ||
        event.completed ||
        event.isRecurring ||
        event.isDeleted ||
        event.systemEvent ||
        event.readOnly) {
      return;
    }
    if (await authorizationState() != AlarmAuthorizationState.authorized) {
      return;
    }
    final fireAt = event.allDay
        ? DateTime(
            event.startAt.year,
            event.startAt.month,
            event.startAt.day,
            event.allDayAlarmMinutes ~/ 60,
            event.allDayAlarmMinutes % 60,
          )
        : event.startAt;
    if (!fireAt.isAfter(DateTime.now())) {
      return;
    }
    await _channel.invokeMethod<void>('schedule', {
      'eventId': event.id,
      'title': event.title,
      'memo': event.memo,
      'fireAtMilliseconds': fireAt.millisecondsSinceEpoch,
      'snoozeMinutes': 10,
    });
  }

  @override
  Future<void> cancelEventAlarm(String eventId) async {
    if (!_isSupportedPlatform || eventId.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod<void>('cancel', {'eventId': eventId});
  }

  @override
  Future<void> cancelAllEventAlarms() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _channel.invokeMethod<void>('cancelAll');
  }

  AlarmAuthorizationState _stateFromName(String? value) {
    return switch (value) {
      'authorized' => AlarmAuthorizationState.authorized,
      'denied' => AlarmAuthorizationState.denied,
      'notDetermined' => AlarmAuthorizationState.notDetermined,
      _ => AlarmAuthorizationState.unsupported,
    };
  }
}
