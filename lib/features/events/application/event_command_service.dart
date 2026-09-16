import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/analytics/product_analytics.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/alarms/alarm_service.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/time/korea_time.dart';
import '../domain/calendar_event.dart';
import '../domain/event_draft.dart';
import '../domain/event_category.dart';
import '../domain/event_repository.dart';
import '../domain/recurrence_rule.dart';

class EventCommandService {
  EventCommandService({
    required EventRepository repository,
    required SettingsRepository settingsRepository,
    required NotificationService notificationService,
    AlarmService alarmService = const UnsupportedAlarmService(),
    required SyncService syncService,
    ProductAnalytics analytics = const NoopProductAnalytics(),
    Future<void> Function()? onEventsChanged,
    KoreaTime? clock,
    Uuid? uuid,
  }) : _repository = repository,
       _settingsRepository = settingsRepository,
       _notificationService = notificationService,
       _alarmService = alarmService,
       _syncService = syncService,
       _analytics = analytics,
       _onEventsChanged = onEventsChanged,
       _clock = clock ?? const KoreaTime(),
       _uuid = uuid ?? const Uuid();

  final EventRepository _repository;
  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;
  final AlarmService _alarmService;
  final SyncService _syncService;
  final ProductAnalytics _analytics;
  final Future<void> Function()? _onEventsChanged;
  final KoreaTime _clock;
  final Uuid _uuid;
  Future<void> _categoryUpdateTail = Future<void>.value();

  Future<CalendarEvent> create(EventDraft draft) async {
    final now = _clock.now();
    final event = draft.toEvent(
      id: _uuid.v4(),
      now: now,
      deviceId: await _settingsRepository.deviceId(),
    );
    await save(event);
    return event;
  }

  Future<void> save(CalendarEvent event) async {
    final stopwatch = Stopwatch()..start();
    final updated = event
        .copyWith(updatedAt: _clock.now(), syncStatus: 'pending')
        .normalizeAllDayBounds();
    CalendarEvent? existing;
    try {
      existing = await _repository.findById(updated.id);
      await _repository.save(updated);
      await _notificationService.cancelEventReminder(
        updated.id,
        reminderMinutesBeforeList: _combinedReminderMinutes(existing, updated),
      );
      await _notificationService.scheduleEventReminder(
        updated,
        allowImmediate: true,
      );
      await _alarmService.cancelEventAlarm(updated.id);
      await _alarmService.scheduleEventAlarm(updated);
      await _rescheduleMorningBriefingIfNeeded();
      await _syncService.queueEventUpsert(updated);
      await _refreshWidgets();
    } on Object catch (error) {
      _recordMutation(
        existing == null
            ? AnalyticsOperation.create
            : AnalyticsOperation.update,
        stopwatch,
        error: error,
      );
      rethrow;
    }
    _recordMutation(
      existing == null ? AnalyticsOperation.create : AnalyticsOperation.update,
      stopwatch,
    );
  }

  Future<void> setCompleted(CalendarEvent event, bool completed) async {
    if (event.readOnly || event.systemEvent || event.holiday) {
      return;
    }
    final stopwatch = Stopwatch()..start();
    try {
      final source = await _repository.findById(event.id) ?? event;
      if (event.occurrenceId != null && source.recurrence.isRepeating) {
        if (event.completed == completed) {
          return;
        }
        await _setRecurringOccurrenceCompleted(
          source: source,
          occurrence: event,
          completed: completed,
        );
        _recordMutation(
          completed
              ? AnalyticsOperation.complete
              : AnalyticsOperation.uncomplete,
          stopwatch,
        );
        return;
      }
      if (source.completed == completed) {
        return;
      }
      final updated = source.copyWith(
        completed: completed,
        updatedAt: _clock.now(),
        syncStatus: 'pending',
      );
      await _repository.save(updated);
      await _notificationService.cancelEventReminder(
        updated.id,
        reminderMinutesBeforeList: updated.reminderMinutesBeforeList,
      );
      await _alarmService.cancelEventAlarm(updated.id);
      if (!completed) {
        await _notificationService.scheduleEventReminder(updated);
        await _alarmService.scheduleEventAlarm(updated);
      }
      await _rescheduleMorningBriefingIfNeeded();
      await _syncService.queueEventUpsert(updated);
      await _refreshWidgets();
    } on Object catch (error) {
      _recordMutation(
        completed ? AnalyticsOperation.complete : AnalyticsOperation.uncomplete,
        stopwatch,
        error: error,
      );
      rethrow;
    }
    _recordMutation(
      completed ? AnalyticsOperation.complete : AnalyticsOperation.uncomplete,
      stopwatch,
    );
  }

  Future<void> _setRecurringOccurrenceCompleted({
    required CalendarEvent source,
    required CalendarEvent occurrence,
    required bool completed,
  }) async {
    final now = _clock.now();
    final occurrenceDay = DateTime(
      occurrence.startAt.year,
      occurrence.startAt.month,
      occurrence.startAt.day,
    );
    final excludedDates = {
      ...source.recurrence.excludedDates.map(
        (date) => DateTime(date.year, date.month, date.day),
      ),
      occurrenceDay,
    }.toList()..sort();
    final updatedSeries = source.copyWith(
      recurrence: source.recurrence.copyWith(excludedDates: excludedDates),
      updatedAt: now,
      syncStatus: 'pending',
    );
    final detachedOccurrence = occurrence
        .copyWith(
          id: _uuid.v4(),
          clearOccurrenceId: true,
          recurrence: const RecurrenceRule(),
          completed: completed,
          createdAt: now,
          updatedAt: now,
          syncStatus: 'pending',
          clearDeletedAt: true,
        )
        .normalizeAllDayBounds();

    await _repository.saveAllAtomically([updatedSeries, detachedOccurrence]);

    await _notificationService.cancelEventReminder(
      updatedSeries.id,
      reminderMinutesBeforeList: updatedSeries.reminderMinutesBeforeList,
    );
    await _notificationService.scheduleEventReminder(updatedSeries);
    await _alarmService.cancelEventAlarm(updatedSeries.id);
    await _alarmService.scheduleEventAlarm(updatedSeries);
    if (!completed) {
      await _notificationService.scheduleEventReminder(detachedOccurrence);
      await _alarmService.scheduleEventAlarm(detachedOccurrence);
    }
    await _syncService.queueEventUpsert(updatedSeries);
    await _syncService.queueEventUpsert(detachedOccurrence);
    await _rescheduleMorningBriefingIfNeeded();
    await _refreshWidgets();
  }

  Future<Set<String>> importBatch(
    Iterable<CalendarEvent> events, {
    Future<CalendarEvent?> Function(CalendarEvent event)? prepare,
    bool Function()? isCurrent,
  }) async {
    final importedIds = <String>{};
    for (final event in events) {
      CalendarEvent imported;
      try {
        final prepared = prepare == null ? event : await prepare(event);
        if (isCurrent != null && !isCurrent()) break;
        if (prepared == null) continue;
        imported = prepared
            .copyWith(updatedAt: _clock.now(), syncStatus: 'pending')
            .normalizeAllDayBounds();
        await _repository.save(imported);
      } on Object {
        continue;
      }

      importedIds.add(imported.id);
      try {
        await _notificationService.scheduleEventReminder(imported);
      } on Object {
        // Import must preserve the event even if notification scheduling fails.
      }
      try {
        await _alarmService.scheduleEventAlarm(imported);
      } on Object {
        // Imported events do not enable alarms by default; keep this best-effort.
      }
      try {
        await _syncService.queueEventUpsert(imported);
      } on Object {
        // The pending sync status lets a later lifecycle sync retry the upload.
      }
    }

    if (importedIds.isNotEmpty) {
      await _rescheduleMorningBriefingIfNeeded();
      await _refreshWidgets();
    }
    return importedIds;
  }

  Future<void> delete(String eventId) async {
    final stopwatch = Stopwatch()..start();
    try {
      final existing = await _repository.findById(eventId);
      await _repository.delete(eventId);
      await _notificationService.cancelEventReminder(
        eventId,
        reminderMinutesBeforeList:
            existing?.reminderMinutesBeforeList ?? const [],
      );
      await _alarmService.cancelEventAlarm(eventId);
      await _rescheduleMorningBriefingIfNeeded();
      await _syncService.queueEventDelete(eventId);
      await _refreshWidgets();
    } on Object catch (error) {
      _recordMutation(AnalyticsOperation.delete, stopwatch, error: error);
      rethrow;
    }
    _recordMutation(AnalyticsOperation.delete, stopwatch);
  }

  Future<void> updateCategoryUsage({
    required EventCategory previous,
    required EventCategory updated,
  }) {
    final operation = _categoryUpdateTail.then(
      (_) => _updateCategoryUsage(previous: previous, updated: updated),
    );
    _categoryUpdateTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _updateCategoryUsage({
    required EventCategory previous,
    required EventCategory updated,
  }) async {
    final affected = await _repository.updateCategoryReferences(
      previous: previous,
      updated: updated,
      updatedAt: _clock.now(),
    );
    if (affected.isEmpty) {
      return;
    }

    for (final event in affected) {
      await _syncService.queueEventUpsert(event);
    }
    await _refreshWidgets();
  }

  Future<void> _refreshWidgets() async {
    try {
      await _onEventsChanged?.call();
    } on Object {
      // Widget refresh is best-effort and must not fail calendar mutations.
    }
  }

  List<int> _combinedReminderMinutes(
    CalendarEvent? existing,
    CalendarEvent updated,
  ) {
    return normalizeReminderMinutes([
      ...?existing?.reminderMinutesBeforeList,
      ...updated.reminderMinutesBeforeList,
    ]);
  }

  Future<void> _rescheduleMorningBriefingIfNeeded() async {
    final settings = _settingsRepository.load();
    if (!settings.morningBriefingEnabled) {
      return;
    }
    await _notificationService.scheduleMorningBriefing(
      hour: settings.morningBriefingHour,
      minute: settings.morningBriefingMinute,
    );
  }

  void _recordMutation(
    AnalyticsOperation operation,
    Stopwatch stopwatch, {
    Object? error,
  }) {
    stopwatch.stop();
    unawaited(
      _analytics
          .record(
            AnalyticsRecord.eventSave(
              operation,
              succeeded: error == null,
              durationMs: stopwatch.elapsedMilliseconds,
              errorCode: error == null ? null : categorizeAnalyticsError(error),
            ),
          )
          .catchError((_) {}),
    );
  }
}
