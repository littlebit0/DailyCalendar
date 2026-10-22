import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/analytics/product_analytics.dart';
import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/calendar/recurring_event_edit.dart';
import '../data/recurrence_expander.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/alarms/alarm_service.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/sync/sync_version.dart';
import '../../../core/time/korea_time.dart';
import '../domain/calendar_event.dart';
import '../domain/event_draft.dart';
import '../domain/event_category.dart';
import '../domain/event_deletion.dart';
import '../domain/event_repository.dart';
import '../domain/recurrence_rule.dart';

enum RecurringMoveScope { onlyThis, future }

class RecurringMoveResult {
  const RecurringMoveResult(this.event, {required this.followUpFailed});
  final CalendarEvent event;
  // The database commit succeeded even if a platform/network follow-up failed.
  final bool followUpFailed;
}

class EventCommandService {
  EventCommandService({
    required EventRepository repository,
    required SettingsRepository settingsRepository,
    required NotificationService notificationService,
    AlarmService alarmService = const UnsupportedAlarmService(),
    required SyncService syncService,
    ProductAnalytics analytics = const NoopProductAnalytics(),
    Future<void> Function()? onEventsChanged,
    void Function()? onFollowUpFailure,
    KoreaTime? clock,
    Uuid? uuid,
  }) : _repository = repository,
       _settingsRepository = settingsRepository,
       _notificationService = notificationService,
       _alarmService = alarmService,
       _syncService = syncService,
       _analytics = analytics,
       _onEventsChanged = onEventsChanged,
       _onFollowUpFailure = onFollowUpFailure,
       _clock = clock ?? const KoreaTime(),
       _uuid = uuid ?? const Uuid();

  final EventRepository _repository;
  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;
  final AlarmService _alarmService;
  final SyncService _syncService;
  final ProductAnalytics _analytics;
  final Future<void> Function()? _onEventsChanged;
  final void Function()? _onFollowUpFailure;
  final KoreaTime _clock;
  final Uuid _uuid;
  Future<void> _categoryUpdateTail = Future<void>.value();
  static final _recurringEffectTails = Expando<Future<void>>();

  Future<T> _serializeRecurringEffects<T>(Future<T> Function() action) {
    final previous = _recurringEffectTails[_repository] ?? Future<void>.value();
    final operation = previous.then((_) => action());
    _recurringEffectTails[_repository] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

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

  Future<void> save(
    CalendarEvent event, {
    bool preserveCategory = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    var updated = event
        .copyWith(updatedAt: _clock.now(), syncStatus: 'pending')
        .normalizeAllDayBounds();
    CalendarEvent? existing;
    try {
      existing = await _repository.findById(updated.id);
      if (preserveCategory && existing != null) {
        updated = updated.copyWith(
          category: _resolveStoredCategory(existing.category),
          colorValue: existing.colorValue,
        );
      }
      if (!_isCurrentOwner(existing?.lms != null ? existing! : updated)) return;
      // Persist intent before the database write so process termination cannot
      // lose recovery. Replay always rereads the database, never the draft.
      await _settingsRepository.stageEventFollowUp(
        updated.id,
        _uuid.v4(),
        _combinedReminderMinutes(existing, updated),
      );
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
              edited.copyWith(
                completed: latest.completed,
                category: preserveCategory
                    ? _resolveStoredCategory(latest.category)
                    : edited.category,
                colorValue: preserveCategory
                    ? latest.colorValue
                    : edited.colorValue,
              ),
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
    // From here the write succeeded: failures must not keep the draft in the
    // input or invite another create with a fresh ID.
    final followUpWatch = Stopwatch()..start();
    final succeeded = await retryPendingFollowUps(allowImmediate: true);
    unawaited(
      _analytics
          .record(
            AnalyticsRecord.eventSave(
              existing == null
                  ? AnalyticsOperation.create
                  : AnalyticsOperation.update,
              succeeded: succeeded,
              durationMs: followUpWatch.elapsedMilliseconds,
              phase: AnalyticsSavePhase.followUp,
            ),
          )
          .catchError((_) {}),
    );
  }

  Future<bool> retryPendingFollowUps({
    bool allowImmediate = false,
  }) => _serializeRecurringEffects(() async {
    var failed = false;
    Future<void> attempt(Future<void> Function() effect) async {
      try {
        await effect();
      } on Object {
        failed = true;
      }
    }

    await attempt(() async {
      final entries = _settingsRepository.pendingEventFollowUps();
      for (final entry in entries.entries) {
        var entryFailed = false;
        Future<void> run(Future<void> Function() effect) async {
          try {
            await effect();
          } on Object {
            entryFailed = true;
          }
        }

        await run(() async {
          final record = entry.value as Map;
          final token = record['token'] as String;
          final stages = List<String>.from(record['stages'] as List);
          // A recovered general reminder must again coordinate with its alarm.
          if (stages.contains('notification') && !stages.contains('alarm')) {
            stages.add('alarm');
          }
          Future<void> stage(
            String name,
            Future<void> Function() effect,
          ) async {
            if (!stages.contains(name)) return;
            await run(() async {
              if (!_isCurrentOwner((await _repository.findById(entry.key))!)) {
                entryFailed = true;
                return;
              }
              await effect();
              await _settingsRepository.completeEventFollowUpStage(
                entry.key,
                token,
                name,
              );
            });
          }

          final event = await _repository.findById(entry.key);
          if (event == null) {
            await _settingsRepository.acknowledgeEventFollowUp(
              entry.key,
              token,
            );
            return;
          }
          // Retain another owner's pending work without touching that account.
          if (!_isCurrentOwner(event)) return;
          await stage('notification', () async {
            await _notificationService.cancelEventReminder(
              event.id,
              reminderMinutesBeforeList: normalizeReminderMinutes([
                ...(record['reminders'] as List).whereType<int>(),
                ...event.reminderMinutesBeforeList,
              ]),
            );
            if (!event.isDeleted &&
                !event.completed &&
                _isCurrentOwner(event)) {
              await _notificationService.scheduleEventReminder(
                event,
                allowImmediate: allowImmediate,
              );
            }
          });
          await stage('alarm', () async {
            if (!_isCurrentOwner(event)) return;
            await _alarmService.cancelEventAlarm(event.id);
            if (!event.isDeleted &&
                !event.completed &&
                _isCurrentOwner(event)) {
              await _alarmService.scheduleEventAlarm(event);
            }
          });
          await stage('sync', () async {
            if (!_isCurrentOwner(event)) return;
            await _syncService.queueEventUpsert(event);
          });
          await stage('briefing', _rescheduleMorningBriefingIfNeeded);
          await stage('widgets', () async {
            await _onEventsChanged?.call();
          });
          if (!entryFailed && _isCurrentOwner(event)) {
            await _settingsRepository.acknowledgeEventFollowUp(
              entry.key,
              token,
            );
          }
        });
        failed = failed || entryFailed;
      }
    });
    if (failed) {
      try {
        _onFollowUpFailure?.call();
      } on Object {
        /* DB success is final. */
      }
    }
    return !failed;
  });

  Future<RecurringMoveResult> moveRecurringOccurrence({
    required CalendarEvent occurrence,
    required DateTime targetStart,
    required RecurringMoveScope scope,
    EventDraft? draft,
  }) async {
    final now = _clock.now();
    // Stable across retries/restarts; only one split may consume this occurrence.
    final movedId = _uuid.v5(
      Namespace.url.value,
      'daily:recurrence-move:${occurrence.id}:${occurrence.startAt.toIso8601String()}',
    );
    final deviceId = await _settingsRepository.deviceId();
    CalendarEvent? source;
    CalendarEvent? savedSource;
    CalendarEvent? moved;
    bool available = false;
    final placeholder = occurrence.copyWith(
      id: movedId,
      clearOccurrenceId: true,
    );
    await _repository.mergeRestoredEventsAtomically(
      [occurrence, placeholder],
      resolve: (latest, incoming) {
        if (incoming.id == occurrence.id) {
          if (latest == null ||
              latest.isDeleted ||
              !calendarEventCanMove(latest) ||
              !_isCurrentOwner(latest) ||
              !latest.recurrence.isRepeating) {
            throw StateError('반복 일정이 변경되었습니다. 다시 확인해 주세요.');
          }
          source = latest;
          available = RecurrenceExpander()
              .expand(
                latest,
                occurrence.startAt,
                occurrence.startAt.add(const Duration(microseconds: 1)),
              )
              .any((item) => item.startAt == occurrence.startAt);
          if (!available) {
            savedSource = latest;
            return latest; // A retry is resolved by the detached row.
          }
          final day = DateTime(
            occurrence.startAt.year,
            occurrence.startAt.month,
            occurrence.startAt.day,
          );
          final rule = scope == RecurringMoveScope.onlyThis
              ? latest.recurrence.copyWith(
                  excludedDates: {
                    ...latest.recurrence.excludedDates,
                    day,
                  }.toList()..sort(),
                )
              : latest.recurrence.copyWith(
                  until: DateTime(day.year, day.month, day.day - 1),
                  clearCount: true,
                );
          savedSource = latest.copyWith(
            recurrence: rule,
            updatedAt: now,
            syncStatus: 'pending',
          );
          return savedSource!;
        }
        if (latest != null) {
          if (available ||
              latest.isDeleted ||
              !calendarEventCanMove(latest) ||
              !_isCurrentOwner(latest)) {
            throw StateError('이미 처리된 반복 일정입니다. 다시 확인해 주세요.');
          }
          moved = latest;
          return latest;
        }
        if (!available || source == null) {
          throw StateError('해당 반복 회차가 변경되었습니다. 다시 확인해 주세요.');
        }
        final currentOccurrence = source!.copyWith(
          startAt: occurrence.startAt,
          endAt: occurrence.startAt.add(source!.duration),
        );
        final rule = scope == RecurringMoveScope.onlyThis
            ? const RecurrenceRule()
            : recurrenceRuleForMovedFuture(
                base: source!,
                occurrence: currentOccurrence,
                targetDate: targetStart,
              );
        final edited = draft == null
            ? shiftCalendarEventToStart(
                currentOccurrence,
                targetStart,
              ).copyWith(recurrence: rule)
            : applyRecurringEventDraft(
                latest: source!,
                occurrence: occurrence,
                draft: draft,
                scope: scope == RecurringMoveScope.onlyThis
                    ? RecurringEditScope.onlyThis
                    : RecurringEditScope.future,
              );
        moved = edited
            .copyWith(
              id: movedId,
              clearOccurrenceId: true,
              deviceId: deviceId,
              createdAt: now,
              updatedAt: now,
              syncStatus: 'pending',
            )
            .normalizeAllDayBounds();
        return moved!;
      },
    );
    // All local writes have committed. Attempt independent effects even when one
    // fails; pending DB rows remain available to the normal sync/startup recovery.
    return _finishRecurringChange(
      [savedSource!, moved!],
      moved!,
      previous: source,
    );
  }

  Future<RecurringMoveResult> _finishRecurringChange(
    List<CalendarEvent> events,
    CalendarEvent moved, {
    CalendarEvent? previous,
  }) => _serializeRecurringEffects(() async {
    var failed = false;
    Future<void> attempt(Future<void> Function() effect) async {
      try {
        await effect();
      } on Object {
        failed = true;
      }
    }

    for (final committed in events) {
      final event = await _repository.findById(committed.id);
      if (event == null || event.isDeleted || !_isCurrentOwner(event)) continue;
      await attempt(() async {
        await _notificationService.cancelEventReminder(
          event.id,
          reminderMinutesBeforeList: _combinedReminderMinutes(previous, event),
        );
        await _notificationService.scheduleEventReminder(event);
      });
      await attempt(() async {
        await _alarmService.cancelEventAlarm(event.id);
        await _alarmService.scheduleEventAlarm(event);
      });
      await attempt(() => _syncService.queueEventUpsert(event));
    }
    await attempt(_rescheduleMorningBriefingIfNeeded);
    await attempt(_refreshWidgets);
    return RecurringMoveResult(moved, followUpFailed: failed);
  });

  Future<RecurringMoveResult> editRecurringOccurrence({
    required CalendarEvent occurrence,
    required EventDraft draft,
    required RecurringEditScope scope,
  }) async {
    if (scope != RecurringEditScope.all) {
      return moveRecurringOccurrence(
        occurrence: occurrence,
        targetStart: draft.startAt,
        scope: scope == RecurringEditScope.onlyThis
            ? RecurringMoveScope.onlyThis
            : RecurringMoveScope.future,
        draft: draft,
      );
    }
    CalendarEvent? previous;
    CalendarEvent? saved;
    await _repository.mergeRestoredEventsAtomically(
      [occurrence],
      resolve: (latest, _) {
        if (latest == null ||
            latest.isDeleted ||
            !calendarEventCanMove(latest) ||
            !latest.recurrence.isRepeating ||
            !_isCurrentOwner(latest)) {
          throw StateError('반복 일정이 변경되었습니다. 다시 확인해 주세요.');
        }
        previous = latest;
        saved = applyRecurringEventDraft(
          latest: latest,
          occurrence: occurrence,
          draft: draft,
          scope: scope,
        ).copyWith(updatedAt: _clock.now(), syncStatus: 'pending');
        return saved!;
      },
    );
    return _finishRecurringChange([saved!], saved!, previous: previous);
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
      if (source.completed == completed &&
          (source.lms == null || source.lms!.manuallyCompleted == completed)) {
        return;
      }
      var updated = source.copyWith(
        completed: completed,
        updatedAt: _clock.now(),
        syncStatus: 'pending',
      );
      await _settingsRepository.stageEventFollowUp(
        updated.id,
        _uuid.v4(),
        _combinedReminderMinutes(source, updated),
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
              lms: latest.lms?.copyWith(manuallyCompleted: completed),
              updatedAt: _nextLmsChange(latest),
              syncStatus: 'pending',
            );
          },
        );
        if (mutations.isEmpty) return;
        updated = mutations.single.current;
      }
      await retryPendingFollowUps();
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
    final detachedID = _uuid.v5(
      Namespace.url.value,
      'daily:recurrence-completion:${source.id}:${occurrence.startAt.toIso8601String()}',
    );
    CalendarEvent? latestSource;
    CalendarEvent? updatedSeries;
    CalendarEvent? detachedOccurrence;
    var available = false;
    await _settingsRepository.stageEventFollowUp(
      source.id,
      _uuid.v4(),
      source.reminderMinutesBeforeList,
    );
    await _settingsRepository.stageEventFollowUp(
      detachedID,
      _uuid.v4(),
      occurrence.reminderMinutesBeforeList,
    );
    await _repository.mergeRestoredEventsAtomically(
      [source, occurrence.copyWith(id: detachedID, clearOccurrenceId: true)],
      resolve: (latest, incoming) {
        if (incoming.id == source.id) {
          if (latest == null ||
              latest.isDeleted ||
              !latest.recurrence.isRepeating ||
              !calendarEventCanMove(latest) ||
              !_isCurrentOwner(latest)) {
            throw StateError('반복 일정이 변경되었습니다. 다시 확인해 주세요.');
          }
          latestSource = latest;
          available = RecurrenceExpander()
              .expand(
                latest,
                occurrence.startAt,
                occurrence.startAt.add(const Duration(microseconds: 1)),
              )
              .any((item) => item.startAt == occurrence.startAt);
          updatedSeries = available
              ? latest.copyWith(
                  recurrence: latest.recurrence.copyWith(
                    excludedDates: {
                      ...latest.recurrence.excludedDates.map(
                        (date) => DateTime(date.year, date.month, date.day),
                      ),
                      occurrenceDay,
                    }.toList()..sort(),
                  ),
                  updatedAt: now,
                  syncStatus: 'pending',
                )
              : latest;
          return updatedSeries!;
        }
        if (latest != null) {
          if (latest.isDeleted || !_isCurrentOwner(latest)) {
            throw StateError('해당 회차가 삭제되었습니다. 다시 확인해 주세요.');
          }
          detachedOccurrence = latest.copyWith(
            completed: completed,
            updatedAt: now,
            syncStatus: 'pending',
          );
        } else {
          if (!available || latestSource == null) {
            throw StateError('해당 반복 회차가 변경되었습니다. 다시 확인해 주세요.');
          }
          detachedOccurrence = latestSource!
              .copyWith(
                id: detachedID,
                clearOccurrenceId: true,
                recurrence: const RecurrenceRule(),
                startAt: occurrence.startAt,
                endAt: occurrence.startAt.add(latestSource!.duration),
                completed: completed,
                createdAt: now,
                updatedAt: now,
                syncStatus: 'pending',
              )
              .normalizeAllDayBounds();
        }
        return detachedOccurrence!;
      },
    );

    await retryPendingFollowUps();
  }

  Future<Set<String>> importBatch(
    Iterable<CalendarEvent> events, {
    Future<CalendarEvent?> Function(CalendarEvent event)? prepare,
    CalendarEvent? Function(CalendarEvent? latest, CalendarEvent incoming)?
    resolveLatest,
    EventCategory? Function()? lmsCategory,
    bool preserveLmsSource = false,
    bool Function()? isCurrent,
    Set<String>? skippedDeleted,
  }) async {
    final importedIds = <String>{};
    for (final event in events) {
      if (isCurrent != null && !isCurrent()) break;
      CalendarEvent imported;
      try {
        if (resolveLatest != null) {
          // The decision reads the current row inside the write transaction,
          // so an edit or deletion saved while the import ran cannot be
          // overwritten by an older snapshot. Returning null keeps the row.
          CalendarEvent? decided;
          CalendarEvent resolve(CalendarEvent? latest, CalendarEvent incoming) {
            if (isCurrent != null && !isCurrent()) {
              throw StateError('가져오기 대상이 변경되었습니다.');
            }
            final result = resolveLatest(latest, incoming);
            if (result == null) {
              if (latest == null) throw StateError('저장할 일정이 없습니다.');
              return latest;
            }
            decided = result
                .copyWith(updatedAt: _clock.now(), syncStatus: 'pending')
                .normalizeAllDayBounds();
            return decided!;
          }

          // With [skippedDeleted], a recorded deletion is checked in the
          // write transaction so a compacted deletion is never recreated.
          final repository = _repository;
          final mutations =
              skippedDeleted != null && repository is EventSyncMaintenance
              ? await (repository as EventSyncMaintenance)
                    .mergeUndeletedEventsAtomically(
                      [event],
                      resolve: resolve,
                      skipped: skippedDeleted,
                    )
              : await _repository.mergeRestoredEventsAtomically([
                  event,
                ], resolve: resolve);
          if (isCurrent != null && !isCurrent()) break;
          if (mutations.isEmpty || decided == null) continue;
          imported = decided!;
        } else {
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
                    completed: preserveLmsSource
                        ? source.completed
                        : source.lms?.sourceCompleted ?? source.completed,
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
                    (preserveLmsSource
                            ? latest
                            : _withLmsSource(latest, source))
                        .copyWith(
                          category: destination,
                          colorValue: destination?.colorValue,
                          // User completion wins over a negative school state.
                          // Read its provenance in this transaction, not from
                          // the possibly stale snapshot prepared by the fetch.
                          lms: preserveLmsSource
                              ? latest.lms
                              : source.lms?.copyWith(
                                  manuallyCompleted:
                                      latest.lms?.manuallyCompleted ?? false,
                                ),
                          completed: preserveLmsSource
                              ? latest.completed
                              : latest.lms?.manuallyCompleted == true
                              ? true
                              : source.lms?.sourceCompleted ?? latest.completed,
                          createdAt: latest.createdAt,
                          updatedAt: _nextLmsChange(latest),
                          syncStatus: 'pending',
                        );
                return imported;
              },
            );
          }
        }
      } on Object {
        continue;
      }

      importedIds.add(imported.id);
      if (isCurrent != null && !isCurrent()) break;
      if (imported.isDeleted || !_isCurrentOwner(imported)) continue;
      try {
        if (imported.lms != null && imported.completed) {
          await _notificationService.cancelEventReminder(
            imported.id,
            reminderMinutesBeforeList: imported.reminderMinutesBeforeList,
          );
        } else {
          await _notificationService.scheduleEventReminder(imported);
        }
      } on Object {
        // Import must preserve the event even if notification scheduling fails.
      }
      if (isCurrent != null && !isCurrent()) break;
      if (!_isCurrentOwner(imported)) break;
      try {
        if (imported.lms != null && imported.completed) {
          await _alarmService.cancelEventAlarm(imported.id);
        } else {
          await _alarmService.scheduleEventAlarm(imported);
        }
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
    bool Function()? isCurrent,
  }) {
    final operation = _categoryUpdateTail.then(
      (_) => _updateCategoryUsage(
        previous: previous,
        updated: updated,
        isCurrent: isCurrent,
      ),
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
    bool Function()? isCurrent,
  }) async {
    if (isCurrent != null && !isCurrent()) {
      throw StateError('Category update cancelled');
    }
    final affected = await _repository.updateCategoryReferences(
      previous: previous,
      updated: updated,
      updatedAt: _clock.now(),
    );
    if (affected.isEmpty) {
      return;
    }

    // The rows are already saved as pending; a failed upload is retried by the
    // next sync and must not look like a failed category update.
    for (final event in affected) {
      // Rows stay pending; a cancelled caller only stops queueing uploads.
      if (isCurrent != null && !isCurrent()) break;
      try {
        await _syncService.queueEventUpsert(event);
      } on Object {
        /* pending status keeps the upload retryable */
      }
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

  EventCategory _resolveStoredCategory(EventCategory category) {
    final categories = _settingsRepository.load().categories;
    final exact = categories.where((c) => c.id == category.id).firstOrNull;
    if (exact != null) return exact;
    final legacy = categories
        .where(
          (c) =>
              c.label == category.label &&
              EventCategory.fromStored(c.label).id == category.id,
        )
        .toList();
    return legacy.length == 1 ? legacy.single : category;
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
