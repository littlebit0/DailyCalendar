import 'package:daily/core/time/calendar_clock.dart';
import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/features/calendar/widgets/schedule_timeline_view.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Run under a DST zone (CI uses TZ=America/New_York) to cover 23h/25h days; in
// zones without DST these still guard the local-midnight contract.
class _FakeClock {
  _FakeClock(this.current);

  DateTime current;

  DateTime now() => current;

  /// Moves wall time and fake-async timers forward together.
  Future<void> advance(WidgetTester tester, Duration duration) async {
    current = current.add(duration);
    await tester.pump(duration);
  }
}

CalendarEvent _ddayEvent(DateTime day) => CalendarEvent(
  id: 'dday',
  title: '마감',
  startAt: day,
  endAt: DateTime(day.year, day.month, day.day + 1),
  allDay: true,
  category: EventCategory.basic,
  colorValue: EventCategory.basic.colorValue,
  createdAt: day,
  updatedAt: day,
  showDday: true,
);

Widget _monthGrid(
  _FakeClock clock,
  DateTime month,
  List<CalendarEvent> events,
) => CalendarClockScope(
  now: clock.now,
  child: MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 700,
        height: 420,
        child: CalendarMonthGrid(
          month: month,
          selectedDate: DateTime(month.year, month.month),
          events: events,
          weekStartsOnMonday: true,
          showLunarDates: false,
          onDateSelected: (_) {},
        ),
      ),
    ),
  ),
);

bool _monthMarksToday(WidgetTester tester, DateTime day) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(
        ValueKey('day-number-${day.year}-${day.month}-${day.day}'),
      ),
      matching: find.byType(Text),
    ),
  );
  return text.style?.fontWeight == FontWeight.w800;
}

bool _timelineMarksToday(WidgetTester tester, DateTime day) {
  final text = tester.widget<Text>(
    find.byKey(
      ValueKey('schedule-day-header-${day.year}-${day.month}-${day.day}'),
    ),
  );
  return text.style?.fontWeight == FontWeight.w700;
}

void main() {
  test('next minute is measured from elapsed seconds', () {
    // 01:59:30 on the US DST-end day is followed by a repeated 01:00 hour.
    expect(
      durationUntilNextMinute(DateTime(2026, 11, 1, 1, 59, 30)),
      const Duration(seconds: 30),
    );
    expect(
      durationUntilNextMinute(DateTime(2026, 11, 19, 10, 15)),
      const Duration(minutes: 1),
    );
  });

  testWidgets('month today mark and D-day move at 23:59 -> 00:01', (
    tester,
  ) async {
    final clock = _FakeClock(DateTime(2026, 11, 19, 23, 59));
    await tester.pumpWidget(
      _monthGrid(clock, DateTime(2026, 11), [
        _ddayEvent(DateTime(2026, 11, 20)),
      ]),
    );

    expect(_monthMarksToday(tester, DateTime(2026, 11, 19)), isTrue);
    expect(_monthMarksToday(tester, DateTime(2026, 11, 20)), isFalse);
    expect(find.textContaining('D-1'), findsOneWidget);

    await clock.advance(tester, const Duration(minutes: 2));

    expect(_monthMarksToday(tester, DateTime(2026, 11, 19)), isFalse);
    expect(_monthMarksToday(tester, DateTime(2026, 11, 20)), isTrue);
    expect(find.textContaining('D-day'), findsOneWidget);
    expect(find.textContaining('D-1'), findsNothing);
  });

  testWidgets('timeline current-time line moves each minute and at midnight', (
    tester,
  ) async {
    final clock = _FakeClock(DateTime(2026, 11, 19, 23, 57, 30));
    final days = [DateTime(2026, 11, 19), DateTime(2026, 11, 20)];
    await tester.pumpWidget(
      CalendarClockScope(
        now: clock.now,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 600,
              child: ScheduleTimelineView(
                days: days,
                events: const [],
                selectedDate: days.first,
                use24HourTime: true,
                showAllDayEvents: true,
                holidayBackgroundEnabled: true,
                holidayColorValue: EventCategory.holiday.colorValue,
                onShowAllDayEventsChanged: (_) {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final line = find.byKey(const ValueKey('schedule-current-time-indicator'));
    final at2357 = tester.getTopLeft(line);
    expect(_timelineMarksToday(tester, days.first), isTrue);

    await clock.advance(tester, const Duration(seconds: 30));
    final at2358 = tester.getTopLeft(line);
    expect(at2358.dx, at2357.dx);
    expect(at2358.dy, greaterThan(at2357.dy));

    await clock.advance(tester, const Duration(minutes: 1));
    await clock.advance(tester, const Duration(minutes: 1));
    await clock.advance(tester, const Duration(minutes: 1));
    final at0001 = tester.getTopLeft(line);
    expect(at0001.dx, greaterThan(at2358.dx));
    expect(at0001.dy, lessThan(at2358.dy));
    expect(_timelineMarksToday(tester, days.first), isFalse);
    expect(_timelineMarksToday(tester, days.last), isTrue);
  });

  testWidgets('returning to the app picks up a date change', (tester) async {
    final clock = _FakeClock(DateTime(2026, 11, 19, 10));
    await tester.pumpWidget(_monthGrid(clock, DateTime(2026, 11), const []));
    expect(_monthMarksToday(tester, DateTime(2026, 11, 19)), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // Background: the midnight timer is stopped, so nothing changes yet.
    await clock.advance(tester, const Duration(days: 1));
    expect(_monthMarksToday(tester, DateTime(2026, 11, 19)), isTrue);

    // Also stands in for a clock or time zone change made in system settings.
    clock.current = DateTime(2026, 11, 20, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_monthMarksToday(tester, DateTime(2026, 11, 19)), isFalse);
    expect(_monthMarksToday(tester, DateTime(2026, 11, 20)), isTrue);
  });

  // US DST starts on 2026-03-08 (23h day) and ends on 2026-11-01 (25h day).
  for (final day in [DateTime(2026, 3, 8), DateTime(2026, 11, 1)]) {
    testWidgets('today changes exactly at local midnight on $day', (
      tester,
    ) async {
      final start = DateTime(day.year, day.month, day.day, 0, 1);
      final next = DateTime(day.year, day.month, day.day + 1);
      final clock = _FakeClock(start);
      await tester.pumpWidget(
        _monthGrid(clock, DateTime(day.year, day.month), const []),
      );

      await clock.advance(
        tester,
        next.difference(start) - const Duration(minutes: 2),
      );
      expect(_monthMarksToday(tester, day), isTrue);
      expect(clock.current.day, day.day);

      await clock.advance(tester, const Duration(minutes: 3));
      expect(clock.current.day, next.day);
      expect(_monthMarksToday(tester, day), isFalse);
      expect(_monthMarksToday(tester, next), isTrue);
    });
  }
}
