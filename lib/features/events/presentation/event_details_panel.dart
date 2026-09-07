import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/analytics/product_analytics.dart';
import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/calendar/calendar_event_ordering.dart';
import '../../../core/maps/map_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../../core/theme/calendar_date_color.dart';
import '../../calendar/widgets/calendar_event_drag_layer.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import '../domain/recurrence_rule.dart';
import 'event_editor_dialog.dart';
import 'event_completion_action.dart';

enum _RecurringChangeScope { onlyThis, future, all }

class EventDetailsPanel extends ConsumerWidget {
  const EventDetailsPanel({
    super.key,
    required this.date,
    required this.events,
    this.scrollController,
    this.initialEvent,
    this.onEventDropped,
    this.onEventDragStateChanged,
    this.onEventDragInteractionStateChanged,
    this.onEventDragGlobalPositionChanged,
    this.compactDragFeedbackListenable,
    this.dragFeedbackSpecListenable,
    this.dragOrigin = CalendarEventDragOrigin.calendar,
    this.colorWeekdayOnly = false,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final ScrollController? scrollController;
  final CalendarEvent? initialEvent;
  final CalendarEventDropCallback? onEventDropped;
  final ValueChanged<bool>? onEventDragStateChanged;
  final ValueChanged<bool>? onEventDragInteractionStateChanged;
  final ValueChanged<Offset>? onEventDragGlobalPositionChanged;
  final ValueListenable<bool>? compactDragFeedbackListenable;
  final ValueListenable<CalendarEventDragFeedbackSpec>?
  dragFeedbackSpecListenable;
  final CalendarEventDragOrigin dragOrigin;
  final bool colorWeekdayOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final selectedEvent = initialEvent;
    if (selectedEvent != null) {
      return _EventDetailSheet(
        event: selectedEvent,
        onEdit: selectedEvent.readOnly
            ? null
            : () => unawaited(
                _editEvent(
                  context,
                  ref,
                  selectedEvent,
                  settings.categories,
                  settings.defaultReminderMinutesList,
                ),
              ),
        onDelete: selectedEvent.readOnly
            ? null
            : () => unawaited(_deleteEvent(context, ref, selectedEvent)),
      );
    }
    final dateLabel = _formatDateLabel(context, date);
    final weekday = DateFormat.EEEE(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
    final weekdayIndex = dateLabel.indexOf(weekday);
    final weekdayColor = colorWeekdayOnly
        ? calendarDateAccent(
            date,
            isHoliday:
                settings.calendarShowHolidays &&
                ref.read(koreanHolidayServiceProvider).isPublicHoliday(date),
            holidayColorValue: settings.holidayCategory.colorValue,
          )
        : null;
    final liveEventsAsync = ref.watch(eventsInRangeProvider(_dayRange(date)));
    final dayEvents = liveEventsAsync.maybeWhen(
      data: (items) => _eventsForDay(items, date, settings),
      orElse: () => sortedCalendarEvents(
        events,
        priority: settings.calendarEventSortPriority,
        categoryOrder: settings.categories
            .map((category) => category.id)
            .toList(),
        manualOrder:
            settings
                .calendarManualEventOrders[calendarDateKey(date)]
                ?.eventKeys ??
            const <String>[],
      ),
    );
    final panel = Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text.rich(
                      key: const ValueKey('event-details-date-label'),
                      TextSpan(
                        children: weekdayColor != null && weekdayIndex >= 0
                            ? [
                                TextSpan(
                                  text: dateLabel.substring(0, weekdayIndex),
                                ),
                                TextSpan(
                                  text: weekday,
                                  style: TextStyle(color: weekdayColor),
                                ),
                                TextSpan(
                                  text: dateLabel.substring(
                                    weekdayIndex + weekday.length,
                                  ),
                                ),
                              ]
                            : [TextSpan(text: dateLabel)],
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('일정 추가'),
                  onPressed: () => _addEvent(
                    context,
                    ref,
                    settings.categories,
                    settings.defaultReminderMinutesList,
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dayEvents.isEmpty
                  ? ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          context.tr('일정이 없습니다.'),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    )
                  : _DraggableEventList(
                      date: date,
                      events: dayEvents,
                      scrollController: scrollController,
                      onEventDropped: onEventDropped,
                      onEventDragStateChanged: onEventDragStateChanged,
                      onEventDragInteractionStateChanged:
                          onEventDragInteractionStateChanged,
                      onEventDragGlobalPositionChanged:
                          onEventDragGlobalPositionChanged,
                      compactDragFeedbackListenable:
                          compactDragFeedbackListenable,
                      dragFeedbackSpecListenable: dragFeedbackSpecListenable,
                      dragOrigin: dragOrigin,
                      itemBuilder: (context, event) => _EventTile(
                        event: event,
                        onOpen: () => _openEventDetails(
                          context,
                          ref,
                          event,
                          settings.categories,
                          settings.defaultReminderMinutesList,
                        ),
                        onEdit: event.readOnly
                            ? null
                            : () => _editEvent(
                                context,
                                ref,
                                event,
                                settings.categories,
                                settings.defaultReminderMinutesList,
                              ),
                        onDelete: event.readOnly
                            ? null
                            : () => _deleteEvent(context, ref, event),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    if (onEventDropped == null) {
      return panel;
    }
    return CalendarEventDateDropTarget(
      key: const ValueKey('event-details-date-drop-target'),
      date: date,
      onEventDropped: onEventDropped,
      borderRadius: BorderRadius.zero,
      child: panel,
    );
  }

  Future<void> _openEventDetails(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    List<EventCategory> categories,
    List<int> defaultReminderMinutesList,
  ) async {
    if (!context.mounted) {
      return;
    }

    unawaited(
      ref
          .read(productAnalyticsProvider)
          .record(AnalyticsRecord.screenView(AnalyticsScreen.eventDetails))
          .catchError((_) {}),
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _EventDetailSheet(
        event: event,
        onEdit: event.readOnly
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(
                  _editEvent(
                    context,
                    ref,
                    event,
                    categories,
                    defaultReminderMinutesList,
                  ),
                );
              },
        onDelete: event.readOnly
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(_deleteEvent(context, ref, event));
              },
      ),
    );
  }

  Future<void> _addEvent(
    BuildContext context,
    WidgetRef ref,
    List<EventCategory> categories,
    List<int> defaultReminderMinutesList,
  ) async {
    final analytics = ref.read(productAnalyticsProvider);
    final stopwatch = Stopwatch()..start();
    unawaited(
      analytics
          .record(
            AnalyticsRecord.eventEditorOpened(
              AnalyticsEditorMode.create,
              trigger: AnalyticsTrigger.manual,
            ),
          )
          .catchError((_) {}),
    );
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: date,
        categories: categories,
        defaultReminderMinutesList: defaultReminderMinutesList,
        alarmService: ref.read(alarmServiceProvider),
      ),
    );
    unawaited(
      analytics
          .record(
            AnalyticsRecord.eventEditorCompleted(
              AnalyticsEditorMode.create,
              outcome: draft == null
                  ? AnalyticsOutcome.canceled
                  : AnalyticsOutcome.succeeded,
              durationMs: stopwatch.elapsedMilliseconds,
            ),
          )
          .catchError((_) {}),
    );
    if (draft != null) {
      await ref.read(eventCommandServiceProvider).create(draft);
    }
  }

  Future<void> _editEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    List<EventCategory> categories,
    List<int> defaultReminderMinutesList,
  ) async {
    final commandService = ref.read(eventCommandServiceProvider);
    final analytics = ref.read(productAnalyticsProvider);
    final stopwatch = Stopwatch()..start();
    unawaited(
      analytics
          .record(
            AnalyticsRecord.eventEditorOpened(
              AnalyticsEditorMode.edit,
              trigger: AnalyticsTrigger.manual,
            ),
          )
          .catchError((_) {}),
    );
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: event.startAt,
        event: event,
        categories: categories,
        defaultReminderMinutesList: defaultReminderMinutesList,
        alarmService: ref.read(alarmServiceProvider),
      ),
    );
    unawaited(
      analytics
          .record(
            AnalyticsRecord.eventEditorCompleted(
              AnalyticsEditorMode.edit,
              outcome: draft == null
                  ? AnalyticsOutcome.canceled
                  : AnalyticsOutcome.succeeded,
              durationMs: stopwatch.elapsedMilliseconds,
            ),
          )
          .catchError((_) {}),
    );
    if (draft == null) {
      return;
    }

    if (!event.isRecurring) {
      await commandService.save(_applyDraft(event, draft));
      return;
    }
    if (!context.mounted) {
      return;
    }

    final scope = await _showRecurringScopeDialog(
      context,
      title: context.tr('반복 일정 수정'),
      actionLabel: context.tr('수정'),
    );
    if (scope == null) {
      return;
    }

    final base =
        await ref.read(eventRepositoryProvider).findById(event.id) ?? event;
    switch (scope) {
      case _RecurringChangeScope.onlyThis:
        await commandService.save(_excludeOccurrence(base, event.startAt));
        await commandService.create(
          draft.copyWith(recurrence: const RecurrenceRule()),
        );
      case _RecurringChangeScope.future:
        await commandService.save(_endBefore(base, event.startAt));
        await commandService.create(draft);
      case _RecurringChangeScope.all:
        await commandService.save(_applyDraft(base, draft));
    }
  }

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final commandService = ref.read(eventCommandServiceProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('일정 삭제')),
        content: Text(
          context.tr('"{title}" 일정을 삭제할까요?', args: {'title': event.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('삭제')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    if (event.isRecurring) {
      if (!context.mounted) {
        return;
      }
      final scope = await _showRecurringScopeDialog(
        context,
        title: context.tr('반복 일정 삭제'),
        actionLabel: context.tr('삭제'),
        allScopeLabel: context.tr('전체 삭제'),
      );
      if (scope == null) {
        return;
      }
      final base =
          await ref.read(eventRepositoryProvider).findById(event.id) ?? event;
      switch (scope) {
        case _RecurringChangeScope.onlyThis:
          await commandService.save(_excludeOccurrence(base, event.startAt));
        case _RecurringChangeScope.future:
          await commandService.save(_endBefore(base, event.startAt));
        case _RecurringChangeScope.all:
          await commandService.delete(event.id);
      }
    } else {
      await commandService.delete(event.id);
    }
  }

  CalendarEvent _applyDraft(CalendarEvent event, EventDraft draft) {
    return event.copyWith(
      title: draft.title,
      memo: draft.memo,
      location: draft.location,
      url: draft.url,
      weather: draft.weather,
      startAt: draft.startAt,
      endAt: draft.endAt,
      allDay: draft.allDay,
      category: draft.category,
      colorValue: draft.colorValue ?? draft.category.colorValue,
      reminderMinutesBeforeList: draft.reminderMinutesBeforeList,
      recurrence: draft.recurrence,
      showDday: draft.showDday,
      alarmEnabled: draft.alarmEnabled,
      allDayAlarmMinutes: draft.allDayAlarmMinutes,
      holiday: draft.category.id == EventCategory.holiday.id,
      clearMemo: draft.memo == null,
      clearLocation: draft.location == null,
      clearUrl: draft.url == null,
      clearWeather: draft.weather == null,
      clearReminder: draft.reminderMinutesBeforeList.isEmpty,
    );
  }

  CalendarEvent _excludeOccurrence(CalendarEvent base, DateTime occurrence) {
    final occurrenceDay = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
    );
    final excluded = {
      ...base.recurrence.excludedDates.map(
        (date) => DateTime(date.year, date.month, date.day),
      ),
      occurrenceDay,
    }.toList()..sort((a, b) => a.compareTo(b));
    return base.copyWith(
      recurrence: base.recurrence.copyWith(excludedDates: excluded),
    );
  }

  CalendarEvent _endBefore(CalendarEvent base, DateTime occurrence) {
    final until = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
    ).subtract(const Duration(days: 1));
    return base.copyWith(
      recurrence: base.recurrence.copyWith(until: until, clearCount: true),
    );
  }

  Future<_RecurringChangeScope?> _showRecurringScopeDialog(
    BuildContext context, {
    required String title,
    required String actionLabel,
    String? allScopeLabel,
  }) {
    return showDialog<_RecurringChangeScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          context.tr(
            '이 반복 일정의 어느 범위에 {action}을 적용할까요?',
            args: {'action': actionLabel},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('취소')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringChangeScope.onlyThis),
            child: Text(context.tr('이 일정만')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringChangeScope.future),
            child: Text(context.tr('이후 일정')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringChangeScope.all),
            child: Text(allScopeLabel ?? context.tr('전체 반복')),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(BuildContext context, DateTime date) {
    return DateFormat.yMMMMEEEEd(
      context.l10n.locale.toLanguageTag(),
    ).format(date);
  }
}

class _DraggableEventList extends StatefulWidget {
  const _DraggableEventList({
    required this.date,
    required this.events,
    required this.scrollController,
    required this.onEventDropped,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
    required this.onEventDragGlobalPositionChanged,
    required this.compactDragFeedbackListenable,
    required this.dragFeedbackSpecListenable,
    required this.dragOrigin,
    required this.itemBuilder,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final ScrollController? scrollController;
  final CalendarEventDropCallback? onEventDropped;
  final ValueChanged<bool>? onEventDragStateChanged;
  final ValueChanged<bool>? onEventDragInteractionStateChanged;
  final ValueChanged<Offset>? onEventDragGlobalPositionChanged;
  final ValueListenable<bool>? compactDragFeedbackListenable;
  final ValueListenable<CalendarEventDragFeedbackSpec>?
  dragFeedbackSpecListenable;
  final CalendarEventDragOrigin dragOrigin;
  final Widget Function(BuildContext context, CalendarEvent event) itemBuilder;

  @override
  State<_DraggableEventList> createState() => _DraggableEventListState();
}

class _DraggableEventListState extends State<_DraggableEventList> {
  static const _itemSpacing = 8.0;
  static const _reorderAnimationDuration = Duration(milliseconds: 180);

  final Map<String, GlobalKey> _itemMeasureKeys = {};
  String? _draggedEventKey;
  CalendarEvent? _draggedEvent;
  int? _hoverInsertionIndex;
  double _draggedExtent = 0;
  bool _eventDropAccepted = false;
  bool _settlingAcceptedDrop = false;

  @override
  void didUpdateWidget(covariant _DraggableEventList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKeys = widget.events.map(calendarEventOrderKey).toSet();
    _itemMeasureKeys.removeWhere((key, value) => !currentKeys.contains(key));
  }

  @override
  Widget build(BuildContext context) {
    final draggedKey = _draggedEventKey;
    final sourceIndex = draggedKey == null
        ? -1
        : widget.events.indexWhere(
            (event) => calendarEventOrderKey(event) == draggedKey,
          );
    final remainingCount = widget.events.length - (sourceIndex >= 0 ? 1 : 0);
    final activeInsertionIndex = draggedKey == null
        ? null
        : (_hoverInsertionIndex ?? sourceIndex.clamp(0, remainingCount))
              .clamp(0, remainingCount)
              .toInt();
    final children = <Widget>[];
    var remainingIndex = 0;

    for (var index = 0; index < widget.events.length; index += 1) {
      final event = widget.events[index];
      final eventKey = calendarEventOrderKey(event);
      final isDraggedEvent = eventKey == draggedKey;
      if (!isDraggedEvent) {
        children.add(
          _EventInsertionGap(
            key: ValueKey('event-reorder-gap-$remainingIndex'),
            date: widget.date,
            insertionIndex: remainingIndex,
            extent: _draggedExtent,
            active: activeInsertionIndex == remainingIndex,
            duration: _reorderAnimationDuration,
            animate: !_settlingAcceptedDrop,
            onEventDropped: widget.onEventDropped,
            onEventDropAccepted: _setEventDropAccepted,
            child:
                _eventDropAccepted &&
                    activeInsertionIndex == remainingIndex &&
                    _draggedEvent != null
                ? IgnorePointer(
                    child: KeyedSubtree(
                      key: ValueKey(
                        'event-accepted-preview-${calendarEventOrderKey(_draggedEvent!)}',
                      ),
                      child: widget.itemBuilder(context, _draggedEvent!),
                    ),
                  )
                : null,
          ),
        );
      }
      children.add(_buildEventEntry(event, index, isDraggedEvent));
      if (!isDraggedEvent) {
        remainingIndex += 1;
      }
    }
    children.add(
      _EventInsertionGap(
        key: ValueKey('event-reorder-gap-$remainingIndex'),
        date: widget.date,
        insertionIndex: remainingIndex,
        extent: _draggedExtent,
        active: activeInsertionIndex == remainingIndex,
        duration: _reorderAnimationDuration,
        animate: !_settlingAcceptedDrop,
        onEventDropped: widget.onEventDropped,
        onEventDropAccepted: _setEventDropAccepted,
        child:
            _eventDropAccepted &&
                activeInsertionIndex == remainingIndex &&
                _draggedEvent != null
            ? IgnorePointer(
                child: KeyedSubtree(
                  key: ValueKey(
                    'event-accepted-preview-${calendarEventOrderKey(_draggedEvent!)}',
                  ),
                  child: widget.itemBuilder(context, _draggedEvent!),
                ),
              )
            : null,
      ),
    );

    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }

  Widget _buildEventEntry(
    CalendarEvent event,
    int itemIndex,
    bool isDraggedEvent,
  ) {
    final eventKey = calendarEventOrderKey(event);
    final measureKey = _itemMeasureKeys.putIfAbsent(eventKey, GlobalKey.new);
    final entry = Padding(
      padding: const EdgeInsets.only(bottom: _itemSpacing),
      child: _EventOrderDropTarget(
        key: ValueKey('event-order-drop-${event.occurrenceId ?? event.id}'),
        date: widget.date,
        events: widget.events,
        itemIndex: itemIndex,
        onInsertionIndexChanged: _setHoverInsertionIndex,
        onEventDropped: widget.onEventDropped,
        onEventDropAccepted: _setEventDropAccepted,
        child: SizedBox(
          key: measureKey,
          child: CalendarEventDraggable(
            key: ValueKey('event-drag-${event.occurrenceId ?? event.id}'),
            event: event,
            enabled: widget.onEventDropped != null,
            onDragStateChanged: (dragging) =>
                _setEventDragging(event, dragging),
            onDragInteractionStateChanged:
                widget.onEventDragInteractionStateChanged,
            onDragGlobalPositionChanged:
                widget.onEventDragGlobalPositionChanged,
            compactFeedbackListenable: widget.compactDragFeedbackListenable,
            feedbackSpecListenable: widget.dragFeedbackSpecListenable,
            origin: widget.dragOrigin,
            child: widget.itemBuilder(context, event),
          ),
        ),
      ),
    );
    if (_settlingAcceptedDrop) {
      return entry;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('event-reorder-entry-$eventKey'),
      duration: _reorderAnimationDuration,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(end: isDraggedEvent ? 0 : 1),
      child: entry,
      builder: (context, factor, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: factor,
          child: child,
        ),
      ),
    );
  }

  void _setEventDragging(CalendarEvent event, bool dragging) {
    final eventKey = calendarEventOrderKey(event);
    if (dragging) {
      final sourceIndex = widget.events.indexWhere(
        (candidate) => calendarEventOrderKey(candidate) == eventKey,
      );
      final renderObject = _itemMeasureKeys[eventKey]?.currentContext
          ?.findRenderObject();
      final measuredHeight = renderObject is RenderBox
          ? renderObject.size.height
          : 0.0;
      if (mounted) {
        setState(() {
          _draggedEventKey = eventKey;
          _draggedEvent = event;
          _draggedExtent = measuredHeight + _itemSpacing;
          _hoverInsertionIndex = sourceIndex.clamp(0, widget.events.length - 1);
          _eventDropAccepted = false;
        });
      }
      widget.onEventDragStateChanged?.call(true);
      return;
    }
    if (_draggedEventKey != eventKey) {
      return;
    }
    if (mounted) {
      final settleAcceptedDrop = _eventDropAccepted;
      setState(() {
        _draggedEventKey = null;
        _draggedEvent = null;
        _hoverInsertionIndex = null;
        _draggedExtent = 0;
        _eventDropAccepted = false;
        _settlingAcceptedDrop = settleAcceptedDrop;
      });
      if (settleAcceptedDrop) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _settlingAcceptedDrop) {
            setState(() => _settlingAcceptedDrop = false);
          }
        });
      }
    }
    widget.onEventDragStateChanged?.call(false);
  }

  void _setHoverInsertionIndex(int index) {
    if (_draggedEventKey == null || _hoverInsertionIndex == index) {
      return;
    }
    setState(() => _hoverInsertionIndex = index);
  }

  void _setEventDropAccepted(CalendarEvent event) {
    if (_draggedEventKey != calendarEventOrderKey(event) ||
        _eventDropAccepted) {
      return;
    }
    setState(() => _eventDropAccepted = true);
  }
}

class _EventOrderDropTarget extends StatefulWidget {
  const _EventOrderDropTarget({
    super.key,
    required this.date,
    required this.events,
    required this.itemIndex,
    required this.onInsertionIndexChanged,
    required this.onEventDropped,
    required this.onEventDropAccepted,
    required this.child,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final int itemIndex;
  final ValueChanged<int> onInsertionIndexChanged;
  final CalendarEventDropCallback? onEventDropped;
  final ValueChanged<CalendarEvent> onEventDropAccepted;
  final Widget child;

  @override
  State<_EventOrderDropTarget> createState() => _EventOrderDropTargetState();
}

class _EventOrderDropTargetState extends State<_EventOrderDropTarget> {
  var _insertAfter = false;

  @override
  Widget build(BuildContext context) {
    final onEventDropped = widget.onEventDropped;
    if (onEventDropped == null) {
      return widget.child;
    }
    return DragTarget<CalendarEventDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (!calendarEventCanMove(details.data.event)) return false;
        _updateHover(details.data.event, details.offset);
        return true;
      },
      onMove: (details) => _updateHover(details.data.event, details.offset),
      onAcceptWithDetails: (details) {
        final targetIndex = _resolvedTargetIndex(details.data.event);
        widget.onInsertionIndexChanged(targetIndex);
        widget.onEventDropAccepted(details.data.event);
        unawaited(
          performCalendarEventDrop(
            details.data.event,
            () => onEventDropped(details.data.event, widget.date, targetIndex),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) => widget.child,
    );
  }

  void _updateHover(CalendarEvent draggedEvent, Offset globalOffset) {
    final renderObject = context.findRenderObject();
    final nextInsertAfter = renderObject is RenderBox
        ? renderObject.globalToLocal(globalOffset).dy >=
              renderObject.size.height / 2
        : false;
    if (_insertAfter != nextInsertAfter) {
      _insertAfter = nextInsertAfter;
    }
    widget.onInsertionIndexChanged(_resolvedTargetIndex(draggedEvent));
  }

  int _resolvedTargetIndex(CalendarEvent draggedEvent) {
    final draggedKey = calendarEventOrderKey(draggedEvent);
    final targetEvent = widget.events[widget.itemIndex];
    if (calendarEventOrderKey(targetEvent) == draggedKey ||
        targetEvent.id == draggedEvent.id) {
      return widget.itemIndex;
    }
    var targetIndex = widget.itemIndex + (_insertAfter ? 1 : 0);
    final sourceIndex = widget.events.indexWhere(
      (event) =>
          calendarEventOrderKey(event) == draggedKey ||
          event.id == draggedEvent.id,
    );
    if (sourceIndex >= 0 && sourceIndex < targetIndex) {
      targetIndex -= 1;
    }
    return targetIndex.clamp(0, widget.events.length).toInt();
  }
}

class _EventInsertionGap extends StatelessWidget {
  const _EventInsertionGap({
    super.key,
    required this.date,
    required this.insertionIndex,
    required this.extent,
    required this.active,
    required this.duration,
    required this.animate,
    required this.onEventDropped,
    required this.onEventDropAccepted,
    this.child,
  });

  final DateTime date;
  final int insertionIndex;
  final double extent;
  final bool active;
  final Duration duration;
  final bool animate;
  final CalendarEventDropCallback? onEventDropped;
  final ValueChanged<CalendarEvent> onEventDropAccepted;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final onDropped = onEventDropped;
    final visible = active && extent > 0 && onDropped != null;
    final content = visible
        ? SizedBox(
            height: extent,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DragTarget<CalendarEventDragPayload>(
                onWillAcceptWithDetails: (details) =>
                    calendarEventCanMove(details.data.event),
                onAcceptWithDetails: (details) {
                  onEventDropAccepted(details.data.event);
                  unawaited(
                    performCalendarEventDrop(
                      details.data.event,
                      () => onDropped(details.data.event, date, insertionIndex),
                    ),
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  return child ?? const SizedBox.expand();
                },
              ),
            ),
          )
        : const SizedBox.shrink();
    if (!animate) {
      return content;
    }
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTimeLabel(context, event);
    final categoryColor = Color(event.colorValue);
    final color = calendarEventAccentColor(
      context,
      categoryColor,
      completed: event.completed,
    );
    final backgroundColor = calendarEventBackgroundColor(
      context,
      categoryColor,
      completed: event.completed,
      categoryAlpha: event.holiday ? 0.07 : 0.08,
    );
    final title = context.l10n.eventTitle(event.title, holiday: event.holiday);
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: EventCompletionAction(
              event: event,
              builder: (onDoubleTap) => InkWell(
                key: ValueKey('event-open-${event.id}'),
                onTap: onOpen,
                onDoubleTap: onDoubleTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          textAlign: TextAlign.start,
                                          style: calendarEventCompletionStyle(
                                            context,
                                            const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                            completed: event.completed,
                                            eventColor: categoryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (event.readOnly)
                                  const Icon(Icons.lock_outline, size: 16),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            if (event.showDday)
                              Text(
                                _formatDday(event),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            if (event.location != null &&
                                event.location!.isNotEmpty)
                              Text(
                                event.location!,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            if (event.location != null &&
                                event.location!.isNotEmpty)
                              TextButton.icon(
                                onPressed: () =>
                                    MapLauncher().openLocation(event.location!),
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: Text(context.tr('지도 바로가기')),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 28),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            if (event.weather != null &&
                                event.weather!.isNotEmpty)
                              Text(
                                '날씨: ${event.weather!}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            if (event.url != null && event.url!.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _openUrl(event.url!),
                                icon: const Icon(Icons.link, size: 16),
                                label: Text(
                                  event.url!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 28),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!event.readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      key: ValueKey('event-edit-${event.id}'),
                      tooltip: context.tr('수정'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      key: ValueKey('event-delete-${event.id}'),
                      tooltip: context.tr('삭제'),
                      onPressed: onDelete == null
                          ? null
                          : () => unawaited(onDelete!()),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final raw = value.trim();
    final uri = Uri.tryParse(
      raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://$raw',
    );
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatTimeLabel(BuildContext context, CalendarEvent event) {
    final locale = context.l10n.locale.toLanguageTag();
    final dateFormatter = DateFormat.yMMMd(locale);
    final timeFormatter = DateFormat.Hm(locale);
    if (event.allDay) {
      final inclusiveEnd = event.endAt.subtract(const Duration(days: 1));
      if (_sameDay(event.startAt, inclusiveEnd)) {
        return context.tr('종일');
      }
      return '${dateFormatter.format(event.startAt)} - '
          '${dateFormatter.format(inclusiveEnd)} ${context.tr('종일')}';
    }
    if (_sameDay(event.startAt, event.endAt)) {
      return '${timeFormatter.format(event.startAt)} - ${timeFormatter.format(event.endAt)}';
    }
    return '${dateFormatter.format(event.startAt)} ${timeFormatter.format(event.startAt)} - ${dateFormatter.format(event.endAt)} ${timeFormatter.format(event.endAt)}';
  }

  String _formatDday(CalendarEvent event) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final target = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    final diff = target.difference(base).inDays;
    if (diff == 0) {
      return 'D-day';
    }
    return diff > 0 ? 'D-$diff' : 'D+${diff.abs()}';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _EventDetailSheet extends ConsumerStatefulWidget {
  const _EventDetailSheet({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<_EventDetailSheet> {
  late bool _completed;
  var _updatingCompletion = false;

  @override
  void initState() {
    super.initState();
    _completed = widget.event.completed;
  }

  @override
  void didUpdateWidget(covariant _EventDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        (!_updatingCompletion &&
            oldWidget.event.completed != widget.event.completed)) {
      _completed = widget.event.completed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event.copyWith(completed: _completed);
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;
    final color = Color(event.colorValue);
    final canChangeCompletion =
        !event.readOnly && !event.systemEvent && !event.holiday;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.eventTitle(
                            event.title,
                            holiday: event.holiday,
                          ),
                          style: calendarEventCompletionStyle(
                            context,
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            completed: event.completed,
                            eventColor: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.categoryName(
                            id: event.category.id,
                            label: event.category.label,
                          ),
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    CheckboxListTile(
                      key: ValueKey(
                        'event-detail-todo-${event.occurrenceId ?? event.id}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.tr('완료')),
                      value: _completed,
                      onChanged: !canChangeCompletion || _updatingCompletion
                          ? null
                          : (value) {
                              if (value != null) {
                                unawaited(_setCompleted(value));
                              }
                            },
                    ),
                    const Divider(height: 8),
                    _DetailRow(
                      icon: Icons.schedule_outlined,
                      label: context.tr('시간'),
                      value: _formatTimeLabel(context, event),
                    ),
                    if (event.alarmEnabled)
                      _DetailRow(
                        icon: Icons.alarm_outlined,
                        label: context.tr('일정 알람'),
                        value: _formatAlarmLabel(context, event),
                      ),
                    if (event.location != null && event.location!.isNotEmpty)
                      _DetailActionRow(
                        icon: Icons.location_on_outlined,
                        label: context.tr('장소'),
                        value: event.location!,
                        actionIcon: Icons.map_outlined,
                        actionLabel: context.tr('지도 바로가기'),
                        onPressed: () =>
                            MapLauncher().openLocation(event.location!),
                      ),
                    if (event.weather != null && event.weather!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.cloud_outlined,
                        label: context.tr('날씨'),
                        value: event.weather!,
                      ),
                    if (event.url != null && event.url!.isNotEmpty)
                      _DetailActionRow(
                        icon: Icons.link,
                        label: 'URI',
                        value: event.url!,
                        actionIcon: Icons.open_in_new,
                        actionLabel: context.tr('열기'),
                        onPressed: () => _openUrl(event.url!),
                      ),
                    if (event.memo != null && event.memo!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: context.tr('메모'),
                        value: event.memo!,
                      ),
                    if (event.showDday)
                      _DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'D-day',
                        value: _formatDday(event),
                      ),
                    if (event.location == null &&
                        event.weather == null &&
                        event.url == null &&
                        event.memo == null &&
                        !event.alarmEnabled &&
                        !event.showDday)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          context.tr('추가 상세정보가 없습니다.'),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.tr('삭제')),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.tr('수정')),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setCompleted(bool completed) async {
    if (_updatingCompletion || completed == _completed) {
      return;
    }
    final previous = _completed;
    setState(() {
      _completed = completed;
      _updatingCompletion = true;
    });
    try {
      await ref
          .read(eventCommandServiceProvider)
          .setCompleted(widget.event, completed);
    } on Object {
      if (mounted) {
        setState(() => _completed = previous);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.tr('요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingCompletion = false);
      }
    }
  }

  String _formatTimeLabel(BuildContext context, CalendarEvent event) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormatter = DateFormat.yMMMMd(locale);
    final timeFormatter = DateFormat.Hm(locale);
    if (event.allDay) {
      final inclusiveEnd = event.endAt.subtract(const Duration(days: 1));
      if (_sameDay(event.startAt, inclusiveEnd)) {
        return '${dateFormatter.format(event.startAt)} ${context.tr('종일')}';
      }
      return '${dateFormatter.format(event.startAt)} - '
          '${dateFormatter.format(inclusiveEnd)} ${context.tr('종일')}';
    }
    return '${dateFormatter.format(event.startAt)} ${timeFormatter.format(event.startAt)} - '
        '${dateFormatter.format(event.endAt)} ${timeFormatter.format(event.endAt)}';
  }

  String _formatDday(CalendarEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    final difference = target.difference(today).inDays;
    if (difference == 0) {
      return 'D-day';
    }
    return difference > 0 ? 'D-$difference' : 'D+${difference.abs()}';
  }

  String _formatAlarmLabel(BuildContext context, CalendarEvent event) {
    if (!event.allDay) {
      return context.tr('시작 시각 · 중지 또는 10분 후 다시 알림');
    }
    final minutes = event.allDayAlarmMinutes;
    final time = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    return context.tr(
      '{time} · 중지 또는 10분 후 다시 알림',
      args: {
        'time': DateFormat.jm(context.l10n.locale.toLanguageTag()).format(time),
      },
    );
  }

  Future<void> _openUrl(String value) async {
    final raw = value.trim();
    final uri = Uri.tryParse(
      raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://$raw',
    );
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                SelectableText(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionIcon,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                SelectableText(value),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onPressed,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

CalendarRange _dayRange(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  return CalendarRange(start, start.add(const Duration(days: 1)));
}

List<CalendarEvent> _eventsForDay(
  List<CalendarEvent> events,
  DateTime date,
  AppSettings settings,
) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return sortedCalendarEvents(
    events.where(
      (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
    ),
    priority: settings.calendarEventSortPriority,
    categoryOrder: settings.categories.map((category) => category.id).toList(),
    manualOrder:
        settings.calendarManualEventOrders[calendarDateKey(date)]?.eventKeys ??
        const <String>[],
  );
}
