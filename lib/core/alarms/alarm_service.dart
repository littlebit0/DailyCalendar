import '../../features/events/domain/calendar_event.dart';

enum AlarmAuthorizationState { unsupported, notDetermined, denied, authorized }

abstract interface class AlarmService {
  Future<AlarmAuthorizationState> authorizationState();

  Future<AlarmAuthorizationState> requestAuthorization();

  Future<void> scheduleEventAlarm(CalendarEvent event);

  Future<void> cancelEventAlarm(String eventId);

  Future<void> cancelAllEventAlarms();
}

class UnsupportedAlarmService implements AlarmService {
  const UnsupportedAlarmService();

  @override
  Future<AlarmAuthorizationState> authorizationState() async =>
      AlarmAuthorizationState.unsupported;

  @override
  Future<AlarmAuthorizationState> requestAuthorization() async =>
      AlarmAuthorizationState.unsupported;

  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async {}

  @override
  Future<void> cancelEventAlarm(String eventId) async {}

  @override
  Future<void> cancelAllEventAlarms() async {}
}

/// Startup reconciliation preserves a native snooze/ringing state when the
/// saved source has not changed. Explicit user mutations still cancel normally.
abstract interface class ReconciliableAlarmService {
  Future<void> reconcileEventAlarm(CalendarEvent event);
}

Future<void> reconcileEventAlarm(
  AlarmService service,
  CalendarEvent event,
) async {
  if (!event.alarmEnabled ||
      event.completed ||
      event.isDeleted ||
      event.isRecurring ||
      event.readOnly ||
      event.systemEvent) {
    await service.cancelEventAlarm(event.id);
  } else if (service is ReconciliableAlarmService) {
    await (service as ReconciliableAlarmService).reconcileEventAlarm(event);
  } else {
    await service.scheduleEventAlarm(event);
  }
}
