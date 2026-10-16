import 'dart:async';
import 'dart:convert';

import '../../features/events/domain/calendar_event.dart';
import '../settings/settings_repository.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';

/// Keeps reset cleanup independent of the event DB, which is about to be erased.
/// All OS mutations share one queue. A timeout never releases that queue early.
class RecoverableNotificationService implements NotificationService {
  RecoverableNotificationService(
    this._delegate,
    this._settings, {
    this.operationTimeout = const Duration(seconds: 15),
  });

  final NotificationService _delegate;
  final SettingsRepository _settings;
  final Duration operationTimeout;
  Future<void> _tail = Future<void>.value();
  int _generation = 0;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Map<String, dynamic>? _journal() {
    final raw = _settings.notificationCleanupJournal;
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data['events'] is! Map ||
        data['briefing'] is! bool ||
        data['dday'] is! List) {
      throw StateError('알림 정리 기록을 읽지 못했습니다. 다시 시도해 주세요.');
    }
    return data;
  }

  Future<void> _save(Map<String, dynamic> journal) =>
      _settings.saveNotificationCleanupJournal(jsonEncode(journal));

  /// Returns false if durable cleanup remains. Persistence failure throws before
  /// account data is removed. No titles, dates or account credentials are saved.
  Future<bool> prepareForReset(
    List<CalendarEvent> events, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    ++_generation; // Discard old queued schedules before the first await.
    final old = _journal();
    final settings = _settings.load();
    final ids = old == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(old['events'] as Map);
    for (final event in events) {
      ids[event.id] = <int>{
        ...(ids[event.id] as List? ?? const []).cast<int>(),
        ...settings.defaultReminderMinutesList,
        ...event.reminderMinutesBeforeList,
      }.toList();
    }
    await _save({
      'events': ids,
      'briefing': true,
      'dday': <int>{
        ...(old?['dday'] as List? ?? const []).cast<int>(),
        ...settings.dDayReminderOffsets,
      }.toList(),
    });
    try {
      return await _serialize(_recover).timeout(timeout);
    } on Object {
      // The journal is already durable; a later initialize/schedule retries it.
      return false;
    }
  }

  Future<bool> _recover() async {
    final journal = _journal();
    if (journal == null) return true;
    final generation = _generation;
    await _delegate.initialize();
    final events = Map<String, dynamic>.from(journal['events'] as Map);
    for (final entry in events.entries.toList()) {
      try {
        final delegate = _delegate;
        if (delegate is LocalNotificationService) {
          await delegate.cancelEventReminder(
            entry.key,
            reminderMinutesBeforeList: (entry.value as List).cast<int>(),
            dDayOffsets: (journal['dday'] as List).cast<int>(),
            includeDelivered: true,
          );
        } else {
          await delegate.cancelEventReminder(
            entry.key,
            reminderMinutesBeforeList: (entry.value as List).cast<int>(),
          );
        }
        if (generation != _generation) return false;
        events.remove(entry.key);
        journal['events'] = events;
        await _save(journal);
      } on Object {
        // A single failure must not skip the remaining event IDs or briefing.
      }
    }
    if (journal['briefing'] == true) {
      try {
        final delegate = _delegate;
        if (delegate is LocalNotificationService) {
          await delegate.cancelMorningBriefing(includeDelivered: true);
        } else {
          await delegate.cancelMorningBriefing();
        }
        if (generation != _generation) return false;
        journal['briefing'] = false;
        await _save(journal);
      } on Object {
        return false;
      }
    }
    // Clear the journal only after all OS cancellations succeeded.
    if (generation != _generation ||
        events.isNotEmpty ||
        journal['briefing'] == true) {
      return false;
    }
    await _settings.saveNotificationCleanupJournal(null);
    return true;
  }

  Future<void> _mutation(Future<void> Function() action) {
    final generation = _generation;
    return _serialize(() async {
      if (generation != _generation) return;
      if (!await _recover()) {
        throw StateError('이전 계정 알림을 정리하지 못했습니다. 알림 설정을 다시 시도해 주세요.');
      }
      if (generation == _generation) await action();
    }).timeout(operationTimeout);
  }

  Future<void> confirmAlarmScheduled(CalendarEvent event) =>
      _mutation(() async {
        final delegate = _delegate;
        if (delegate is LocalNotificationService) {
          await delegate.confirmAlarmScheduled(event);
        }
      });

  @override
  Future<void> initialize() => _mutation(_delegate.initialize);
  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) => _mutation(
    () =>
        _delegate.scheduleEventReminder(event, allowImmediate: allowImmediate),
  );
  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) => _mutation(
    () => _delegate.cancelEventReminder(
      eventId,
      reminderMinutesBeforeList: reminderMinutesBeforeList,
    ),
  );
  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) => _mutation(
    () => _delegate.scheduleMorningBriefing(hour: hour, minute: minute),
  );
  @override
  Future<void> cancelMorningBriefing() =>
      _mutation(_delegate.cancelMorningBriefing);
  @override
  Future<int> pendingNotificationCount() =>
      _delegate.pendingNotificationCount();
  @override
  Future<String> permissionSummary() => _delegate.permissionSummary();
}
