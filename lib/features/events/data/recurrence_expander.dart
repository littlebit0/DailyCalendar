import '../../../core/calendar/calendar_event_movement.dart';
import '../domain/calendar_event.dart';
import '../domain/recurrence_rule.dart';

class RecurrenceExpander {
  DateTime lastPlannedEnd(CalendarEvent event) {
    final until = event.recurrence.until;
    final count = event.recurrence.count;
    if (event.recurrence.hasDetails) {
      return _detailedLastEnd(event);
    }
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
    if (event.recurrence.hasDetails) return _detailedLastEnd(event);
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

    if (event.recurrence.hasDetails) {
      return _expandDetailed(event, rangeStart, rangeEnd);
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

/// Occurrences of a rule with BYDAY/BYMONTHDAY/BYMONTH/BYSETPOS conditions.
///
/// Generated period by period (days, weeks, months, years), so the nth
/// occurrence has no closed form; the start date is always the first one.
extension _DetailedRecurrence on RecurrenceExpander {
  List<CalendarEvent> _expandDetailed(
    CalendarEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final rule = event.recurrence;
    final duration = event.endAt.difference(event.startAt);
    final occurrences = <CalendarEvent>[];
    var generated = 0;
    // A count needs every earlier occurrence; an open rule can jump ahead.
    final skipBefore = rule.count == null
        ? rangeStart.subtract(duration + const Duration(days: 1))
        : null;
    for (final start in _detailedStarts(event.startAt, rule, skipBefore)) {
      generated += 1;
      if (rule.count != null && generated > rule.count!) break;
      if (rule.until != null && _isAfterDate(start, rule.until!)) break;
      if (!start.isBefore(rangeEnd)) break;
      final end = start.add(duration);
      if (!rule.excludes(start) && end.isAfter(rangeStart)) {
        occurrences.add(
          event.copyWith(
            occurrenceId: '${event.id}@${start.toIso8601String()}',
            startAt: start,
            endAt: end,
          ),
        );
      }
    }
    return occurrences;
  }

  DateTime _detailedLastEnd(CalendarEvent event) {
    final rule = event.recurrence;
    var generated = 0;
    DateTime? last;
    for (final start in _detailedStarts(event.startAt, rule, null)) {
      generated += 1;
      if (rule.count != null && generated > rule.count!) break;
      if (rule.until != null && _isAfterDate(start, rule.until!)) break;
      last = start;
      if (rule.count == null && rule.until == null) break;
    }
    return (last ?? event.startAt).add(event.duration);
  }

  bool _isAfterDate(DateTime value, DateTime boundary) => DateTime(
    value.year,
    value.month,
    value.day,
  ).isAfter(DateTime(boundary.year, boundary.month, boundary.day));
}

const _weekdayCodes = {
  'MO': DateTime.monday,
  'TU': DateTime.tuesday,
  'WE': DateTime.wednesday,
  'TH': DateTime.thursday,
  'FR': DateTime.friday,
  'SA': DateTime.saturday,
  'SU': DateTime.sunday,
};

class _DayToken {
  const _DayToken(this.weekday, this.ordinal);

  final int weekday;
  final int? ordinal;
}

List<_DayToken> _dayTokens(List<String> values) {
  final tokens = <_DayToken>[];
  for (final value in values) {
    final match = RegExp(
      r'^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$',
    ).firstMatch(value.toUpperCase());
    if (match == null) continue;
    tokens.add(
      _DayToken(
        _weekdayCodes[match.group(2)]!,
        match.group(1) == null ? null : int.parse(match.group(1)!),
      ),
    );
  }
  return tokens;
}

int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// Days of one month selected by BYMONTHDAY / BYDAY / BYSETPOS (sorted).
List<int> _monthDays(int year, int month, RecurrenceRule rule, int startDay) {
  final length = _daysIn(year, month);
  final tokens = _dayTokens(rule.byDay);
  Set<int>? fromMonthDay;
  if (rule.byMonthDay.isNotEmpty) {
    fromMonthDay = {
      for (final day in rule.byMonthDay)
        if (day > 0 && day <= length)
          day
        else if (day < 0 && length + day + 1 >= 1)
          length + day + 1,
    };
  }
  Set<int>? fromWeekday;
  if (tokens.isNotEmpty) {
    fromWeekday = <int>{};
    for (final token in tokens) {
      final matching = [
        for (var day = 1; day <= length; day++)
          if (DateTime(year, month, day).weekday == token.weekday) day,
      ];
      final ordinal = token.ordinal;
      if (ordinal == null) {
        fromWeekday.addAll(matching);
      } else if (ordinal > 0 && ordinal <= matching.length) {
        fromWeekday.add(matching[ordinal - 1]);
      } else if (ordinal < 0 && -ordinal <= matching.length) {
        fromWeekday.add(matching[matching.length + ordinal]);
      }
    }
  }
  Set<int> days;
  if (fromMonthDay != null && fromWeekday != null) {
    days = fromMonthDay.intersection(fromWeekday);
  } else {
    days =
        fromMonthDay ??
        fromWeekday ??
        {
          if ((rule.anchorDay ?? startDay) <= length)
            rule.anchorDay ?? startDay,
        };
  }
  final sorted = days.toList()..sort();
  if (rule.bySetPos.isEmpty) return sorted;
  return {
    for (final position in rule.bySetPos)
      if (position > 0 && position <= sorted.length)
        sorted[position - 1]
      else if (position < 0 && -position <= sorted.length)
        sorted[sorted.length + position],
  }.toList()..sort();
}

Iterable<DateTime> _detailedStarts(
  DateTime start,
  RecurrenceRule rule,
  DateTime? skipBefore,
) sync* {
  final interval = rule.interval < 1 ? 1 : rule.interval;
  DateTime at(int year, int month, int day) => DateTime(
    year,
    month,
    day,
    start.hour,
    start.minute,
    start.second,
    start.millisecond,
    start.microsecond,
  );
  final tokens = _dayTokens(rule.byDay);
  final weekdays = {for (final token in tokens) token.weekday};
  final startDay = DateTime(start.year, start.month, start.day);
  var firstPeriod = 0;
  if (skipBefore != null && skipBefore.isAfter(start)) {
    final days = DateTime.utc(
      skipBefore.year,
      skipBefore.month,
      skipBefore.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    final months =
        (skipBefore.year - start.year) * 12 + skipBefore.month - start.month;
    firstPeriod =
        switch (rule.frequency) {
          RecurrenceFrequency.daily => days ~/ interval,
          RecurrenceFrequency.weekly => days ~/ (7 * interval),
          RecurrenceFrequency.monthly => months ~/ interval,
          _ => (skipBefore.year - start.year) ~/ interval,
        } -
        1;
    if (firstPeriod < 0) firstPeriod = 0;
  }
  // The start date is always the first occurrence.
  if (firstPeriod == 0) yield start;
  var yielded = 0;
  for (var period = firstPeriod; period < firstPeriod + 200000; period++) {
    final candidates = <DateTime>[];
    switch (rule.frequency) {
      case RecurrenceFrequency.daily:
        final day = DateTime(
          start.year,
          start.month,
          start.day + period * interval,
        );
        final monthDays = rule.byMonthDay.isEmpty
            ? null
            : _monthDays(
                day.year,
                day.month,
                rule.copyWith(byDay: const [], bySetPos: const []),
                day.day,
              );
        if ((weekdays.isEmpty || weekdays.contains(day.weekday)) &&
            (rule.byMonth.isEmpty || rule.byMonth.contains(day.month)) &&
            (monthDays == null || monthDays.contains(day.day))) {
          candidates.add(at(day.year, day.month, day.day));
        }
      case RecurrenceFrequency.weekly:
        final weekStart = DateTime(
          start.year,
          start.month,
          start.day - (start.weekday - DateTime.monday) + 7 * interval * period,
        );
        final wanted = weekdays.isEmpty ? {start.weekday} : weekdays;
        for (var offset = 0; offset < 7; offset++) {
          final day = DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + offset,
          );
          if (wanted.contains(day.weekday) &&
              (rule.byMonth.isEmpty || rule.byMonth.contains(day.month))) {
            candidates.add(at(day.year, day.month, day.day));
          }
        }
      case RecurrenceFrequency.monthly:
        final month = DateTime(start.year, start.month + period * interval);
        if (rule.byMonth.isEmpty || rule.byMonth.contains(month.month)) {
          for (final day in _monthDays(
            month.year,
            month.month,
            rule,
            start.day,
          )) {
            candidates.add(at(month.year, month.month, day));
          }
        }
      case RecurrenceFrequency.yearly:
        final year = start.year + period * interval;
        final months = rule.byMonth.isEmpty ? [start.month] : [...rule.byMonth]
          ..sort();
        for (final month in months) {
          if (month < 1 || month > 12) continue;
          for (final day in _monthDays(year, month, rule, start.day)) {
            candidates.add(at(year, month, day));
          }
        }
      case RecurrenceFrequency.none:
        return;
    }
    for (final candidate in candidates) {
      final day = DateTime(candidate.year, candidate.month, candidate.day);
      if (!day.isAfter(startDay)) continue;
      yield candidate;
      if (++yielded > 500000) return;
    }
  }
}

class _FastForwardResult {
  const _FastForwardResult(this.current, this.skippedOccurrences);

  final DateTime current;
  final int skippedOccurrences;
}
