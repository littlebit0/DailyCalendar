import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/analytics/product_analytics.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/alarms/alarm_service.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/sync/sync_version.dart';
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
    var updated = event
        .copyWith(updatedAt: _clock.now(), syncStatus: 'pending')
        .normalizeAllDayBounds();
    CalendarEvent? existing;
    try {
      existing = await _repository.findById(updated.id);
      if (existing?.lms != null || event.lms != null) {
        if (existing == null ||
            existing.isDeleted ||
            !_isCurrentOwner(existing)) {
          return;
        }
        final mutations = await _repository.mergeRestoredEventsAtomically(
          [updated],
          resolve: (latest, edited) {
            if (latest == null) {
              throw StateError('LMS 일정이 삭제되었습니다. 다시 확인해 주세요.');
            }
            if (latest.isDeleted || !_isCurrentOwner(latest)) return latest;
            // The editor may have opened before the LMS refreshed its title,
            // deadline or status. Only personal editor fields come from it.
            return _withLmsSource(
              edited.copyWith(completed: latest.completed),
              latest,
            ).copyWith(
              updatedAt: _nextLmsChange(latest),
              syncStatus: 'pending',
            );
          },
        );
        if (mutations.isEmpty) return;
        existing = mutations.single.previous;
        updated = mutations.single.current;
      } else {
        if (!_isCurrentOwner(updated)) return;
        await _repository.save(updated);
      }
      if (!_isCurrentOwner(updated)) return;
      await _notificationService.cancelEventReminder(
        updated.id,
        reminderMinutesBeforeList: _combinedReminderMinutes(existing, updated),
      );
      if (!_isCurrentOwner(updated)) return;
      await _notificationService.scheduleEventReminder(
        updated,
        allowImmediate: true,
      );
      if (!_isCurrentOwner(updated)) return;
      await _alarmService.cancelEventAlarm(updated.id);
      if (!_isCurrentOwner(updated)) return;
      await _alarmService.scheduleEventAlarm(updated);
      if (!_isCurrentOwner(updated)) return;
      await _rescheduleMorningBriefingIfNeeded();
      if (!_isCurrentOwner(updated)) return;
      await _syncService.queueEventUpsert(updated);
      if (!_isCurrentOwner(updated)) return;
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
      if (!_isCurrentOwner(source)) return;
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
      var updated = source.copyWith(
        completed: completed,
        updatedAt: _clock.now(),
        syncStatus: 'pending',
      );
      if (source.lms == null) {
        await _repository.save(updated);
      } else {
        final mutations = await _repository.mergeRestoredEventsAtomically(
          [updated],
          resolve: (latest, _) {
            if (latest == null) {
              throw StateError('LMS 일정이 삭제되었습니다. 다시 확인해 주세요.');
            }
            if (latest.isDeleted || !_isCurrentOwner(latest)) return latest;
            return latest.copyWith(
              completed: completed,
              updatedAt: _nextLmsChange(latest),
              syncStatus: 'pending',
            );
          },
        );
        if (mutations.isEmpty) return;
        updated = mutations.single.current;
      }
      if (!_isCurrentOwner(updated)) return;
      await _notificationService.cancelEventReminder(
        updated.id,
        reminderMinutesBeforeList: updated.reminderMinutesBeforeList,
      );
      if (!_isCurrentOwner(updated)) return;
      await _alarmService.cancelEventAlarm(updated.id);
      if (!_isCurrentOwner(updated)) return;
      if (!completed) {
        await _notificationService.scheduleEventReminder(updated);
        if (!_isCurrentOwner(updated)) return;
        await _alarmService.scheduleEventAlarm(updated);
      }
      if (!_isCurrentOwner(updated)) return;
      await _rescheduleMorningBriefingIfNeeded();
      if (!_isCurrentOwner(updated)) return;
      await _syncService.queueEventUpsert(updated);
      if (!_isCurrentOwner(updated)) return;
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
    EventCategory? Function()? lmsCategory,
    bool preserveLmsSource = false,
    bool Function()? isCurrent,
  }) async {
    final importedIds = <String>{};
    for (final event in events) {
      if (isCurrent != null && !isCurrent()) break;
      CalendarEvent imported;
      try {
        final prepared = prepare == null ? event : await prepare(event);
        if (isCurrent != null && !isCurrent()) break;
        if (prepared == null) continue;
        imported = prepared
            .copyWith(updatedAt: _clock.now(), syncStatus: 'pending')
            .normalizeAllDayBounds();
        if (imported.lms == null) {
          await _repository.save(imported);
        } else {
          if (!_isCurrentOwner(imported)) break;
          await _repository.mergeRestoredEventsAtomically(
            [imported],
            resolve: (latest, source) {
              if (isCurrent != null && !isCurrent() ||
                  !_isCurrentOwner(source)) {
                throw StateError('LMS 계정이 변경되었습니다.');
              }
              final destination = lmsCategory?.call();
              if (latest == null) {
                imported = source.copyWith(
                  category: destination,
                  colorValue: destination?.colorValue,
                );
                return imported;
              }
              final recoverStrippedSource =
                  latest.lms == null && latest.id.startsWith('lms:');
              if (!_isCurrentOwner(latest) && !recoverStrippedSource) {
                imported = latest;
                return latest;
              }
              // Re-read personal fields in the same write transaction, after
              // any editor save which completed while prepare was awaiting.
              imported =
                  (preserveLmsSource ? latest : _withLmsSource(latest, source))
                      .copyWith(
                        category: destination,
                        colorValue: destination?.colorValue,
                        createdAt: latest.createdAt,
                        updatedAt: _nextLmsChange(latest),
                        syncStatus: 'pending',
                      );
              return imported;
            },
          );
        }
      } on Object {
        continue;
      }

      importedIds.add(imported.id);
      if (isCurrent != null && !isCurrent()) break;
      if (imported.isDeleted || !_isCurrentOwner(imported)) continue;
      try {
        await _notificationService.scheduleEventReminder(imported);
      } on Object {
        // Import must preserve the event even if notification scheduling fails.
      }
      if (isCurrent != null && !isCurrent()) break;
      if (!_isCurrentOwner(imported)) break;
      try {
        await _alarmService.scheduleEventAlarm(imported);
      } on Object {
        // Imported events do not enable alarms by default; keep this best-effort.
      }
      if (isCurrent != null && !isCurrent()) break;
      if (!_isCurrentOwner(imported)) break;
      try {
        await _syncService.queueEventUpsert(imported);
      } on Object {
        // The pending sync status lets a later lifecycle sync retry the upload.
      }
    }

    if (importedIds.isNotEmpty && (isCurrent == null || isCurrent())) {
      await _rescheduleMorningBriefingIfNeeded();
      if (isCurrent == null || isCurrent()) await _refreshWidgets();
    }
    return importedIds;
  }

  Future<void> delete(String eventId, {bool Function()? isCurrent}) async {
    if (isCurrent != null && !isCurrent()) return;
    final stopwatch = Stopwatch()..start();
    try {
      final existing = await _repository.findById(eventId);
      bool current() =>
          (isCurrent == null || isCurrent()) &&
          (existing == null || _isCurrentOwner(existing));
      if (isCurrent != null && !isCurrent()) return;
      if (existing != null && !_isCurrentOwner(existing)) return;
      await _repository.delete(eventId);
      if (isCurrent != null && !isCurrent()) return;
      if (existing != null && !_isCurrentOwner(existing)) return;
      await _notificationService.cancelEventReminder(
        eventId,
        reminderMinutesBeforeList:
            existing?.reminderMinutesBeforeList ?? const [],
      );
      if (!current()) return;
      await _alarmService.cancelEventAlarm(eventId);
      if (!current()) return;
      await _rescheduleMorningBriefingIfNeeded();
      if (!current()) return;
      await _syncService.queueEventDelete(eventId);
      if (!current()) return;
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

  bool _isCurrentOwner(CalendarEvent event) => event.isVisibleToOwner(
    _settingsRepository.dailyAccount()?.googleAccount?.email,
  );

  DateTime _nextLmsChange(CalendarEvent latest) {
    final now = _clock.now();
    final previous = eventChangedAt(latest);
    return now.isAfter(previous)
        ? now
        : previous.add(const Duration(microseconds: 1));
  }

  CalendarEvent _withLmsSource(CalendarEvent personal, CalendarEvent source) =>
      personal.copyWith(
        title: source.title,
        startAt: source.startAt,
        endAt: source.endAt,
        allDay: source.allDay,
        recurrence: source.recurrence,
        location: source.location,
        clearLocation: source.location == null,
        url: source.url,
        clearUrl: source.url == null,
        weather: source.weather,
        clearWeather: source.weather == null,
        createdAt: source.createdAt,
        deletedAt: source.deletedAt,
        clearDeletedAt: source.deletedAt == null,
        lms: source.lms,
      );

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
