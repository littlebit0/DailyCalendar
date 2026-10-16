import '../../../core/calendar/calendar_event_movement.dart';
import '../domain/calendar_event.dart';
import '../domain/recurrence_rule.dart';

class RecurrenceExpander {
  DateTime lastPlannedEnd(CalendarEvent event) {
    final until = event.recurrence.until;
    final count = event.recurrence.count;
    DateTime? end = count == null ? null : lastCountedEnd(event);
    if (until != null) {
      final limit = DateTime(until.year, until.month, until.day + 1);
      final fastForward = _fastForward(
        current: event.startAt,
        duration: Duration.zero,
        rangeStart: limit.subtract(const Duration(microseconds: 1)),
        rule: event.recurrence,
      );
      var current = fastForward.current;
      var index = fastForward.skippedOccurrences;
      var last = event.startAt;
      while (current.isBefore(limit)) {
        last = current;
        final next = _at(event.startAt, event.recurrence, ++index);
        if (!next.isAfter(current)) break;
        current = next;
      }
      final untilEnd = last.add(event.duration);
      if (end == null || untilEnd.isBefore(end)) end = untilEnd;
    }
    return end ?? event.endAt;
  }

  DateTime lastCountedEnd(CalendarEvent event) {
    final steps = (event.recurrence.count ?? 1) - 1;
    if (steps <= 0) return event.endAt;
    return _at(event.startAt, event.recurrence, steps).add(event.duration);
  }

  List<CalendarEvent> expand(
    CalendarEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    if (!event.recurrence.isRepeating) {
      return event.overlaps(rangeStart, rangeEnd) ? [event] : const [];
    }

    final occurrences = <CalendarEvent>[];
    final duration = event.endAt.difference(event.startAt);
    var current = event.startAt;
    var generated = 0;
    final until = event.recurrence.until;
    final maxCount = event.recurrence.count;

    final fastForward = _fastForward(
      current: current,
      duration: duration,
      rangeStart: rangeStart,
      rule: event.recurrence,
    );
    current = fastForward.current;
    generated = fastForward.skippedOccurrences;

    while (current.isBefore(rangeEnd)) {
      generated += 1;
      if (until != null && _isAfterCalendarDate(current, until)) {
        break;
      }
      if (maxCount != null && generated > maxCount) {
        break;
      }

      final occurrenceEnd = current.add(duration);
      if (!event.recurrence.excludes(current) &&
          current.isBefore(rangeEnd) &&
          occurrenceEnd.isAfter(rangeStart)) {
        occurrences.add(
          event.copyWith(
            occurrenceId: '${event.id}@${current.toIso8601String()}',
            startAt: current,
            endAt: occurrenceEnd,
          ),
        );
      }

      final next = _at(event.startAt, event.recurrence, generated);
      if (!next.isAfter(current)) {
        break;
      }
      current = next;
    }

    return occurrences;
  }

  _FastForwardResult _fastForward({
    required DateTime current,
    required Duration duration,
    required DateTime rangeStart,
    required RecurrenceRule rule,
  }) {
    final interval = rule.interval < 1 ? 1 : rule.interval;
    final stepDays = switch (rule.frequency) {
      RecurrenceFrequency.daily => interval,
      RecurrenceFrequency.weekly => 7 * interval,
      _ => null,
    };
    if (stepDays == null) {
      return _FastForwardResult(current, 0);
    }

    final earliestRelevantStart = rangeStart.subtract(duration);
    if (!earliestRelevantStart.isAfter(current)) {
      return _FastForwardResult(current, 0);
    }

    // Step by calendar days so the local start time survives daylight-saving
    // changes; elapsed 24-hour periods would shift it by an hour.
    var skipped =
        calendarDayDifference(earliestRelevantStart, current) ~/ stepDays;
    var candidate = shiftCalendarDateByDays(current, stepDays * skipped);
    while (skipped > 0 && candidate.isAfter(earliestRelevantStart)) {
      skipped -= 1;
      candidate = shiftCalendarDateByDays(current, stepDays * skipped);
    }
    if (skipped <= 0) {
      return _FastForwardResult(current, 0);
    }
    return _FastForwardResult(candidate, skipped);
  }

  DateTime _at(DateTime current, RecurrenceRule rule, int index) {
    if (index == 0) return current;
    final interval = (rule.interval < 1 ? 1 : rule.interval) * index;
    return switch (rule.frequency) {
      RecurrenceFrequency.none => current,
      RecurrenceFrequency.daily => shiftCalendarDateByDays(current, interval),
      RecurrenceFrequency.weekly => shiftCalendarDateByDays(
        current,
        7 * interval,
      ),
      RecurrenceFrequency.monthly => _addMonths(
        current,
        interval,
        rule.anchorDay,
      ),
      RecurrenceFrequency.yearly => _addYears(
        current,
        interval,
        rule.anchorDay,
      ),
    };
  }

  DateTime _addMonths(DateTime value, int months, int? anchorDay) {
    final targetMonth = value.month + months;
    final targetYear = value.year + ((targetMonth - 1) ~/ 12);
    final normalizedMonth = ((targetMonth - 1) % 12) + 1;
    final day = (anchorDay ?? value.day).clamp(
      1,
      _daysInMonth(targetYear, normalizedMonth),
    );
    final construct = value.isUtc ? DateTime.utc : DateTime.new;
    return construct(
      targetYear,
      normalizedMonth,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  DateTime _addYears(DateTime value, int years, int? anchorDay) {
    final targetYear = value.year + years;
    final day = (anchorDay ?? value.day).clamp(
      1,
      _daysInMonth(targetYear, value.month),
    );
    final construct = value.isUtc ? DateTime.utc : DateTime.new;
    return construct(
      targetYear,
      value.month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool _isAfterCalendarDate(DateTime value, DateTime boundary) {
    final valueDate = DateTime(value.year, value.month, value.day);
    final boundaryDate = DateTime(boundary.year, boundary.month, boundary.day);
    return valueDate.isAfter(boundaryDate);
  }
}

class _FastForwardResult {
  const _FastForwardResult(this.current, this.skippedOccurrences);

  final DateTime current;
  final int skippedOccurrences;
}
