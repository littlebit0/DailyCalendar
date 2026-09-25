import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LMS source schedules cannot drag while personal schedules remain movable',
    () {
      final personal = _event(
        start: DateTime(2026, 9, 26),
        end: DateTime(2026, 9, 27),
      );
      final lms = personal.copyWith(
        lms: LmsEventMetadata(
          schoolId: 'smu',
          ownerId: 'student@example.com',
          lmsUserId: '42',
          courseId: '123',
          courseTitle: '자료구조',
          activityType: 'assignment',
          activityId: '456',
          sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=456',
        ),
      );
      expect(calendarEventCanMove(personal), isTrue);
      expect(calendarEventCanMove(lms), isFalse);
      expect(calendarEventCanMove(lms.copyWith(completed: true)), isFalse);
      expect(calendarEventCanMove(personal.copyWith(readOnly: true)), isFalse);
    },
  );
  test('timed move preserves wall-clock time and duration', () {
    final event = _event(
      start: DateTime(2026, 8, 21, 9, 35),
      end: DateTime(2026, 8, 21, 11, 5),
    );

    final shifted = shiftCalendarEventToDate(event, DateTime(2026, 9, 2));

    expect(shifted.startAt, DateTime(2026, 9, 2, 9, 35));
    expect(shifted.endAt, DateTime(2026, 9, 2, 11, 5));
    expect(shifted.duration, const Duration(minutes: 90));
  });

  test('all-day multi-day move preserves its exclusive-end span', () {
    final event = _event(
      start: DateTime(2026, 8, 21),
      end: DateTime(2026, 8, 25),
      allDay: true,
    );

    final shifted = shiftCalendarEventToDate(event, DateTime(2026, 9, 29));

    expect(shifted.startAt, DateTime(2026, 9, 29));
    expect(shifted.endAt, DateTime(2026, 10, 3));
    expect(shifted.duration, const Duration(days: 4));
  });

  test('whole-series move shifts recurrence boundaries and exclusions', () {
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      until: DateTime(2026, 9, 30),
      excludedDates: [DateTime(2026, 9, 9)],
    );

    final shifted = shiftRecurrenceRuleByDays(rule, 3);

    expect(shifted.until, DateTime(2026, 10, 3));
    expect(shifted.excludedDates, [DateTime(2026, 9, 12)]);
    expect(shifted.frequency, RecurrenceFrequency.weekly);
  });

  test('future-series move keeps only its remaining count and exclusions', () {
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      count: 6,
      until: DateTime(2026, 8, 10),
      excludedDates: [DateTime(2026, 7, 31), DateTime(2026, 8, 4)],
    );
    final base = _event(
      start: DateTime(2026, 8, 1, 9),
      end: DateTime(2026, 8, 1, 10),
      recurrence: rule,
    );
    final occurrence = base.copyWith(
      occurrenceId: 'move@2026-08-03T09:00:00.000',
      startAt: DateTime(2026, 8, 3, 9),
      endAt: DateTime(2026, 8, 3, 10),
    );

    final shifted = recurrenceRuleForMovedFuture(
      base: base,
      occurrence: occurrence,
      targetDate: DateTime(2026, 8, 5),
    );

    expect(shifted.count, 4);
    expect(shifted.until, DateTime(2026, 8, 12));
    expect(shifted.excludedDates, [DateTime(2026, 8, 6)]);
  });
}

CalendarEvent _event({
  required DateTime start,
  required DateTime end,
  bool allDay = false,
  RecurrenceRule recurrence = const RecurrenceRule(),
}) {
  return CalendarEvent(
    id: 'move',
    title: '이동 일정',
    startAt: start,
    endAt: end,
    allDay: allDay,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    recurrence: recurrence,
    createdAt: start,
    updatedAt: start,
  );
}
