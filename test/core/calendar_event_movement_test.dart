import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
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

  test('weekday conditions rotate with a moved weekly series', () {
    const rule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      byDay: ['MO', 'WE'],
    );
    expect(shiftRecurrenceRuleByDays(rule, 0).byDay, ['MO', 'WE']);
    expect(shiftRecurrenceRuleByDays(rule, 1).byDay, ['TU', 'TH']);
    expect(shiftRecurrenceRuleByDays(rule, -1).byDay, ['SU', 'TU']);
  });

  test('month position conditions reset when the series moves', () {
    const rule = RecurrenceRule(
      frequency: RecurrenceFrequency.monthly,
      byDay: ['2TU'],
    );
    expect(shiftRecurrenceRuleByDays(rule, 0).byDay, ['2TU']);
    expect(shiftRecurrenceRuleByDays(rule, 1).hasDetails, isFalse);
  });

  test('future-series move counts real occurrences for weekday rules', () {
    final base = _event(
      start: DateTime(2026, 10, 5, 9),
      end: DateTime(2026, 10, 5, 10),
      recurrence: const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        count: 6,
        byDay: ['MO', 'WE'],
      ),
    );
    // Occurrences: 10/5, 10/7, 10/12, 10/14, 10/19, 10/21. From 10/12 on, 4 remain.
    final occurrence = base.copyWith(
      occurrenceId: 'move@2026-10-12T09:00:00.000',
      startAt: DateTime(2026, 10, 12, 9),
      endAt: DateTime(2026, 10, 12, 10),
    );
    final moved = recurrenceRuleForMovedFuture(
      base: base,
      occurrence: occurrence,
      targetDate: DateTime(2026, 10, 12),
    );
    expect(moved.count, 4);
    expect(moved.byDay, ['MO', 'WE']);
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

  test('격주 다중 요일 일정을 옮기면 모든 회차가 같은 일수만큼 옮겨진다 (#802)', () {
    final base = _event(
      start: DateTime(2026, 1, 5, 9),
      end: DateTime(2026, 1, 5, 10),
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        until: DateTime(2026, 3, 31),
        byDay: const ['MO', 'FR'],
        excludedDates: [DateTime(2026, 1, 19, 9)],
      ),
    ).copyWith(memo: '메모', completed: true);
    final moved = base.copyWith(
      startAt: DateTime(2026, 1, 8, 9),
      endAt: DateTime(2026, 1, 8, 10),
      recurrence: shiftRecurrenceRuleByDays(base.recurrence, 3),
    );
    expect(moved.recurrence.byDay, ['TH', 'MO']);
    expect(moved.recurrence.excludedDates, [DateTime(2026, 1, 22, 9)]);
    expect(moved.memo, '메모');
    expect(moved.completed, isTrue);

    final range = (DateTime(2026, 1, 1), DateTime(2026, 5, 1));
    final before = RecurrenceExpander().expand(base, range.$1, range.$2);
    final after = RecurrenceExpander().expand(moved, range.$1, range.$2);
    expect(before.map((e) => e.startAt).take(4), [
      DateTime(2026, 1, 5, 9),
      DateTime(2026, 1, 9, 9),
      DateTime(2026, 1, 23, 9),
      DateTime(2026, 2, 2, 9),
    ]);
    expect(after.last.startAt, DateTime(2026, 4, 2, 9));
    expect(
      after.map((e) => e.startAt),
      before.map((e) => e.startAt.add(const Duration(days: 3))),
    );
    for (final occurrence in after) {
      expect(occurrence.memo, '메모');
      expect(occurrence.completed, isTrue);
    }
  });

  test('시작 요일이 아닌 회차부터 이후 일정을 나눠도 이후 날짜가 그대로다 (#802)', () {
    final base = _event(
      start: DateTime(2026, 1, 5, 9),
      end: DateTime(2026, 1, 5, 10),
      recurrence: const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        count: 4,
        byDay: ['MO', 'FR'],
      ),
    );
    List<DateTime> starts(CalendarEvent event) => [
      for (final item in RecurrenceExpander().expand(
        event,
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 1),
      ))
        item.startAt,
    ];
    expect(starts(base), [
      DateTime(2026, 1, 5, 9),
      DateTime(2026, 1, 9, 9),
      DateTime(2026, 1, 19, 9),
      DateTime(2026, 1, 23, 9),
    ]);
    final friday = base.copyWith(
      startAt: DateTime(2026, 1, 9, 9),
      endAt: DateTime(2026, 1, 9, 10),
    );

    final kept = recurrenceRuleForMovedFuture(
      base: base,
      occurrence: friday,
      targetDate: DateTime(2026, 1, 9),
    );
    expect(kept.weekStart, DateTime.monday);
    expect(kept.count, 3);
    final restored = RecurrenceRule.withDetailsJson(
      const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        count: 3,
      ),
      kept.detailsJson,
    );
    expect(restored.weekStart, DateTime.monday);
    expect(starts(friday.copyWith(recurrence: restored)), [
      DateTime(2026, 1, 9, 9),
      DateTime(2026, 1, 19, 9),
      DateTime(2026, 1, 23, 9),
    ]);

    final moved = recurrenceRuleForMovedFuture(
      base: base,
      occurrence: friday,
      targetDate: DateTime(2026, 1, 10),
    );
    expect(moved.byDay, ['TU', 'SA']);
    expect(moved.weekStart, DateTime.tuesday);
    expect(
      starts(
        friday.copyWith(
          startAt: DateTime(2026, 1, 10, 9),
          endAt: DateTime(2026, 1, 10, 10),
          recurrence: moved,
        ),
      ),
      [
        DateTime(2026, 1, 10, 9),
        DateTime(2026, 1, 20, 9),
        DateTime(2026, 1, 24, 9),
      ],
    );

    // Splitting on the start weekday needs no stored week start, and a
    // whole-series move rotates a stored one with the dates.
    final monday = base.copyWith(
      startAt: DateTime(2026, 1, 19, 9),
      endAt: DateTime(2026, 1, 19, 10),
    );
    expect(
      recurrenceRuleForMovedFuture(
        base: base,
        occurrence: monday,
        targetDate: DateTime(2026, 1, 19),
      ).weekStart,
      isNull,
    );
    expect(shiftRecurrenceRuleByDays(kept, 3).weekStart, DateTime.thursday);
    expect(shiftRecurrenceRuleByDays(kept, -1).weekStart, DateTime.sunday);
  });

  group('구버전이 weekStart를 지워도 나눈 격주 반복 날짜가 그대로다 (#820)', () {
    // 4.1.0 rebuilds recurrenceDetails from the keys it knows, so it drops
    // weekStart; every other recurrence field survives its save.
    RecurrenceRule legacySave(RecurrenceRule rule) {
      final details = rule.detailsJson!.replaceAll(
        RegExp(r',?"weekStart":"[A-Z]{2}"'),
        '',
      );
      expect(details, isNot(contains('weekStart')));
      return RecurrenceRule.withDetailsJson(
        rule.copyWith(clearDetails: true),
        details,
      );
    }

    List<DateTime> starts(CalendarEvent event, DateTime from, DateTime to) => [
      for (final item in RecurrenceExpander().expand(event, from, to))
        item.startAt,
    ];

    CalendarEvent splitAndLegacySave(
      CalendarEvent base,
      DateTime occurrenceStart,
    ) {
      final occurrence = base.copyWith(
        startAt: occurrenceStart,
        endAt: occurrenceStart.add(base.endAt.difference(base.startAt)),
      );
      final kept = recurrenceRuleForMovedFuture(
        base: base,
        occurrence: occurrence,
        targetDate: occurrenceStart,
      );
      expect(kept.weekStart, isNotNull);
      final legacy = legacySave(kept);
      expect(legacy.weekStart, isNull);
      return occurrence.copyWith(title: '구버전에서 바꾼 제목', recurrence: legacy);
    }

    test('이슈 재현: 1/5 시작 격주 월·금을 1/9부터 나눔', () {
      final base = _event(
        start: DateTime(2026, 1, 5, 9),
        end: DateTime(2026, 1, 5, 10),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          count: 6,
          byDay: ['MO', 'FR'],
        ),
      );
      final split = splitAndLegacySave(base, DateTime(2026, 1, 9, 9));
      expect(starts(split, DateTime(2026, 1, 1), DateTime(2026, 6, 1)), [
        DateTime(2026, 1, 9, 9),
        DateTime(2026, 1, 19, 9),
        DateTime(2026, 1, 23, 9),
        DateTime(2026, 2, 2, 9),
        DateTime(2026, 2, 6, 9),
      ]);
      // A far query range skips ahead and still keeps the week boundary.
      final open = split.copyWith(
        recurrence: split.recurrence.copyWith(clearCount: true),
      );
      expect(starts(open, DateTime(2026, 3, 1), DateTime(2026, 3, 15)), [
        DateTime(2026, 3, 2, 9),
        DateTime(2026, 3, 6, 9),
      ]);
      // An older app moving the whole series shifts the exclusions with it.
      final moved = open.copyWith(
        startAt: DateTime(2026, 1, 10, 9),
        endAt: DateTime(2026, 1, 10, 10),
        recurrence: legacySave(shiftRecurrenceRuleByDays(open.recurrence, 1)),
      );
      expect(starts(moved, DateTime(2026, 1, 1), DateTime(2026, 1, 25)), [
        DateTime(2026, 1, 10, 9),
        DateTime(2026, 1, 20, 9),
        DateTime(2026, 1, 24, 9),
      ]);
    });

    test('횟수 있는 구버전 사본을 주 시작 요일 회차에서 다시 나눠도 남은 횟수가 맞다', () {
      final base = _event(
        start: DateTime(2026, 1, 5, 9),
        end: DateTime(2026, 1, 5, 10),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          count: 6,
          byDay: ['MO', 'FR'],
        ),
      );
      final legacy = splitAndLegacySave(base, DateTime(2026, 1, 9, 9));
      final monday = legacy.copyWith(
        startAt: DateTime(2026, 1, 19, 9),
        endAt: DateTime(2026, 1, 19, 10),
      );
      final again = recurrenceRuleForMovedFuture(
        base: legacy,
        occurrence: monday,
        targetDate: DateTime(2026, 1, 19),
      );
      expect(again.count, 4);
      expect(
        starts(
          monday.copyWith(recurrence: again),
          DateTime(2026, 1, 1),
          DateTime(2026, 3, 1),
        ),
        [
          DateTime(2026, 1, 19, 9),
          DateTime(2026, 1, 23, 9),
          DateTime(2026, 2, 2, 9),
          DateTime(2026, 2, 6, 9),
        ],
      );
    });

    test('월말: 1/29(목) 시작 격주 목·월을 2/2(월)부터 나눔', () {
      final base = _event(
        start: DateTime(2026, 1, 29, 9),
        end: DateTime(2026, 1, 29, 10),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          byDay: ['TH', 'MO'],
        ),
      );
      final split = splitAndLegacySave(base, DateTime(2026, 2, 2, 9));
      expect(starts(split, DateTime(2026, 1, 1), DateTime(2026, 3, 3)), [
        DateTime(2026, 2, 2, 9),
        DateTime(2026, 2, 12, 9),
        DateTime(2026, 2, 16, 9),
        DateTime(2026, 2, 26, 9),
        DateTime(2026, 3, 2, 9),
      ]);
    });

    // Run under a DST zone (e.g. TZ=America/New_York; US DST starts on
    // 2026-03-08) to cover the 23h day between the marker and later dates.
    test('서머타임: 3/2 시작 격주 월·금을 3/6부터 나눔', () {
      final base = _event(
        start: DateTime(2026, 3, 2, 9),
        end: DateTime(2026, 3, 2, 10),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          byDay: ['MO', 'FR'],
        ),
      );
      final split = splitAndLegacySave(base, DateTime(2026, 3, 6, 9));
      expect(starts(split, DateTime(2026, 3, 1), DateTime(2026, 4, 1)), [
        DateTime(2026, 3, 6, 9),
        DateTime(2026, 3, 16, 9),
        DateTime(2026, 3, 20, 9),
        DateTime(2026, 3, 30, 9),
      ]);
    });

    test('구버전 사본을 다시 나눠도 원래 주 경계를 이어 받는다', () {
      final base = _event(
        start: DateTime(2026, 1, 5, 9),
        end: DateTime(2026, 1, 5, 10),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          byDay: ['MO', 'FR'],
        ),
      );
      final legacy = splitAndLegacySave(base, DateTime(2026, 1, 9, 9));
      final again = splitAndLegacySave(legacy, DateTime(2026, 1, 23, 9));
      expect(starts(again, DateTime(2026, 1, 1), DateTime(2026, 2, 10)), [
        DateTime(2026, 1, 23, 9),
        DateTime(2026, 2, 2, 9),
        DateTime(2026, 2, 6, 9),
      ]);
    });
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
