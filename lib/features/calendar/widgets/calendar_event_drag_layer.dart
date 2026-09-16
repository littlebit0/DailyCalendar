import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../events/domain/calendar_event.dart';

final Map<String, Future<void>> _pendingCalendarEventDrops = {};
final ValueNotifier<CalendarEventDragPayload?> activeCalendarEventDrag =
    ValueNotifier<CalendarEventDragPayload?>(null);
final ValueNotifier<CalendarEventDragFeedbackSpec>
activeCalendarEventDragFeedbackSpec = ValueNotifier(
  const CalendarEventDragFeedbackSpec.source(),
);

enum CalendarEventDragFeedbackStyle {
  source,
  month,
  week,
  day,
  schedule,
  sidebar,
}

@immutable
class CalendarEventDragFeedbackSpec {
  const CalendarEventDragFeedbackSpec.source()
    : style = CalendarEventDragFeedbackStyle.source,
      width = null,
      height = null,
      builder = null;

  const CalendarEventDragFeedbackSpec.target({
    required this.style,
    required this.width,
    required this.height,
    this.builder,
  }) : assert(style != CalendarEventDragFeedbackStyle.source);

  final CalendarEventDragFeedbackStyle style;
  final double? width;
  final double? height;
  final WidgetBuilder? builder;

  @override
  bool operator ==(Object other) {
    return other is CalendarEventDragFeedbackSpec &&
        other.style == style &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(style, width, height);
}

Future<void> performCalendarEventDrop(
  CalendarEvent event,
  Future<void> Function() action,
) {
  final eventKey = _calendarEventDragKey(event);
  final future = Future<void>.sync(action);
  _pendingCalendarEventDrops[eventKey] = future;
  void removePendingDrop() {
    if (identical(_pendingCalendarEventDrops[eventKey], future)) {
      _pendingCalendarEventDrops.remove(eventKey);
    }
  }

  unawaited(
    future.then<void>(
      (_) => removePendingDrop(),
      onError: (Object _, StackTrace _) => removePendingDrop(),
    ),
  );
  return future;
}

Future<void> waitForCalendarEventDrop(CalendarEvent event) async {
  final pending = _pendingCalendarEventDrops[_calendarEventDragKey(event)];
  if (pending == null) return;
  try {
    await pending;
  } on Object {
    // The command layer reports the failure. The drag source still needs to
    // return to its original place after the failed drop completes.
  }
}

String _calendarEventDragKey(CalendarEvent event) =>
    event.occurrenceId ?? event.id;

class CalendarEventDraggable extends StatelessWidget {
  const CalendarEventDraggable({
    super.key,
    required this.event,
    required this.child,
    this.enabled = true,
    this.onDragStateChanged,
    this.onDragInteractionStateChanged,
    this.onDragGlobalPositionChanged,
    this.compactFeedbackListenable,
    this.feedbackSpecListenable,
    this.origin = CalendarEventDragOrigin.calendar,
  });

  final CalendarEvent event;
  final Widget child;
  final bool enabled;

  /// The visual lift state. It remains active until an accepted drop finishes
  /// saving so the source does not briefly jump back into place.
  final ValueChanged<bool>? onDragStateChanged;

  /// The pointer interaction state. It ends as soon as the pointer is released,
  /// independently of any asynchronous save still in progress.
  final ValueChanged<bool>? onDragInteractionStateChanged;
  final ValueChanged<Offset>? onDragGlobalPositionChanged;
  final ValueListenable<bool>? compactFeedbackListenable;
  final ValueListenable<CalendarEventDragFeedbackSpec>? feedbackSpecListenable;
  final CalendarEventDragOrigin origin;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !calendarEventCanMove(event)) {
      return child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Within the source surface preserve the exact card. Only desktop
          // calendar/sidebar crossings use the destination's real renderer.
          Size? sourceSize;
          var grabOffset = Offset.zero;
          final feedback = InheritedTheme.captureAll(
            context,
            CalendarEventSurface(
              color: CalendarEventSurface.of(context),
              child: MediaQuery(
                data: MediaQuery.of(context),
                child: IgnorePointer(
                  child: Builder(
                    builder: (_) =>
                        ValueListenableBuilder<CalendarEventDragFeedbackSpec>(
                          valueListenable:
                              feedbackSpecListenable ??
                              activeCalendarEventDragFeedbackSpec,
                          builder: (context, spec, _) => _SurfaceDragFeedback(
                            feedbackKey: ValueKey(
                              'calendar-event-drag-feedback-${event.occurrenceId ?? event.id}',
                            ),
                            sourceSize: sourceSize!,
                            grabOffset: grabOffset,
                            spec: spec,
                            origin: origin,
                            source: Material(
                              type: MaterialType.transparency,
                              child: DefaultTextStyle.of(context).wrap(
                                context,
                                KeyedSubtree(
                                  key: const ValueKey(
                                    'calendar-event-source-feedback',
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
          );
          var visualEndReported = false;
          var interactionEndReported = false;
          void reportVisualEnd() {
            if (visualEndReported) return;
            visualEndReported = true;
            final activeDrag = activeCalendarEventDrag.value;
            if (activeDrag != null &&
                _calendarEventDragKey(activeDrag.event) ==
                    _calendarEventDragKey(event)) {
              activeCalendarEventDrag.value = null;
            }
            activeCalendarEventDragFeedbackSpec.value =
                const CalendarEventDragFeedbackSpec.source();
            onDragStateChanged?.call(false);
          }

          void reportInteractionEnd() {
            if (interactionEndReported) return;
            interactionEndReported = true;
            onDragInteractionStateChanged?.call(false);
          }

          void reportCanceledDrag() {
            reportInteractionEnd();
            reportVisualEnd();
          }

          return LongPressDraggable<CalendarEventDragPayload>(
            data: CalendarEventDragPayload(event, origin: origin),
            delay: const Duration(milliseconds: 320),
            allowedButtonsFilter: (buttons) =>
                (buttons & kPrimaryMouseButton) != 0,
            dragAnchorStrategy: (_, sourceContext, position) {
              final box = sourceContext.findRenderObject()! as RenderBox;
              sourceSize = box.size;
              grabOffset = box.globalToLocal(position);
              // Drop handlers receive pointer coordinates, not card coordinates.
              return Offset.zero;
            },
            rootOverlay: true,
            onDragStarted: () {
              activeCalendarEventDragFeedbackSpec.value =
                  const CalendarEventDragFeedbackSpec.source();
              activeCalendarEventDrag.value = CalendarEventDragPayload(
                event,
                origin: origin,
              );
              onDragStateChanged?.call(true);
              onDragInteractionStateChanged?.call(true);
            },
            onDragUpdate: (details) =>
                onDragGlobalPositionChanged?.call(details.globalPosition),
            onDragCompleted: () async {
              reportInteractionEnd();
              await waitForCalendarEventDrop(event);
              reportVisualEnd();
            },
            onDraggableCanceled: (_, _) => reportCanceledDrag(),
            onDragEnd: (details) {
              if (details.wasAccepted) {
                reportInteractionEnd();
              } else {
                reportCanceledDrag();
              }
            },
            feedback: feedback,
            childWhenDragging: IgnorePointer(
              child: Opacity(opacity: 0, child: child),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _SurfaceDragFeedback extends StatelessWidget {
  const _SurfaceDragFeedback({
    required this.feedbackKey,
    required this.sourceSize,
    required this.grabOffset,
    required this.spec,
    required this.origin,
    required this.source,
  });
  final Size sourceSize;
  final Key feedbackKey;
  final Offset grabOffset;
  final CalendarEventDragFeedbackSpec spec;
  final CalendarEventDragOrigin origin;
  final Widget source;

  @override
  Widget build(BuildContext context) {
    final crossing =
        Theme.of(context).platform == TargetPlatform.macOS &&
        spec.builder != null &&
        (origin == CalendarEventDragOrigin.calendar
            ? spec.style == CalendarEventDragFeedbackStyle.sidebar
            : spec.style != CalendarEventDragFeedbackStyle.sidebar &&
                  spec.style != CalendarEventDragFeedbackStyle.source);
    final target = crossing ? Size(spec.width!, spec.height!) : sourceSize;
    final content = crossing ? spec.builder!(context) : source;
    return TweenAnimationBuilder<Size?>(
      tween: SizeTween(begin: sourceSize, end: target),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final size = value!;
        return Transform.translate(
          offset: Offset(
            -grabOffset.dx / sourceSize.width * size.width,
            -grabOffset.dy / sourceSize.height * size.height,
          ),
          child: SizedBox.fromSize(
            size: size,
            child: Material(
              key: feedbackKey,
              type: MaterialType.transparency,
              child: ClipRect(child: child),
            ),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 170),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: OverflowBox(
          key: ValueKey(
            crossing ? spec.style : CalendarEventDragFeedbackStyle.source,
          ),
          alignment: Alignment.topLeft,
          minWidth: target.width,
          maxWidth: target.width,
          minHeight: target.height,
          maxHeight: target.height,
          child: content,
        ),
      ),
    );
  }
}

class CalendarEventDateDropTarget extends StatefulWidget {
  const CalendarEventDateDropTarget({
    super.key,
    required this.date,
    required this.child,
    required this.onEventDropped,
    this.targetIndex = calendarEventAppendIndex,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.onDropAccepted,
  });

  final DateTime date;
  final Widget child;
  final CalendarEventDropCallback? onEventDropped;
  final int targetIndex;
  final bool enabled;
  final BorderRadius borderRadius;
  final ValueChanged<CalendarEvent>? onDropAccepted;

  @override
  State<CalendarEventDateDropTarget> createState() =>
      _CalendarEventDateDropTargetState();
}

class _CalendarEventDateDropTargetState
    extends State<CalendarEventDateDropTarget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.onEventDropped == null) {
      return widget.child;
    }
    return DragTarget<CalendarEventDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (!calendarEventCanMove(details.data.event)) {
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        widget.onDropAccepted?.call(details.data.event);
        unawaited(
          performCalendarEventDrop(
            details.data.event,
            () => widget.onEventDropped!(
              details.data.event,
              widget.date,
              widget.targetIndex,
            ),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) => widget.child,
    );
  }
}

class CalendarEventMonthDropOverlay extends StatelessWidget {
  const CalendarEventMonthDropOverlay({
    super.key,
    required this.focusDate,
    required this.weekStartsOnMonday,
    required this.onEventDropped,
  });

  final DateTime focusDate;
  final bool weekStartsOnMonday;
  final CalendarEventDropCallback onEventDropped;

  @override
  Widget build(BuildContext context) {
    final month = DateTime(focusDate.year, focusDate.month);
    final firstWeekdayOffset = weekStartsOnMonday
        ? month.weekday - DateTime.monday
        : month.weekday % DateTime.daysPerWeek;
    final firstDate = month.subtract(Duration(days: firstWeekdayOffset));
    final days = List.generate(
      42,
      (index) => firstDate.add(Duration(days: index)),
    );
    final firstWeekday = weekStartsOnMonday ? DateTime.monday : DateTime.sunday;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      key: const ValueKey('event-date-drop-overlay'),
      color: scheme.surface.withValues(alpha: 0.98),
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.drag_indicator, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('일정을 놓을 날짜'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  DateFormat.yMMMM(locale).format(month),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(
                    child: Text(
                      DateFormat.E(
                        locale,
                      ).format(DateTime(2024, 1, firstWeekday + index)),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Column(
                children: [
                  for (var week = 0; week < 6; week++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var weekday = 0; weekday < 7; weekday++)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final day = days[week * 7 + weekday];
                                  final inMonth = day.month == month.month;
                                  final isSourceDay = _sameDate(day, focusDate);
                                  return Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: CalendarEventDateDropTarget(
                                      key: ValueKey(
                                        'event-date-drop-${day.year}-${day.month}-${day.day}',
                                      ),
                                      date: day,
                                      onEventDropped: onEventDropped,
                                      borderRadius: BorderRadius.circular(7),
                                      child: Center(
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSourceDay
                                                ? scheme.secondaryContainer
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${day.day}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: inMonth
                                                      ? scheme.onSurface
                                                      : scheme.outline,
                                                  fontWeight: isSourceDay
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
