import '../domain/calendar_event.dart';
import '../domain/recurrence_rule.dart';

class RecurrenceExpander {
  DateTime lastPlannedEnd(CalendarEvent event) {
    final until = event.recurrence.until;
    final count = event.recurrence.count;
    DateTime? end = count == null ? null : lastCountedEnd(event);
    if (until != null) {
      final limit = DateTime(until.year, until.month, until.day + 1);
      var current = _fastForward(
        current: event.startAt,
        duration: Duration.zero,
        rangeStart: limit.subtract(const Duration(microseconds: 1)),
        rule: event.recurrence,
      ).current;
      var last = event.startAt;
      while (current.isBefore(limit)) {
        last = current;
        final next = _next(current, event.recurrence);
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
    final interval = event.recurrence.interval < 1
        ? 1
        : event.recurrence.interval;
    if (event.recurrence.frequency == RecurrenceFrequency.daily ||
        event.recurrence.frequency == RecurrenceFrequency.weekly) {
      final days = event.recurrence.frequency == RecurrenceFrequency.daily
          ? 1
          : 7;
      return event.startAt
          .add(Duration(days: steps * interval * days))
          .add(event.duration);
    }
    var start = event.startAt;
    for (var index = 0; index < steps; index++) {
      start = _next(start, event.recurrence);
    }
    return start.add(event.duration);
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

      final next = _next(current, event.recurrence);
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
    final step = switch (rule.frequency) {
      RecurrenceFrequency.daily => Duration(
        days: rule.interval < 1 ? 1 : rule.interval,
      ),
      RecurrenceFrequency.weekly => Duration(
        days: 7 * (rule.interval < 1 ? 1 : rule.interval),
      ),
      _ => null,
    };
    if (step == null) {
      return _FastForwardResult(current, 0);
    }

    final earliestRelevantStart = rangeStart.subtract(duration);
    if (!earliestRelevantStart.isAfter(current)) {
      return _FastForwardResult(current, 0);
    }

    final elapsedMicroseconds = earliestRelevantStart
        .difference(current)
        .inMicroseconds;
    final skipped = elapsedMicroseconds ~/ step.inMicroseconds;
    if (skipped <= 0) {
      return _FastForwardResult(current, 0);
    }
    return _FastForwardResult(current.add(step * skipped), skipped);
  }

  DateTime _next(DateTime current, RecurrenceRule rule) {
    final interval = rule.interval < 1 ? 1 : rule.interval;
    return switch (rule.frequency) {
      RecurrenceFrequency.none => current,
      RecurrenceFrequency.daily => current.add(Duration(days: interval)),
      RecurrenceFrequency.weekly => current.add(Duration(days: 7 * interval)),
      RecurrenceFrequency.monthly => _addMonths(current, interval),
      RecurrenceFrequency.yearly => _addYears(current, interval),
    };
  }

  DateTime _addMonths(DateTime value, int months) {
    final targetMonth = value.month + months;
    final targetYear = value.year + ((targetMonth - 1) ~/ 12);
    final normalizedMonth = ((targetMonth - 1) % 12) + 1;
    final day = value.day.clamp(1, _daysInMonth(targetYear, normalizedMonth));
    return DateTime(
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

  DateTime _addYears(DateTime value, int years) {
    final targetYear = value.year + years;
    final day = value.day.clamp(1, _daysInMonth(targetYear, value.month));
    return DateTime(
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
