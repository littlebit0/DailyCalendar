import 'dart:ui' show Offset;

import '../../features/events/data/recurrence_expander.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/recurrence_rule.dart';

typedef CalendarEventDropCallback =
    Future<void> Function(
      CalendarEvent event,
      DateTime targetDate,
      int targetIndex,
    );

typedef CalendarEventTimeDropCallback =
    Future<void> Function(CalendarEvent event, DateTime targetStart);

enum CalendarEventDragOrigin { calendar, sidebar }

class CalendarEventDragPayload {
  CalendarEventDragPayload(
    this.event, {
    this.origin = CalendarEventDragOrigin.calendar,
    this.sourceStartOffset = Duration.zero,
  });

  final CalendarEvent event;
  final CalendarEventDragOrigin origin;

  /// Wall-clock time from [event]'s start to the top of the dragged block.
  /// Non-zero only for a block clipped at midnight.
  final Duration sourceStartOffset;

  /// Pointer position inside the dragged block when the drag started.
  Offset? grabOffset;
}

const calendarEventAppendIndex = 1 << 30;

bool calendarEventCanMove(CalendarEvent event) {
  return !event.readOnly &&
      !event.systemEvent &&
      !event.holiday &&
      event.lms == null;
}

CalendarEvent shiftCalendarEventToDate(
  CalendarEvent event,
  DateTime targetDate,
) {
  final normalizedTarget = DateTime(
    targetDate.year,
    targetDate.month,
    targetDate.day,
  );
  final start = event.startAt;
  final shiftedStart = event.allDay
      ? normalizedTarget
      : DateTime(
          normalizedTarget.year,
          normalizedTarget.month,
          normalizedTarget.day,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
          start.microsecond,
        );
  return event.copyWith(
    startAt: shiftedStart,
    endAt: shiftedStart.add(event.duration),
  );
}

CalendarEvent shiftCalendarEventToStart(
  CalendarEvent event,
  DateTime targetStart,
) {
  if (event.allDay) {
    return shiftCalendarEventToDate(event, targetStart);
  }
  return event.copyWith(
    startAt: targetStart,
    endAt: targetStart.add(event.duration),
  );
}

int calendarDayDifference(DateTime target, DateTime source) {
  final targetDate = DateTime.utc(target.year, target.month, target.day);
  final sourceDate = DateTime.utc(source.year, source.month, source.day);
  return targetDate.difference(sourceDate).inDays;
}

DateTime shiftCalendarDateByDays(DateTime value, int days) {
  return DateTime(
    value.year,
    value.month,
    value.day + days,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

/// Weekday/position conditions after the series moves by [days].
///
/// Weekly and daily weekday lists rotate with the move. Month positions and
/// month days only make sense relative to the old date, so a moved series goes
/// back to repeating on its new date.
RecurrenceRule _withShiftedDetails(
  RecurrenceRule target,
  RecurrenceRule rule,
  int days,
) {
  if (!rule.hasDetails) return target;
  if (days == 0) {
    return target.copyWith(
      byDay: rule.byDay,
      byMonthDay: rule.byMonthDay,
      byMonth: rule.byMonth,
      bySetPos: rule.bySetPos,
      weekStart: rule.weekStart,
    );
  }
  final weekdayRule =
      rule.frequency == RecurrenceFrequency.weekly ||
      rule.frequency == RecurrenceFrequency.daily;
  if (!weekdayRule) return target;
  const codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  final rotated = <String>[];
  for (final token in rule.byDay) {
    final index = codes.indexOf(token.replaceAll(RegExp(r'[^A-Z]'), ''));
    if (index != -1) rotated.add(codes[(index + days) % 7]);
  }
  return target.copyWith(
    byDay: rotated,
    byMonth: rule.frequency == RecurrenceFrequency.daily
        ? rule.byMonth
        : const [],
    weekStart: rule.frequency == RecurrenceFrequency.weekly
        ? _rotatedWeekday(rule.weekStart, days)
        : null,
  );
}

int? _rotatedWeekday(int? weekday, int days) =>
    weekday == null ? null : (weekday - 1 + days) % 7 + 1;

RecurrenceRule shiftRecurrenceRuleByDays(RecurrenceRule rule, int days) {
  return _withShiftedDetails(
    RecurrenceRule(
      frequency: rule.frequency,
      interval: rule.interval,
      until: rule.until == null
          ? null
          : shiftCalendarDateByDays(rule.until!, days),
      count: rule.count,
      anchorDay: days == 0 ? rule.anchorDay : null,
      excludedDates: rule.excludedDates
          .map((date) => shiftCalendarDateByDays(date, days))
          .toList(growable: false),
    ),
    rule,
    days,
  );
}

RecurrenceRule recurrenceRuleForMovedFuture({
  required CalendarEvent base,
  required CalendarEvent occurrence,
  required DateTime targetDate,
}) {
  final rule = base.recurrence;
  final dayOffset = calendarDayDifference(targetDate, occurrence.startAt);
  final occurrenceDate = DateTime(
    occurrence.startAt.year,
    occurrence.startAt.month,
    occurrence.startAt.day,
  );
  final shifted = _withShiftedDetails(
    RecurrenceRule(
      frequency: rule.frequency,
      interval: rule.interval,
      until: rule.until == null
          ? null
          : shiftCalendarDateByDays(rule.until!, dayOffset),
      count: _remainingRecurrenceCount(base, occurrence),
      anchorDay: dayOffset == 0 ? rule.anchorDay ?? base.startAt.day : null,
      excludedDates: rule.excludedDates
          .where((date) => !_calendarDate(date).isBefore(occurrenceDate))
          .map((date) => shiftCalendarDateByDays(date, dayOffset))
          .toList(growable: false),
    ),
    rule,
    dayOffset,
  );
  if (shifted.frequency != RecurrenceFrequency.weekly || !shifted.hasDetails) {
    return shifted;
  }
  // The new series starts mid-period; keep the original week boundary so
  // later dates stay where they were.
  final weekStart = _rotatedWeekday(
    rule.weekStartFor(base.startAt),
    dayOffset,
  )!;
  final newStart = _calendarDate(
    shiftCalendarDateByDays(occurrence.startAt, dayOffset),
  );
  if (weekStart == newStart.weekday) {
    return shifted.copyWith(clearWeekStart: true);
  }
  // Apps up to 4.1.0 drop weekStart but keep exclusions; the period's first
  // day before the start restores the boundary (RecurrenceRule.weekStartFor).
  final periodStart = shiftCalendarDateByDays(
    newStart,
    -((newStart.weekday - weekStart) % 7),
  );
  return shifted.copyWith(
    weekStart: weekStart,
    excludedDates: [periodStart, ...shifted.excludedDates],
  );
}

int? _remainingRecurrenceCount(CalendarEvent base, CalendarEvent occurrence) {
  final totalCount = base.recurrence.count;
  if (totalCount == null) {
    return null;
  }
  if (base.recurrence.hasDetails) {
    // Several dates can share one period, so count the real occurrences
    // before this one (excluded dates still use up the series count).
    final before = RecurrenceExpander().expand(
      base.copyWith(
        // Clearing exclusions also drops a week-start marker; keep its week.
        recurrence: base.recurrence.copyWith(
          clearCount: true,
          clearUntil: true,
          excludedDates: const [],
          weekStart: base.recurrence.weekStartFor(base.startAt),
        ),
      ),
      base.startAt,
      occurrence.startAt,
    );
    return (totalCount - before.length).clamp(1, totalCount).toInt();
  }
  final interval = base.recurrence.interval < 1 ? 1 : base.recurrence.interval;
  final elapsedOccurrences = switch (base.recurrence.frequency) {
    RecurrenceFrequency.none => 0,
    RecurrenceFrequency.daily =>
      calendarDayDifference(occurrence.startAt, base.startAt) ~/ interval,
    RecurrenceFrequency.weekly =>
      calendarDayDifference(occurrence.startAt, base.startAt) ~/ (7 * interval),
    RecurrenceFrequency.monthly =>
      ((occurrence.startAt.year - base.startAt.year) * 12 +
              occurrence.startAt.month -
              base.startAt.month) ~/
          interval,
    RecurrenceFrequency.yearly =>
      (occurrence.startAt.year - base.startAt.year) ~/ interval,
  };
  return (totalCount - elapsedOccurrences).clamp(1, totalCount).toInt();
}

DateTime _calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
