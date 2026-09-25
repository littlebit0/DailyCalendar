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
}
