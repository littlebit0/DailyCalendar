import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

// Run under a DST zone (e.g. TZ=America/New_York) to cover 23h/25h days; in
// zones without DST these still guard the local-midnight contract.
void main() {
  CalendarEvent event(String id, DateTime start, Duration length) =>
      CalendarEvent(
        id: id,
        title: id,
        startAt: start,
        endAt: start.add(length),
        allDay: false,
        category: EventCategory.basic,
        colorValue: 1,
        createdAt: start,
        updatedAt: start,
      );

  void expectMidnight(DateTime value, DateTime expectedDate) {
    expect(
      value,
      DateTime(expectedDate.year, expectedDate.month, expectedDate.day),
    );
  }

  // US DST ends on 2026-11-01 (25h day) and starts on 2026-03-08 (23h day).
  final dstEnd = DateTime(2026, 11, 1);
  final dstStart = DateTime(2026, 3, 8);

  test('day range ends at next local midnight on DST days', () {
    for (final day in [dstEnd, dstStart, DateTime(2026, 11, 3)]) {
      final range = calendarDayRangeForTesting(
        day.add(const Duration(hours: 15)),
      );
      expectMidnight(range.start, day);
      expectMidnight(range.end, DateTime(day.year, day.month, day.day + 1));
    }
  });

  test('late event on the 25h DST-end day stays in that day', () {
    final late = event(
      'late',
      DateTime(2026, 11, 1, 23, 15),
      const Duration(minutes: 30),
    );
    final control = event(
      'control',
      DateTime(2026, 11, 3, 23, 15),
      const Duration(minutes: 30),
    );
    final events = [late, control];

    expect(calendarEventsForDayForTesting(events, dstEnd), [late]);
    expect(
      calendarEventsForDayForTesting(events, DateTime(2026, 11, 2)),
      isEmpty,
    );
    expect(calendarEventsForDayForTesting(events, DateTime(2026, 11, 3)), [
      control,
    ]);
  });

  test('next-day midnight event does not leak into the 23h DST-start day', () {
    final midnight = event(
      'midnight',
      DateTime(2026, 3, 9),
      const Duration(minutes: 30),
    );
    final late = event(
      'late',
      DateTime(2026, 3, 8, 23, 15),
      const Duration(minutes: 30),
    );
    final events = [midnight, late];

    expect(calendarEventsForDayForTesting(events, dstStart), [late]);
    expect(calendarEventsForDayForTesting(events, DateTime(2026, 3, 9)), [
      midnight,
    ]);
  });

  test('week and month ranges keep local midnight bounds across DST', () {
    for (final monday in [true, false]) {
      for (final day in [dstEnd, dstStart]) {
        final week = calendarWeekRangeForTesting(day, monday);
        final leading = monday ? day.weekday - 1 : day.weekday % 7;
        final weekStart = DateTime(day.year, day.month, day.day - leading);
        expectMidnight(week.start, weekStart);
        expectMidnight(
          week.end,
          DateTime(weekStart.year, weekStart.month, weekStart.day + 7),
        );

        final month = calendarMonthRangeForTesting(day, monday);
        final first = DateTime(day.year, day.month);
        final monthLeading = monday ? first.weekday - 1 : first.weekday % 7;
        final gridStart = DateTime(first.year, first.month, 1 - monthLeading);
        expectMidnight(month.start, gridStart);
        expectMidnight(
          month.end,
          DateTime(gridStart.year, gridStart.month, gridStart.day + 42),
        );
      }
    }
  });
}
