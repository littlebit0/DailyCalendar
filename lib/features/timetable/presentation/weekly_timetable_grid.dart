import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/event_completion_palette.dart';
import '../domain/timetable.dart';

/// A semester timetable whose weekdays always fit the available width.
/// Dates and date-specific modes can also be shown for a selected week.
class WeeklyTimetableGrid extends StatelessWidget {
  const WeeklyTimetableGrid({
    super.key,
    required this.days,
    required this.occurrences,
    required this.use24HourTime,
    required this.onOccurrenceTap,
    required this.onEmptySlotTap,
    this.showDates = false,
    this.previewCourseIds = const {},
    this.compact = false,
  });

  final List<DateTime> days;
  final List<ClassOccurrence> occurrences;
  final bool use24HourTime;
  final ValueChanged<ClassOccurrence> onOccurrenceTap;
  final void Function(int weekday, int startMinute) onEmptySlotTap;
  final bool showDates;

  /// IDs of unsaved candidates displayed alongside the saved timetable.
  final Set<String> previewCourseIds;

  /// A denser overview for a timetable displayed above the course picker.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final visible = occurrences.where(
      (occurrence) =>
          days.any((day) => DateUtils.isSameDay(day, occurrence.date)),
    );
    final startMinute =
        visible.fold<int>(
          9 * 60,
          (start, occurrence) =>
              math.min(start, occurrence.meeting.startMinute),
        ) ~/
        60 *
        60;
    final endMinute =
        (visible.fold<int>(
                  18 * 60,
                  (end, occurrence) =>
                      math.max(end, occurrence.meeting.endMinute),
                ) /
                60)
            .ceil() *
        60;
    final hourCount = (endMinute - startMinute) ~/ 60;
    final scheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final railWidth = math.max(
      use24HourTime ? (compact ? 30.0 : 38.0) : (compact ? 38.0 : 46.0),
      textScaler.scale(compact ? 18 : 24) + 14,
    );
    final headerHeight = math.max(
      showDates ? (compact ? 44.0 : 52.0) : (compact ? 28.0 : 36.0),
      textScaler.scale(showDates ? 26 : (compact ? 11 : 14)) + 14,
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayLabels = [
      for (final day in days) DateFormat.E(locale).format(day),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final bodyHeight = bounded
            ? math.max(0.0, constraints.maxHeight - headerHeight - 2)
            : 9 * 60.0;
        final minimumHourHeight = compact
            ? math.max(22.0, textScaler.scale(11) * 1.25 + 8)
            : 48.0;
        final hourHeight = (bodyHeight / hourCount)
            .clamp(
              minimumHourHeight,
              compact ? math.max(36.0, minimumHourHeight) : 76.0,
            )
            .toDouble();
        final gridHeight = hourCount * hourHeight;
        final dayWidth =
            math.max(0.0, constraints.maxWidth - railWidth - 2) / days.length;
        final body = SingleChildScrollView(
          key: const ValueKey('timetable-grid-scroll'),
          child: SizedBox(
            height: gridHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TimetableLines(
                      color: scheme.outlineVariant,
                      railWidth: railWidth,
                      dayWidth: dayWidth,
                      dayCount: days.length,
                      hourHeight: hourHeight,
                      hourCount: hourCount,
                    ),
                  ),
                ),
                for (var hour = 0; hour < hourCount; hour++)
                  Positioned(
                    left: 0,
                    top: hour * hourHeight,
                    width: railWidth,
                    height: hourHeight,
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              Text(
                                DateFormat(
                                  use24HourTime ? 'HH' : 'h',
                                  locale,
                                ).format(
                                  DateTime(
                                    2000,
                                    1,
                                    1,
                                    startMinute ~/ 60 + hour,
                                  ),
                                ),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                              ),
                              if (!use24HourTime)
                                Text(
                                  DateFormat('a', locale).format(
                                    DateTime(
                                      2000,
                                      1,
                                      1,
                                      startMinute ~/ 60 + hour,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                  for (var hour = 0; hour < hourCount; hour++)
                    Positioned(
                      left: railWidth + dayIndex * dayWidth,
                      top: hour * hourHeight,
                      width: dayWidth,
                      height: hourHeight,
                      child: Semantics(
                        button: true,
                        label:
                            '${dayLabels[dayIndex]} ${_timeLabel(context, startMinute + hour * 60)} ${context.tr('수업 추가')}',
                        onTap: () => onEmptySlotTap(
                          days[dayIndex].weekday,
                          startMinute + hour * 60,
                        ),
                        child: InkWell(
                          key: ValueKey(
                            'timetable-slot-${days[dayIndex].weekday}-${startMinute + hour * 60}',
                          ),
                          onTap: () => onEmptySlotTap(
                            days[dayIndex].weekday,
                            startMinute + hour * 60,
                          ),
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                  for (final placement in _placeOccurrences(
                    visible
                        .where(
                          (item) =>
                              DateUtils.isSameDay(item.date, days[dayIndex]),
                        )
                        .toList(),
                  ))
                    Positioned(
                      left:
                          railWidth +
                          dayIndex * dayWidth +
                          placement.lane * dayWidth / placement.laneCount +
                          1.5,
                      top:
                          (placement.occurrence.meeting.startMinute -
                                  startMinute) /
                              60 *
                              hourHeight +
                          1,
                      width: math.max(0, dayWidth / placement.laneCount - 3),
                      height: math.max(
                        2,
                        (placement.occurrence.meeting.endMinute -
                                    placement.occurrence.meeting.startMinute) /
                                60 *
                                hourHeight -
                            2,
                      ),
                      child: _ClassBlock(
                        key: ValueKey(
                          'timetable-occurrence-${placement.occurrence.id}',
                        ),
                        occurrence: placement.occurrence,
                        timeLabel:
                            '${_timeLabel(context, placement.occurrence.meeting.startMinute)}–${_timeLabel(context, placement.occurrence.meeting.endMinute)}',
                        weekday: dayLabels[dayIndex],
                        isPreview: previewCourseIds.contains(
                          placement.occurrence.course.id,
                        ),
                        compact: compact,
                        onTap: () => onOccurrenceTap(placement.occurrence),
                      ),
                    ),
              ],
            ),
          ),
        );
        return Material(
          key: const ValueKey('weekly-timetable-grid'),
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  height: headerHeight,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: railWidth),
                      for (var index = 0; index < days.length; index++)
                        SizedBox(
                          width: dayWidth,
                          child: Semantics(
                            header: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dayLabels[index],
                                      key: ValueKey(
                                        'timetable-day-${days[index].weekday}',
                                      ),
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                            fontSize: compact ? 11 : null,
                                          ),
                                    ),
                                    if (showDates)
                                      Text(
                                        '${days[index].month}.${days[index].day}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: scheme.onSurfaceVariant,
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
                if (bounded)
                  Expanded(child: body)
                else
                  SizedBox(height: gridHeight, child: body),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeLabel(BuildContext context, int minute) {
    // 24:00 denotes the end of the same timetable day, not its midnight start.
    if (minute == 1440 && use24HourTime) return '24:00';
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60),
      alwaysUse24HourFormat: use24HourTime,
    );
  }
}

class _ClassBlock extends StatelessWidget {
  const _ClassBlock({
    super.key,
    required this.occurrence,
    required this.weekday,
    required this.timeLabel,
    required this.onTap,
    required this.isPreview,
    required this.compact,
  });
  final ClassOccurrence occurrence;
  final String weekday;
  final String timeLabel;
  final VoidCallback onTap;
  final bool isPreview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final course = occurrence.course;
    final room = occurrence.meeting.classroom;
    final color = Color(course.colorValue);
    final palette = calendarEventPalette(
      color,
      Color.alphaBlend(
        color.withValues(alpha: .16),
        Theme.of(context).colorScheme.surface,
      ),
    );
    final cancelled = occurrence.mode == LectureMode.cancelled;
    final label = [
      if (isPreview) context.tr('추가 미리보기'),
      course.title,
      '$weekday $timeLabel',
      if (room.isNotEmpty) room,
      context.tr(lectureModeLabel(occurrence.mode)),
      if (course.professor.isNotEmpty) course.professor,
    ].join(', ');
    return Semantics(
      button: !isPreview,
      label: label,
      onTap: isPreview ? null : onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          key: isPreview
              ? ValueKey('timetable-preview-border-${course.id}')
              : null,
          color: palette.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: isPreview
                ? BorderSide(color: palette.foreground, width: 2)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isPreview ? null : onTap,
            excludeFromSemantics: true,
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final inset = compact
                      ? 3.0
                      : constraints.maxWidth >= 50
                      ? 5.0
                      : 3.0;
                  final fontSize = compact
                      ? (constraints.maxWidth >= 50 ? 11.0 : 10.0)
                      : constraints.maxWidth >= 100
                      ? 13.0
                      : constraints.maxWidth >= 50
                      ? 12.0
                      : 11.0;
                  final lineHeight =
                      MediaQuery.textScalerOf(context).scale(fontSize) * 1.25;
                  final availableHeight = math.max(
                    0.0,
                    constraints.maxHeight - 8,
                  );
                  final lines = (availableHeight / lineHeight).floor();
                  final modeIcon = switch (occurrence.mode) {
                    LectureMode.inPerson => null,
                    LectureMode.liveOnline => Icons.videocam_outlined,
                    LectureMode.video => Icons.play_circle_outline,
                    LectureMode.cancelled => Icons.block,
                  };
                  final showRoom = room.isNotEmpty && lines >= 3;
                  final showMode =
                      modeIcon != null &&
                      constraints.maxWidth >= 32 &&
                      lines >= 2;
                  final showDetails = showRoom || showMode;
                  final titleLines = math.max(
                    1,
                    math.min(4, lines - (showDetails ? 1 : 0)),
                  );
                  final showPreviewBadge =
                      isPreview &&
                      constraints.maxWidth >= 44 &&
                      constraints.maxHeight >= 32;
                  final style = TextStyle(
                    fontSize: fontSize,
                    height: 1.25,
                    color: palette.foreground,
                    fontWeight: FontWeight.w600,
                    decoration: cancelled
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: palette.strike,
                  );
                  return ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            inset,
                            compact ? 3 : 4,
                            inset + (showPreviewBadge ? 14 : 0),
                            compact ? 3 : 4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  course.title,
                                  maxLines: titleLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                              if (showDetails)
                                Row(
                                  children: [
                                    Expanded(
                                      child: showRoom
                                          ? Text(
                                              room,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: style.copyWith(
                                                fontWeight: FontWeight.normal,
                                                decoration: TextDecoration.none,
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    if (showMode)
                                      Icon(
                                        modeIcon,
                                        size: 12,
                                        color: palette.foreground,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (showPreviewBadge)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: DecoratedBox(
                              key: ValueKey(
                                'timetable-preview-badge-${course.id}',
                              ),
                              decoration: BoxDecoration(
                                color: palette.foreground,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 12,
                                color: palette.background,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Placement {
  _Placement(this.occurrence, this.lane);
  final ClassOccurrence occurrence;
  final int lane;
  int laneCount = 1;
}

/// Allocate lanes within connected overlap groups, so adjacent classes retain
/// the full column width while every simultaneous class remains tappable.
List<_Placement> _placeOccurrences(List<ClassOccurrence> occurrences) {
  occurrences.sort((a, b) {
    final time = a.meeting.startMinute.compareTo(b.meeting.startMinute);
    if (time != 0) return time;
    final end = a.meeting.endMinute.compareTo(b.meeting.endMinute);
    return end != 0 ? end : a.id.compareTo(b.id);
  });
  final result = <_Placement>[];
  final group = <_Placement>[];
  final laneEnds = <int>[];
  var groupEnd = -1;
  void finishGroup() {
    for (final placement in group) {
      placement.laneCount = laneEnds.length;
    }
    group.clear();
    laneEnds.clear();
  }

  for (final occurrence in occurrences) {
    if (occurrence.meeting.startMinute >= groupEnd) finishGroup();
    var lane = laneEnds.indexWhere(
      (end) => end <= occurrence.meeting.startMinute,
    );
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(occurrence.meeting.endMinute);
    } else {
      laneEnds[lane] = occurrence.meeting.endMinute;
    }
    final placement = _Placement(occurrence, lane);
    result.add(placement);
    group.add(placement);
    groupEnd = math.max(groupEnd, occurrence.meeting.endMinute);
  }
  finishGroup();
  return result;
}

class _TimetableLines extends CustomPainter {
  const _TimetableLines({
    required this.color,
    required this.railWidth,
    required this.dayWidth,
    required this.dayCount,
    required this.hourHeight,
    required this.hourCount,
  });
  final Color color;
  final double railWidth;
  final double dayWidth;
  final int dayCount;
  final double hourHeight;
  final int hourCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .6;
    for (var day = 0; day <= dayCount; day++) {
      final x = railWidth + day * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var hour = 1; hour < hourCount; hour++) {
      final y = hour * hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_TimetableLines oldDelegate) =>
      color != oldDelegate.color ||
      railWidth != oldDelegate.railWidth ||
      dayWidth != oldDelegate.dayWidth ||
      dayCount != oldDelegate.dayCount ||
      hourHeight != oldDelegate.hourHeight ||
      hourCount != oldDelegate.hourCount;
}
