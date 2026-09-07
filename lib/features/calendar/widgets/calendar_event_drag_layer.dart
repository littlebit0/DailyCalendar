import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      height = null;

  const CalendarEventDragFeedbackSpec.target({
    required this.style,
    required this.width,
    required this.height,
  }) : assert(style != CalendarEventDragFeedbackStyle.source);

  final CalendarEventDragFeedbackStyle style;
  final double? width;
  final double? height;

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
          final feedbackWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : null;
          final sourceFeedback = feedbackWidth == null
              ? child
              : SizedBox(width: feedbackWidth, child: child);
          Widget feedbackForSpec(CalendarEventDragFeedbackSpec spec) {
            return _AnimatedCalendarEventDragFeedback(
              key: const ValueKey(
                'calendar-event-drag-feedback-size-animation',
              ),
              event: event,
              spec: spec,
              sourceFeedback: sourceFeedback,
              fallbackWidth: feedbackWidth,
            );
          }

          final feedbackContent = feedbackSpecListenable != null
              ? ValueListenableBuilder<CalendarEventDragFeedbackSpec>(
                  valueListenable: feedbackSpecListenable!,
                  builder: (context, spec, _) => feedbackForSpec(spec),
                )
              : compactFeedbackListenable != null
              ? ValueListenableBuilder<bool>(
                  valueListenable: compactFeedbackListenable!,
                  builder: (context, compact, _) => feedbackForSpec(
                    compact
                        ? CalendarEventDragFeedbackSpec.target(
                            style: CalendarEventDragFeedbackStyle.month,
                            width: math.min(feedbackWidth ?? 220, 220),
                            height: 26,
                          )
                        : const CalendarEventDragFeedbackSpec.source(),
                  ),
                )
              : ValueListenableBuilder<CalendarEventDragFeedbackSpec>(
                  valueListenable: activeCalendarEventDragFeedbackSpec,
                  builder: (context, spec, _) => feedbackForSpec(spec),
                );
          final feedback = InheritedTheme.captureAll(
            context,
            MediaQuery(
              data: MediaQuery.of(context),
              child: IgnorePointer(
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Material(
                    key: ValueKey(
                      'calendar-event-drag-feedback-${event.occurrenceId ?? event.id}',
                    ),
                    type: MaterialType.transparency,
                    child: feedbackContent,
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
            dragAnchorStrategy: pointerDragAnchorStrategy,
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

class _AnimatedCalendarEventDragFeedback extends StatefulWidget {
  const _AnimatedCalendarEventDragFeedback({
    super.key,
    required this.event,
    required this.spec,
    required this.sourceFeedback,
    required this.fallbackWidth,
  });

  final CalendarEvent event;
  final CalendarEventDragFeedbackSpec spec;
  final Widget sourceFeedback;
  final double? fallbackWidth;

  @override
  State<_AnimatedCalendarEventDragFeedback> createState() =>
      _AnimatedCalendarEventDragFeedbackState();
}

class _AnimatedCalendarEventDragFeedbackState
    extends State<_AnimatedCalendarEventDragFeedback>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 170);

  late final AnimationController _controller;
  Size? _sourceSize;
  Size? _fromSize;
  Size? _toSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didUpdateWidget(covariant _AnimatedCalendarEventDragFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec == widget.spec) return;

    final targetSize = _targetSize(widget.spec);
    if (targetSize == null) {
      _controller.stop();
      _fromSize = null;
      _toSize = null;
      return;
    }

    final currentSize =
        _animatedSize() ??
        _targetSize(oldWidget.spec) ??
        _sourceSize ??
        targetSize;
    if (currentSize == targetSize) {
      _controller.stop();
      _fromSize = targetSize;
      _toSize = targetSize;
      return;
    }

    _fromSize = currentSize;
    _toSize = targetSize;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Size? _targetSize(CalendarEventDragFeedbackSpec spec) {
    if (spec.style == CalendarEventDragFeedbackStyle.source) {
      return _sourceSize;
    }
    final minimumHeight = spec.style == CalendarEventDragFeedbackStyle.month
        ? 1.0
        : 24.0;
    return Size(
      math.max(1, spec.width ?? widget.fallbackWidth ?? 220),
      math.max(minimumHeight, spec.height ?? 26),
    );
  }

  Size? _animatedSize() {
    final fromSize = _fromSize;
    final toSize = _toSize;
    if (fromSize == null || toSize == null) return null;
    final progress = Curves.easeOutCubic.transform(_controller.value);
    return Size.lerp(fromSize, toSize, progress);
  }

  void _recordSourceSize(Size size) {
    _sourceSize = size;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.style == CalendarEventDragFeedbackStyle.source) {
      final sourceFeedback = _DragFeedbackSizeReporter(
        onSizeChanged: _recordSourceSize,
        child: KeyedSubtree(
          key: const ValueKey('calendar-event-source-feedback'),
          child: widget.sourceFeedback,
        ),
      );
      final sourceSize = _sourceSize;
      if (sourceSize == null) return sourceFeedback;
      // Keep the original layout intact while the outer feedback grows back.
      return AnimatedBuilder(
        animation: _controller,
        child: SizedBox.fromSize(size: sourceSize, child: sourceFeedback),
        builder: (context, child) => SizedBox.fromSize(
          size: _animatedSize() ?? sourceSize,
          child: FittedBox(fit: BoxFit.fill, child: child),
        ),
      );
    }

    final targetSize = _targetSize(spec)!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final size = _animatedSize() ?? targetSize;
        return _CalendarEventTargetDragFeedback(
          key: ValueKey(
            spec.style == CalendarEventDragFeedbackStyle.month
                ? 'calendar-event-compact-feedback'
                : 'calendar-event-target-feedback-${spec.style.name}',
          ),
          event: widget.event,
          style: spec.style,
          width: size.width,
          height: size.height,
        );
      },
    );
  }
}

class _DragFeedbackSizeReporter extends SingleChildRenderObjectWidget {
  const _DragFeedbackSizeReporter({
    required this.onSizeChanged,
    required super.child,
  });

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDragFeedbackSizeReporter(onSizeChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderDragFeedbackSizeReporter renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderDragFeedbackSizeReporter extends RenderProxyBox {
  _RenderDragFeedbackSizeReporter(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _lastReportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastReportedSize == size) return;
    _lastReportedSize = size;
    onSizeChanged(size);
  }
}

class _CalendarEventTargetDragFeedback extends StatelessWidget {
  const _CalendarEventTargetDragFeedback({
    super.key,
    required this.event,
    required this.style,
    required this.width,
    required this.height,
  });

  final CalendarEvent event;
  final CalendarEventDragFeedbackStyle style;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Color(event.colorValue);
    final title = context.l10n.eventTitle(event.title, holiday: event.holiday);
    if (style == CalendarEventDragFeedbackStyle.month) {
      return _buildMonthFeedback(context, color, title);
    }
    if (style == CalendarEventDragFeedbackStyle.sidebar) {
      return _buildSidebarFeedback(context, color, title);
    }
    final schedule = style == CalendarEventDragFeedbackStyle.schedule;
    final day = style == CalendarEventDragFeedbackStyle.day;
    final background = calendarEventBackgroundColor(
      context,
      color,
      completed: event.completed,
      categoryAlpha: schedule || day ? 0.2 : 0.18,
    );
    final accent = calendarEventAccentColor(
      context,
      color,
      completed: event.completed,
    );
    final time = DateFormat.Hm(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(event.startAt);
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        elevation: 7,
        shadowColor: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(schedule || day ? 6 : 5),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: schedule || day ? 6 : 7,
            vertical: schedule || day ? 4 : 0,
          ),
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(schedule || day ? 6 : 5),
            border: BorderDirectional(
              start: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Text(
            schedule ? '$title\n$time' : title,
            maxLines: schedule && height >= 42
                ? 3
                : day
                ? 2
                : 1,
            overflow: TextOverflow.ellipsis,
            style: calendarEventCompletionStyle(
              context,
              TextStyle(
                color: accent,
                fontSize: schedule || day ? 12 : 11,
                fontWeight: FontWeight.w700,
              ),
              completed: event.completed,
              eventColor: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthFeedback(BuildContext context, Color color, String title) {
    final textColor = calendarEventAccentColor(
      context,
      color,
      completed: event.completed,
    );
    return Container(
      width: width,
      height: height,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: event.holiday ? 0.12 : 0.15),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 9,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: calendarEventCompletionStyle(
          context,
          TextStyle(
            color: textColor,
            fontSize: height <= 13 ? 10 : 11,
            height: height <= 13 ? 1 : null,
            fontWeight: FontWeight.w700,
          ),
          completed: event.completed,
          eventColor: color,
        ),
      ),
    );
  }

  Widget _buildSidebarFeedback(
    BuildContext context,
    Color color,
    String title,
  ) {
    final expansionProgress = ((height - 24) / (76 - 24)).clamp(0.0, 1.0);
    final timeProgress = ((expansionProgress - 0.48) / 0.52).clamp(0.0, 1.0);
    final horizontalPadding = 5 + (5 * expansionProgress);
    final verticalPadding = 10 * expansionProgress;
    final indicatorWidth = 4 * expansionProgress;
    final indicatorGap = 10 * expansionProgress;
    final titleFontSize = 11 + (3 * expansionProgress);
    final accent = calendarEventAccentColor(
      context,
      color,
      completed: event.completed,
    );
    final sidebarBackground = calendarEventBackgroundColor(
      context,
      color,
      completed: event.completed,
      categoryAlpha: event.holiday ? 0.07 : 0.08,
    );
    final background = Color.lerp(
      color.withValues(alpha: event.holiday ? 0.12 : 0.15),
      sidebarBackground,
      expansionProgress,
    )!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = event.allDay
        ? context.tr('종일')
        : '${DateFormat.Hm(locale).format(event.startAt)} - '
              '${DateFormat.Hm(locale).format(event.endAt)}';
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 7,
        shadowColor: Colors.black.withValues(alpha: 0.26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: accent.withValues(alpha: 0.28 * expansionProgress),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: background,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              children: [
                if (indicatorWidth > 0)
                  Container(
                    width: indicatorWidth,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                SizedBox(width: indicatorGap),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(
                            -1,
                            -0.45 * expansionProgress,
                          ),
                          child: Text(
                            key: const ValueKey(
                              'calendar-event-sidebar-feedback-title',
                            ),
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: calendarEventCompletionStyle(
                              context,
                              TextStyle(
                                color: accent,
                                fontSize: titleFontSize,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                              completed: event.completed,
                              eventColor: color,
                            ),
                          ),
                        ),
                        if (timeProgress > 0 && constraints.maxHeight >= 28)
                          Align(
                            alignment: AlignmentDirectional.bottomStart,
                            child: Opacity(
                              opacity: timeProgress,
                              child: Text(
                                key: const ValueKey(
                                  'calendar-event-sidebar-feedback-time',
                                ),
                                time,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: accent.withValues(alpha: 0.72),
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
          ),
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
