import 'package:daily/core/calendar/calendar_event_span.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CalendarEvent event(String id, DateTime start, DateTime end) => CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: end,
    allDay: true,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: start,
    updatedAt: start,
  );

  test(
    'midnight LMS deadline occupies its own date without a fabricated duration',
    () {
      final due = DateTime(2026, 9, 26);
      final deadline = event('lms:due', due, due).copyWith(
        allDay: false,
        lms: LmsEventMetadata(
          schoolId: 'smu',
          ownerId: 'student@example.com',
          lmsUserId: '1',
          courseId: '2',
          courseTitle: '수업',
          activityType: 'quiz',
          activityId: '3',
          sourceUrl: 'https://ecampus.smu.ac.kr/mod/quiz/view.php?id=3',
          dueAt: due,
        ),
      );
      final span = CalendarEventSpan.fromEvent(deadline, due, dayCount: 1)!;
      expect((span.startCol, span.endCol, span.span), (0, 0, 1));
      expect(
        CalendarEventSpan.fromEvent(
          deadline,
          due.subtract(const Duration(days: 1)),
          dayCount: 1,
        ),
        isNull,
      );
      expect(deadline.duration, Duration.zero);
    },
  );

  test('exclusive ends and week boundaries produce one clipped span', () {
    final trip = event('trip', DateTime(2026, 8, 27), DateTime(2026, 9, 2));
    final first = CalendarEventSpan.fromEvent(trip, DateTime(2026, 8, 23))!;
    final second = CalendarEventSpan.fromEvent(trip, DateTime(2026, 8, 30))!;
    expect((first.startCol, first.endCol, first.span), (4, 6, 3));
    expect((second.startCol, second.endCol, second.span), (0, 2, 3));
    expect(
      CalendarEventSpan.fromEvent(trip, DateTime(2026, 9, 2), dayCount: 1),
      isNull,
    );
    expect(
      CalendarEventSpan.fromEvent(
        trip,
        DateTime(2026, 9, 1),
        dayCount: 1,
      )!.span,
      1,
    );
  });

  test(
    'overlapping spans keep one lane over all their dates and reuse empty lanes',
    () {
      final first = DateTime(2026, 8, 23);
      final spans = layoutCalendarEventLanes([
        CalendarEventSpan.fromEvent(
          event('a', first, DateTime(2026, 8, 26)),
          first,
        )!,
        CalendarEventSpan.fromEvent(
          event('b', DateTime(2026, 8, 24), DateTime(2026, 8, 27)),
          first,
        )!,
        CalendarEventSpan.fromEvent(
          event('c', DateTime(2026, 8, 26), DateTime(2026, 8, 29)),
          first,
        )!,
      ]);
      expect(spans.map((span) => span.lane), [0, 1, 0]);
      expect(spans.map((span) => span.event.id), ['a', 'b', 'c']);
    },
  );

  test('date columns are calendar dates, including a DST transition week', () {
    final item = event('dst', DateTime(2026, 3, 9), DateTime(2026, 3, 10));
    final span = CalendarEventSpan.fromEvent(item, DateTime(2026, 3, 8))!;
    expect((span.startCol, span.endCol), (1, 1));
  });

  group('overnight timed events (#696, #791)', () {
    CalendarEvent timed(DateTime start, DateTime end) =>
        event('night', start, end).copyWith(allDay: false);
    List<DateTime> listedDays(
      CalendarEvent item,
      DateTime from,
      int count, {
      required bool showOvernight,
    }) =>
        [
          for (var index = 0; index < count; index++)
            DateTime(from.year, from.month, from.day + index),
        ].where((day) {
          final next = DateTime(day.year, day.month, day.day + 1);
          return calendarEventListedOnDay(
            item.copyWith(showOvernightOnFollowingDays: showOvernight),
            day,
            next,
          );
        }).toList();

    test('lists every overlapped date when on and only the start when off', () {
      final item = timed(DateTime(2026, 10, 29, 22), DateTime(2026, 10, 30, 2));
      final from = DateTime(2026, 10, 28);
      expect(listedDays(item, from, 4, showOvernight: true), [
        DateTime(2026, 10, 29),
        DateTime(2026, 10, 30),
      ]);
      expect(listedDays(item, from, 4, showOvernight: false), [
        DateTime(2026, 10, 29),
      ]);
    });

    test('an exact midnight end never adds the end date', () {
      final item = timed(DateTime(2026, 10, 29, 22), DateTime(2026, 10, 30));
      expect(listedDays(item, DateTime(2026, 10, 28), 4, showOvernight: true), [
        DateTime(2026, 10, 29),
      ]);
    });

    test('multi-day spans cross month, year and leap-day boundaries', () {
      final yearEnd = timed(
        DateTime(2026, 12, 31, 20),
        DateTime(2027, 1, 2, 1),
      );
      expect(
        listedDays(yearEnd, DateTime(2026, 12, 30), 5, showOvernight: true),
        [DateTime(2026, 12, 31), DateTime(2027, 1, 1), DateTime(2027, 1, 2)],
      );
      expect(
        listedDays(yearEnd, DateTime(2026, 12, 30), 5, showOvernight: false),
        [DateTime(2026, 12, 31)],
      );
      final leap = timed(DateTime(2028, 2, 28, 23), DateTime(2028, 3, 1, 1));
      expect(listedDays(leap, DateTime(2028, 2, 27), 4, showOvernight: true), [
        DateTime(2028, 2, 28),
        DateTime(2028, 2, 29),
        DateTime(2028, 3, 1),
      ]);
    });

    test('all-day events keep their whole span when off', () {
      final trip = event('trip', DateTime(2026, 5, 4), DateTime(2026, 5, 6));
      expect(listedDays(trip, DateTime(2026, 5, 3), 4, showOvernight: false), [
        DateTime(2026, 5, 4),
        DateTime(2026, 5, 5),
      ]);
    });

    test('local dates are used across a daylight-saving change', () {
      // Calendar-date arithmetic, so a 23/25-hour local day keeps its date.
      final item = timed(DateTime(2026, 11, 1, 23), DateTime(2026, 11, 2, 1));
      expect(listedDays(item, DateTime(2026, 10, 31), 4, showOvernight: true), [
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      ]);
      expect(
        listedDays(item, DateTime(2026, 10, 31), 4, showOvernight: false),
        [DateTime(2026, 11, 1)],
      );
    });

    test('new events default to listing every overlapped date', () {
      final item = timed(DateTime(2026, 10, 29, 22), DateTime(2026, 10, 30, 2));
      expect(item.showOvernightOnFollowingDays, isTrue);
      expect(
        calendarEventListedOnDay(
          item,
          DateTime(2026, 10, 30),
          DateTime(2026, 10, 31),
        ),
        isTrue,
      );
    });

    test('each event keeps its own choice on the same date', () {
      final shift = timed(DateTime(2026, 10, 29, 22), DateTime(2026, 10, 30, 6));
      final party = shift.copyWith(showOvernightOnFollowingDays: false);
      final day = DateTime(2026, 10, 30);
      final next = DateTime(2026, 10, 31);
      expect(calendarEventListedOnDay(shift, day, next), isTrue);
      expect(calendarEventListedOnDay(party, day, next), isFalse);
    });

    test('the editor switch only applies past the start date midnight', () {
      final start = DateTime(2026, 10, 29, 22);
      bool ends(DateTime end, {bool allDay = false}) =>
          calendarEventEndsAfterStartDay(
            allDay: allDay,
            startAt: start,
            endAt: end,
          );
      expect(ends(DateTime(2026, 10, 29, 23)), isFalse);
      expect(ends(DateTime(2026, 10, 30)), isFalse);
      expect(ends(DateTime(2026, 10, 30, 0, 1)), isTrue);
      expect(ends(DateTime(2026, 11, 2, 1)), isTrue);
      expect(ends(DateTime(2026, 11, 2), allDay: true), isFalse);
      // A 25-hour daylight-saving day still compares local dates.
      expect(
        calendarEventEndsAfterStartDay(
          allDay: false,
          startAt: DateTime(2026, 11, 1, 23),
          endAt: DateTime(2026, 11, 2, 0, 30),
        ),
        isTrue,
      );
    });

    test('start-day-only spans collapse to the start column', () {
      final item = timed(DateTime(2026, 10, 29, 22), DateTime(2026, 10, 31, 2));
      final weekStart = DateTime(2026, 10, 26);
      final full = CalendarEventSpan.fromEvent(item, weekStart)!;
      expect((full.startCol, full.endCol), (3, 5));
      final startOnly = CalendarEventSpan.fromEvent(
        item,
        weekStart,
        startDayOnly: true,
      )!;
      expect((startOnly.startCol, startOnly.endCol), (3, 3));
      // A carried-over event that started last week has nothing to show.
      expect(
        CalendarEventSpan.fromEvent(
          timed(DateTime(2026, 10, 25, 22), DateTime(2026, 10, 26, 2)),
          weekStart,
          startDayOnly: true,
        ),
        isNull,
      );
    });
  });
}
