import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/calendar/calendar_event_ordering.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/theme/calendar_date_color.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../../core/widgets/smooth_mouse_wheel_scroll_controller.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/presentation/event_completion_action.dart';
import 'calendar_event_drag_layer.dart';

class ScheduleTimelineView extends StatefulWidget {
  const ScheduleTimelineView({
    super.key,
    required this.days,
    required this.events,
    required this.selectedDate,
    required this.use24HourTime,
    required this.showAllDayEvents,
    required this.holidayBackgroundEnabled,
    required this.holidayColorValue,
    this.showDateHeader = true,
    this.holidayDates,
    this.centerEventTitles = false,
    this.eventSortPriority = CalendarEventSortPriority.time,
    this.categoryOrder = const <String>[],
    this.weekStartsOnMonday = false,
    this.onEventDropped,
    this.onEventTimeDropped,
    this.onEventDragStateChanged,
    this.onEventDragInteractionStateChanged,
    this.externalEventDragActive = false,
    this.externalEventDragInteractionActive = false,
    required this.onShowAllDayEventsChanged,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime selectedDate;
  final bool use24HourTime;
  final bool showAllDayEvents;
  final bool holidayBackgroundEnabled;
  final int holidayColorValue;
  final bool showDateHeader;
  final Set<DateTime>? holidayDates;
  final bool centerEventTitles;
  final CalendarEventSortPriority eventSortPriority;
  final List<String> categoryOrder;
  final bool weekStartsOnMonday;
  final CalendarEventDropCallback? onEventDropped;
  final CalendarEventTimeDropCallback? onEventTimeDropped;
  final ValueChanged<bool>? onEventDragStateChanged;
  final ValueChanged<bool>? onEventDragInteractionStateChanged;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;
  final ValueChanged<bool> onShowAllDayEventsChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<ScheduleTimelineView> createState() => _ScheduleTimelineViewState();
}

class _ScheduleTimelineViewState extends State<ScheduleTimelineView> {
  static const _hourHeight = 64.0;
  static const _initialHour = 7;

  ScrollController? _scrollController;
  CalendarEvent? _draggingEvent;
  DateTime? _dragPreviewStart;
  DateTime? _acceptedDropDate;
  var _dragInteractionActive = false;
  var _eventDropAccepted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollController ??= Theme.of(context).platform == TargetPlatform.windows
        ? SmoothMouseWheelScrollController(
            initialScrollOffset: _initialHour * _hourHeight,
          )
        : ScrollController(initialScrollOffset: _initialHour * _hourHeight);
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScheduleTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalEventDragActive &&
        !widget.externalEventDragActive &&
        _draggingEvent == null) {
      _dragPreviewStart = null;
      _acceptedDropDate = null;
      _eventDropAccepted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final draggingEvent = _effectiveDraggingEvent;
    final dragInteractionActive =
        _dragInteractionActive || widget.externalEventDragInteractionActive;
    final allDayEvents = widget.events.where((event) => event.allDay).toList();
    final showAllDayArea = widget.showAllDayEvents && allDayEvents.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final scrollController = _scrollController!;
    final holidayEvents = widget.events
        .where((event) => event.holiday)
        .toList();
    final holidayDates =
        widget.holidayDates ??
        {
          for (final day in widget.days)
            if (holidayEvents.any((event) => _eventOccursOnDate(event, day)))
              DateTime(day.year, day.month, day.day),
        };

    final timeline = Column(
      key: const ValueKey('schedule-timeline'),
      children: [
        if (widget.showDateHeader)
          _ScheduleDayHeader(
            days: widget.days,
            selectedDate: widget.selectedDate,
            holidayDates: holidayDates,
            holidayColorValue: widget.holidayColorValue,
            onEventDropped: widget.onEventDropped,
            onEventDropAccepted: _setEventDateDropAccepted,
            onDateSelected: widget.onDateSelected,
          ),
        if (showAllDayArea)
          _AllDayEventStrip(
            days: widget.days,
            events: allDayEvents,
            centerEventTitles: widget.centerEventTitles,
            eventSortPriority: widget.eventSortPriority,
            categoryOrder: widget.categoryOrder,
            draggingEvent: draggingEvent,
            eventDropAccepted: _eventDropAccepted,
            acceptedDropDate: _acceptedDropDate,
            onEventDropped: widget.onEventDropped,
            onEventDropAccepted: _setEventDateDropAccepted,
            onEventDragStateChanged: _setDraggingEvent,
            onEventDragInteractionStateChanged: _setDragInteraction,
            onDateSelected: widget.onDateSelected,
          ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: Stack(
            children: [
              Scrollbar(
                controller: scrollController,
                child: SingleChildScrollView(
                  key: const ValueKey('schedule-time-scroll'),
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: _ScheduleTimeGrid(
                    days: widget.days,
                    events: widget.events
                        .where((event) => !event.allDay)
                        .toList(),
                    use24HourTime: widget.use24HourTime,
                    centerEventTitles: widget.centerEventTitles,
                    eventSortPriority: widget.eventSortPriority,
                    categoryOrder: widget.categoryOrder,
                    draggingEvent: draggingEvent,
                    dragPreviewStart: _dragPreviewStart,
                    eventDropAccepted: _eventDropAccepted,
                    onEventDropped: widget.onEventDropped,
                    onEventTimeDropped: widget.onEventTimeDropped,
                    onDragPreviewStartChanged: _setDragPreviewStart,
                    onEventDropAccepted: _setEventTimeDropAccepted,
                    onEventDragStateChanged: _setDraggingEvent,
                    onEventDragInteractionStateChanged: _setDragInteraction,
                    dragInteractionActive: dragInteractionActive,
                    onDateSelected: widget.onDateSelected,
                  ),
                ),
              ),
              PositionedDirectional(
                end: 12,
                bottom: 12,
                child: DailyIconAction(
                  key: const ValueKey('schedule-all-day-toggle'),
                  tooltip: context.tr(
                    widget.showAllDayEvents ? '종일 일정 숨기기' : '종일 일정 표시',
                  ),
                  selected: widget.showAllDayEvents,
                  icon: widget.showAllDayEvents
                      ? Icons.view_agenda_rounded
                      : Icons.horizontal_rule_rounded,
                  borderless: true,
                  onPressed: () => widget.onShowAllDayEventsChanged(
                    !widget.showAllDayEvents,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return timeline;
  }

  CalendarEvent? get _effectiveDraggingEvent {
    if (_draggingEvent != null) {
      return _draggingEvent;
    }
    if (!widget.externalEventDragActive) {
      return null;
    }
    return activeCalendarEventDrag.value?.event;
  }

  void _setDraggingEvent(CalendarEvent? event) {
    if (!mounted || _draggingEvent == event) return;
    final wasDragging = _draggingEvent != null;
    final isDragging = event != null;
    setState(() {
      _draggingEvent = event;
      _dragPreviewStart = event?.allDay == false ? event?.startAt : null;
      _acceptedDropDate = null;
      _eventDropAccepted = false;
    });
    if (wasDragging != isDragging) {
      widget.onEventDragStateChanged?.call(isDragging);
    }
  }

  void _setDragInteraction(bool active) {
    if (!mounted || _dragInteractionActive == active) return;
    setState(() => _dragInteractionActive = active);
    widget.onEventDragInteractionStateChanged?.call(active);
  }

  void _setDragPreviewStart(DateTime? value) {
    if (!mounted || _dragPreviewStart == value) return;
    setState(() => _dragPreviewStart = value);
  }

  void _setEventDateDropAccepted(CalendarEvent event, DateTime target) {
    _setEventDropAccepted(
      event,
      shiftCalendarEventToDate(event, target).startAt,
    );
  }

  void _setEventTimeDropAccepted(CalendarEvent event, DateTime target) {
    _setEventDropAccepted(event, target);
  }

  void _setEventDropAccepted(CalendarEvent event, DateTime targetStart) {
    final draggingEvent = _effectiveDraggingEvent;
    if (!mounted ||
        draggingEvent == null ||
        !_sameDraggedEvent(draggingEvent, event) ||
        _eventDropAccepted) {
      return;
    }
    setState(() {
      _eventDropAccepted = true;
      _acceptedDropDate = targetStart;
      if (!event.allDay) {
        _dragPreviewStart = targetStart;
      }
    });
  }
}

class _ScheduleDayHeader extends StatelessWidget {
  const _ScheduleDayHeader({
    required this.days,
    required this.selectedDate,
    required this.holidayDates,
    required this.holidayColorValue,
    required this.onEventDropped,
    required this.onEventDropAccepted,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final Set<DateTime> holidayDates;
  final int holidayColorValue;
  final CalendarEventDropCallback? onEventDropped;
  final void Function(CalendarEvent event, DateTime target) onEventDropAccepted;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final compact = days.length > 1;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(width: compact ? 42 : 54),
          for (final day in days)
            Expanded(
              child: CalendarEventDateDropTarget(
                date: day,
                onEventDropped: onEventDropped,
                onDropAccepted: (event) => onEventDropAccepted(event, day),
                child: InkWell(
                  onTap: () => onDateSelected(day),
                  child: Center(
                    child: Container(
                      key: ValueKey(
                        'schedule-day-background-${day.year}-${day.month}-${day.day}',
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 3 : 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _isSameDay(day, selectedDate)
                            ? scheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        key: ValueKey(
                          'schedule-day-header-${day.year}-${day.month}-${day.day}',
                        ),
                        compact
                            ? '${DateFormat.E(locale).format(day)}\n${day.day}'
                            : DateFormat.MMMEd(locale).format(day),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: _dayColor(day, scheme),
                              fontWeight: _isSameDay(day, DateTime.now())
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _dayColor(DateTime day, ColorScheme scheme) {
    final accent = calendarDateAccent(
      day,
      isHoliday: _isHoliday(day),
      holidayColorValue: holidayColorValue,
    );
    if (accent != null) return accent;
    if (_isSameDay(day, selectedDate)) {
      return scheme.onPrimaryContainer;
    }
    return scheme.onSurface;
  }

  bool _isHoliday(DateTime day) {
    return holidayDates.contains(DateTime(day.year, day.month, day.day));
  }
}

class _AllDayEventStrip extends StatelessWidget {
  const _AllDayEventStrip({
    required this.days,
    required this.events,
    required this.centerEventTitles,
    required this.eventSortPriority,
    required this.categoryOrder,
    required this.draggingEvent,
    required this.eventDropAccepted,
    required this.acceptedDropDate,
    required this.onEventDropped,
    required this.onEventDropAccepted,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final bool centerEventTitles;
  final CalendarEventSortPriority eventSortPriority;
  final List<String> categoryOrder;
  final CalendarEvent? draggingEvent;
  final bool eventDropAccepted;
  final DateTime? acceptedDropDate;
  final CalendarEventDropCallback? onEventDropped;
  final void Function(CalendarEvent event, DateTime target) onEventDropAccepted;
  final ValueChanged<CalendarEvent?> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final compact = days.length > 1;
    final eventComparator = calendarEventComparator(
      priority: eventSortPriority,
      categoryOrder: categoryOrder,
    );
    final displayedEvents =
        eventDropAccepted &&
            draggingEvent?.allDay == true &&
            acceptedDropDate != null
        ? <CalendarEvent>[
            ...events.where(
              (event) => !_sameDraggedEvent(event, draggingEvent),
            ),
            shiftCalendarEventToDate(draggingEvent!, acceptedDropDate!),
          ]
        : events;
    final eventsByDay = <DateTime, List<CalendarEvent>>{
      for (final day in days)
        DateTime(day.year, day.month, day.day): _eventsForDate(
          displayedEvents,
          day,
          eventComparator,
        ),
    };
    final rowCount = eventsByDay.values.fold<int>(
      0,
      (current, events) => math.max(current, events.length),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final chipHeight = 24.0 * textScale;
    const rowGap = 2.0;
    const verticalPadding = 7.0;
    const maximumVisibleRows = 4;
    final visibleRows = math.min(rowCount, maximumVisibleRows);
    final stripHeight = math.max(
      34.0,
      verticalPadding + visibleRows * chipHeight + (visibleRows - 1) * rowGap,
    );

    return SizedBox(
      key: const ValueKey('schedule-all-day-area'),
      height: stripHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 42 : 54,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 7, end: 5),
              child: Text(
                context.tr('종일'),
                textAlign: TextAlign.end,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('schedule-all-day-scroll'),
              primary: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in days)
                    Expanded(
                      child: CalendarEventDateDropTarget(
                        date: day,
                        onEventDropped: onEventDropped,
                        onDropAccepted: (event) =>
                            onEventDropAccepted(event, day),
                        child: InkWell(
                          onTap: () => onDateSelected(day),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 3, 2, 4),
                            child: Column(
                              children: [
                                for (final event
                                    in eventsByDay[DateTime(
                                      day.year,
                                      day.month,
                                      day.day,
                                    )]!)
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(
                                      'schedule-all-day-entry-${calendarEventOrderKey(event)}-${day.toIso8601String()}',
                                    ),
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    tween: Tween<double>(
                                      end:
                                          !eventDropAccepted &&
                                              _sameDraggedEvent(
                                                event,
                                                draggingEvent,
                                              )
                                          ? 0
                                          : 1,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: rowGap,
                                      ),
                                      child: CalendarEventDraggable(
                                        event: event,
                                        enabled: onEventDropped != null,
                                        onDragStateChanged: (dragging) =>
                                            onEventDragStateChanged(
                                              dragging ? event : null,
                                            ),
                                        onDragInteractionStateChanged:
                                            onEventDragInteractionStateChanged,
                                        child: EventCompletionAction(
                                          event: event,
                                          builder: (onDoubleTap) =>
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () =>
                                                    onDateSelected(day),
                                                onDoubleTap: onDoubleTap,
                                                child: _AllDayEventChip(
                                                  event: event,
                                                  centerTitle:
                                                      centerEventTitles,
                                                  height: chipHeight,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                    builder: (context, factor, child) =>
                                        ClipRect(
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            heightFactor: factor,
                                            child: child,
                                          ),
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDayEventChip extends StatelessWidget {
  const _AllDayEventChip({
    required this.event,
    required this.centerTitle,
    required this.height,
  });

  final CalendarEvent event;
  final bool centerTitle;
  final double height;

  @override
  Widget build(BuildContext context) {
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
      categoryAlpha: 0.17,
    );
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        context.l10n.eventTitle(event.title, holiday: event.holiday),
        textAlign: centerTitle ? TextAlign.center : TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: calendarEventCompletionStyle(
          context,
          Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          completed: event.completed,
          eventColor: categoryColor,
        ),
      ),
    );
  }
}

class _ScheduleTimeGrid extends StatelessWidget {
  const _ScheduleTimeGrid({
    required this.days,
    required this.events,
    required this.use24HourTime,
    required this.centerEventTitles,
    required this.eventSortPriority,
    required this.categoryOrder,
    required this.draggingEvent,
    required this.dragPreviewStart,
    required this.eventDropAccepted,
    required this.onEventDropped,
    required this.onEventTimeDropped,
    required this.onDragPreviewStartChanged,
    required this.onEventDropAccepted,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
    required this.dragInteractionActive,
    required this.onDateSelected,
  });

  static const _hourHeight = 64.0;

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final bool use24HourTime;
  final bool centerEventTitles;
  final CalendarEventSortPriority eventSortPriority;
  final List<String> categoryOrder;
  final CalendarEvent? draggingEvent;
  final DateTime? dragPreviewStart;
  final bool eventDropAccepted;
  final CalendarEventDropCallback? onEventDropped;
  final CalendarEventTimeDropCallback? onEventTimeDropped;
  final ValueChanged<DateTime?> onDragPreviewStartChanged;
  final void Function(CalendarEvent event, DateTime target) onEventDropAccepted;
  final ValueChanged<CalendarEvent?> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;
  final bool dragInteractionActive;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = days.length > 1;
    final gutterWidth = compact ? 42.0 : 54.0;
    final eventComparator = calendarEventComparator(
      priority: eventSortPriority,
      categoryOrder: categoryOrder,
    );
    final originalLayouts = <int, List<_TimelineSegmentLayout>>{
      for (var index = 0; index < days.length; index++)
        index: _layoutSegments(
          _segmentsForDate(events, days[index], eventComparator),
          eventComparator,
        ),
    };
    final activeEvent = draggingEvent?.allDay == false ? draggingEvent : null;
    final projectedEvents = activeEvent == null
        ? events
        : <CalendarEvent>[
            ...events.where((event) => !_sameDraggedEvent(event, activeEvent)),
            if (dragPreviewStart != null &&
                days.any((day) => _isSameDay(day, dragPreviewStart!)))
              shiftCalendarEventToStart(activeEvent, dragPreviewStart!),
          ];
    final projectedLayouts = activeEvent == null
        ? originalLayouts
        : <int, List<_TimelineSegmentLayout>>{
            for (var index = 0; index < days.length; index++)
              index: _layoutSegments(
                _segmentsForDate(projectedEvents, days[index], eventComparator),
                eventComparator,
              ),
          };

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(1.0, constraints.maxWidth - gutterWidth);
        final dayWidth = contentWidth / days.length;
        return SizedBox(
          height: 24 * _hourHeight,
          width: constraints.maxWidth,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var hour = 0; hour <= 24; hour++) ...[
                Positioned(
                  top: hour * _hourHeight,
                  left: gutterWidth,
                  right: 0,
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
                if (hour < 24)
                  Positioned(
                    top: hour * _hourHeight + 3,
                    left: 0,
                    width: gutterWidth - 5,
                    child: Text(
                      _hourLabel(context, hour),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              for (var dayIndex = 0; dayIndex <= days.length; dayIndex++)
                Positioned(
                  left: gutterWidth + dayWidth * dayIndex,
                  top: 0,
                  bottom: 0,
                  child: VerticalDivider(
                    width: 1,
                    color: scheme.outlineVariant,
                  ),
                ),
              for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                Positioned(
                  left: gutterWidth + dayWidth * dayIndex,
                  top: 0,
                  width: dayWidth,
                  height: 24 * _hourHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => onDateSelected(days[dayIndex]),
                  ),
                ),
              for (final entry in projectedLayouts.entries)
                for (final layout in entry.value)
                  _buildEventBlock(
                    context,
                    layout,
                    gutterWidth + dayWidth * entry.key,
                    dayWidth,
                    days[entry.key],
                    preview:
                        activeEvent != null &&
                        _sameDraggedEvent(layout.event, activeEvent),
                  ),
              if (activeEvent != null)
                for (final entry in originalLayouts.entries)
                  for (final layout in entry.value)
                    if (_sameDraggedEvent(layout.event, activeEvent))
                      _buildEventBlock(
                        context,
                        layout,
                        gutterWidth + dayWidth * entry.key,
                        dayWidth,
                        days[entry.key],
                        hidden: true,
                      ),
              if (days.any((day) => _isSameDay(day, DateTime.now())))
                _buildCurrentTimeIndicator(
                  context,
                  days,
                  gutterWidth,
                  dayWidth,
                ),
              if (activeEvent != null &&
                  dragInteractionActive &&
                  onEventTimeDropped != null)
                for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                  Positioned(
                    left: gutterWidth + dayWidth * dayIndex,
                    top: 0,
                    width: dayWidth,
                    height: 24 * _hourHeight,
                    child: _ScheduleTimeDropTarget(
                      day: days[dayIndex],
                      hourHeight: _hourHeight,
                      onPreviewStartChanged: onDragPreviewStartChanged,
                      onDropAccepted: onEventDropAccepted,
                      onEventTimeDropped: onEventTimeDropped!,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventBlock(
    BuildContext context,
    _TimelineSegmentLayout layout,
    double dayLeft,
    double dayWidth,
    DateTime day, {
    bool hidden = false,
    bool preview = false,
  }) {
    const gap = 2.0;
    final laneWidth = (dayWidth - gap * 2) / layout.laneCount;
    final left = dayLeft + gap + laneWidth * layout.lane;
    final top = layout.startMinute / 60 * _hourHeight + 1;
    final height = math.max(
      24.0,
      (layout.endMinute - layout.startMinute) / 60 * _hourHeight - 2,
    );
    final categoryColor = Color(layout.event.colorValue);
    final color = calendarEventAccentColor(
      context,
      categoryColor,
      completed: layout.event.completed,
    );
    final backgroundColor = calendarEventBackgroundColor(
      context,
      categoryColor,
      completed: layout.event.completed,
      categoryAlpha: 0.18,
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final start = layout.event.startAt;
    final time = use24HourTime
        ? DateFormat.Hm(locale).format(start)
        : DateFormat.jm(locale).format(start);
    final eventBlock = CalendarEventDraggable(
      event: layout.event,
      enabled:
          !preview && (onEventTimeDropped != null || onEventDropped != null),
      onDragStateChanged: (dragging) =>
          onEventDragStateChanged(dragging ? layout.event : null),
      onDragInteractionStateChanged: onEventDragInteractionStateChanged,
      child: EventCompletionAction(
        event: layout.event,
        builder: (onDoubleTap) => Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onDateSelected(day),
            onDoubleTap: onDoubleTap,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(5, 3, 3, 2),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: color, width: 3),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: context.l10n.eventTitle(
                        layout.event.title,
                        holiday: layout.event.holiday,
                      ),
                      style: calendarEventCompletionStyle(
                        context,
                        const TextStyle(fontWeight: FontWeight.w600),
                        completed: layout.event.completed,
                        eventColor: categoryColor,
                      ),
                    ),
                    TextSpan(text: '\n$time'),
                  ],
                ),
                maxLines: height >= 42 ? 3 : 1,
                textAlign: centerEventTitles
                    ? TextAlign.center
                    : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color, height: 1.15),
              ),
            ),
          ),
        ),
      ),
    );
    return AnimatedPositioned(
      key: ValueKey(
        'schedule-event-${layout.event.id}-${day.toIso8601String()}${preview ? '-preview' : ''}',
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: math.max(1, laneWidth - gap),
      height: height,
      child: IgnorePointer(
        ignoring: preview || hidden,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: hidden
              ? 0
              : preview && !eventDropAccepted
              ? 0.48
              : 1,
          child: eventBlock,
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(
    BuildContext context,
    List<DateTime> days,
    double gutterWidth,
    double dayWidth,
  ) {
    final now = DateTime.now();
    final dayIndex = days.indexWhere((day) => _isSameDay(day, now));
    final top = (now.hour * 60 + now.minute) / 60 * _hourHeight;
    return Positioned(
      left: gutterWidth + dayWidth * dayIndex,
      top: top,
      width: dayWidth,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1.5,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _hourLabel(BuildContext context, int hour) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final value = DateTime(2020, 1, 1, hour);
    return use24HourTime
        ? DateFormat.Hm(locale).format(value)
        : DateFormat.jm(locale).format(value);
  }
}

class _ScheduleTimeDropTarget extends StatelessWidget {
  const _ScheduleTimeDropTarget({
    required this.day,
    required this.hourHeight,
    required this.onPreviewStartChanged,
    required this.onDropAccepted,
    required this.onEventTimeDropped,
  });

  static const _snapMinutes = 30;

  final DateTime day;
  final double hourHeight;
  final ValueChanged<DateTime?> onPreviewStartChanged;
  final void Function(CalendarEvent event, DateTime target) onDropAccepted;
  final CalendarEventTimeDropCallback onEventTimeDropped;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CalendarEventDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (details.data.event.allDay ||
            !calendarEventCanMove(details.data.event)) {
          return false;
        }
        onPreviewStartChanged(_targetStart(context, details));
        return true;
      },
      onMove: (details) {
        onPreviewStartChanged(_targetStart(context, details));
      },
      onLeave: (_) => onPreviewStartChanged(null),
      onAcceptWithDetails: (details) {
        final targetStart = _targetStart(context, details);
        onPreviewStartChanged(targetStart);
        onDropAccepted(details.data.event, targetStart);
        unawaited(
          performCalendarEventDrop(
            details.data.event,
            () => onEventTimeDropped(details.data.event, targetStart),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) =>
          const SizedBox.expand(key: ValueKey('schedule-time-drop-target')),
    );
  }

  DateTime _targetStart(
    BuildContext context,
    DragTargetDetails<CalendarEventDragPayload> details,
  ) {
    if (details.data.origin == CalendarEventDragOrigin.sidebar) {
      final start = details.data.event.startAt;
      return DateTime(
        day.year,
        day.month,
        day.day,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
        start.microsecond,
      );
    }
    final renderObject = context.findRenderObject();
    final localOffset = renderObject is RenderBox
        ? renderObject.globalToLocal(details.offset)
        : Offset.zero;
    final feedbackHeight = math.max(
      24.0,
      details.data.event.duration.inMinutes / 60 * hourHeight - 2,
    );
    final feedbackTop = localOffset.dy - feedbackHeight / 2;
    final rawMinutes = feedbackTop / hourHeight * 60;
    final snappedMinutes = (rawMinutes / _snapMinutes).round() * _snapMinutes;
    final minuteOfDay = snappedMinutes.clamp(0, 24 * 60 - _snapMinutes);
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: minuteOfDay));
  }
}

class _TimelineSegment {
  const _TimelineSegment({
    required this.event,
    required this.startMinute,
    required this.endMinute,
  });

  final CalendarEvent event;
  final int startMinute;
  final int endMinute;
}

class _TimelineSegmentLayout {
  const _TimelineSegmentLayout({
    required this.event,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
    required this.laneCount,
  });

  final CalendarEvent event;
  final int startMinute;
  final int endMinute;
  final int lane;
  final int laneCount;
}

List<_TimelineSegment> _segmentsForDate(
  List<CalendarEvent> events,
  DateTime date,
  Comparator<CalendarEvent> eventComparator,
) {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final segments = <_TimelineSegment>[];
  for (final event in events) {
    if (event.allDay ||
        !event.startAt.isBefore(dayEnd) ||
        !event.endAt.isAfter(dayStart)) {
      continue;
    }
    final start = event.startAt.isAfter(dayStart) ? event.startAt : dayStart;
    final end = event.endAt.isBefore(dayEnd) ? event.endAt : dayEnd;
    final startMinute = start.difference(dayStart).inMinutes.clamp(0, 1439);
    final endMinute = end.difference(dayStart).inMinutes.clamp(1, 1440);
    segments.add(
      _TimelineSegment(
        event: event,
        startMinute: startMinute,
        endMinute: math.max(startMinute + 1, endMinute),
      ),
    );
  }
  segments.sort((a, b) {
    final byStart = a.startMinute.compareTo(b.startMinute);
    if (byStart != 0) return byStart;
    return eventComparator(a.event, b.event);
  });
  return segments;
}

List<_TimelineSegmentLayout> _layoutSegments(
  List<_TimelineSegment> segments,
  Comparator<CalendarEvent> eventComparator,
) {
  final layouts = <_TimelineSegmentLayout>[];
  var offset = 0;
  while (offset < segments.length) {
    var groupEnd = segments[offset].endMinute;
    var end = offset + 1;
    while (end < segments.length && segments[end].startMinute < groupEnd) {
      groupEnd = math.max(groupEnd, segments[end].endMinute);
      end++;
    }
    final group = segments.sublist(offset, end)
      ..sort((a, b) => eventComparator(a.event, b.event));
    final lanes = <List<_TimelineSegment>>[];
    final assigned = <({_TimelineSegment segment, int lane})>[];
    for (final segment in group) {
      var lane = lanes.indexWhere(
        (items) => items.every((item) => !_segmentsOverlap(item, segment)),
      );
      if (lane == -1) {
        lane = lanes.length;
        lanes.add(<_TimelineSegment>[]);
      }
      lanes[lane].add(segment);
      assigned.add((segment: segment, lane: lane));
    }
    for (final item in assigned) {
      layouts.add(
        _TimelineSegmentLayout(
          event: item.segment.event,
          startMinute: item.segment.startMinute,
          endMinute: item.segment.endMinute,
          lane: item.lane,
          laneCount: lanes.length,
        ),
      );
    }
    offset = end;
  }
  return layouts;
}

bool _segmentsOverlap(_TimelineSegment first, _TimelineSegment second) {
  return first.startMinute < second.endMinute &&
      first.endMinute > second.startMinute;
}

List<CalendarEvent> _eventsForDate(
  List<CalendarEvent> events,
  DateTime date,
  Comparator<CalendarEvent> eventComparator,
) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return events
      .where(
        (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
      )
      .toList()
    ..sort(eventComparator);
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool _eventOccursOnDate(CalendarEvent event, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return event.startAt.isBefore(end) && event.endAt.isAfter(start);
}

bool _sameDraggedEvent(CalendarEvent event, CalendarEvent? draggedEvent) {
  return draggedEvent != null &&
      calendarEventOrderKey(event) == calendarEventOrderKey(draggedEvent);
}
