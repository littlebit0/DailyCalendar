import 'dart:convert';
import 'dart:io';
import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:drift/native.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime fixtureDate(String value) => DateTime.parse('${value}T09:00:00');

void main() {
  final cases =
      jsonDecode(
            File(
              'test/fixtures/recurrence_anchor_cases.json',
            ).readAsStringSync(),
          )
          as List;
  for (final item in cases) {
    test('shared anchor fixture ${item['name']}', () async {
      final start = fixtureDate(item['start']);
      final event = CalendarEvent(
        id: item['name'],
        title: 'anchor',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: 1,
        createdAt: start,
        updatedAt: start,
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.values.byName(item['frequency']),
          interval: item['interval'],
          count: item['count'],
          anchorDay: item['anchorDay'],
          until: item['until'] == null ? null : fixtureDate(item['until']),
          excludedDates: [
            for (final d in item['excluded'] ?? []) fixtureDate(d),
          ],
        ),
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftEventRepository(db);
      try {
        await repository.save(event);
        final restored = (await repository.findById(event.id))!;
        expect(restored.recurrence.anchorDay, event.recurrence.anchorDay);
        final actual = RecurrenceExpander().expand(
          restored,
          fixtureDate(
            item['rangeStart'] ?? item['start'],
          ).subtract(const Duration(hours: 9)),
          fixtureDate(item['rangeEnd'] ?? '2030-01-01'),
        );
        expect(
          actual.map((e) => e.startAt.toIso8601String().substring(0, 10)),
          item['expected'],
        );
        if (item['rangeStart'] == null) {
          expect(
            RecurrenceExpander().lastPlannedEnd(restored),
            actual.last.endAt,
          );
          if (item['until'] == null) {
            expect(
              RecurrenceExpander().lastCountedEnd(restored),
              actual.last.endAt,
            );
          }
        }
        if (item['name'] == 'jan31') {
          final split = recurrenceRuleForMovedFuture(
            base: restored,
            occurrence: actual[1],
            targetDate: actual[1].startAt,
          );
          expect(split.anchorDay, 31);
          expect(
            RecurrenceExpander()
                .expand(
                  actual[1].copyWith(recurrence: split),
                  fixtureDate('2025-02-01'),
                  fixtureDate('2025-05-01'),
                )
                .map((e) => e.startAt.day),
            [28, 31],
          );
        }
      } finally {
        await db.close();
      }
    });
  }

  test('expands weekly events inside the visible range', () {
    final event = CalendarEvent(
      id: 'event-1',
      title: '운동',
      startAt: DateTime(2026, 5, 4, 19),
      endAt: DateTime(2026, 5, 4, 20),
      allDay: false,
      category: EventCategory.health,
      colorValue: EventCategory.health.colorValue,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

    final occurrences = RecurrenceExpander().expand(
      event,
      DateTime(2026, 5, 1),
      DateTime(2026, 6, 1),
    );

    expect(occurrences.map((event) => event.startAt.day), [4, 11, 18, 25]);
  });

  test('fast-forwards an old daily recurrence to the visible range', () {
    final event = CalendarEvent(
      id: 'old-daily',
      title: '매일 기록',
      startAt: DateTime(2000, 1, 1, 9),
      endAt: DateTime(2000, 1, 1, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
      createdAt: DateTime(2000, 1, 1),
      updatedAt: DateTime(2000, 1, 1),
    );

    final occurrences = RecurrenceExpander().expand(
      event,
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 4),
    );

    expect(occurrences.map((occurrence) => occurrence.startAt), [
      DateTime(2026, 7, 1, 9),
      DateTime(2026, 7, 2, 9),
      DateTime(2026, 7, 3, 9),
    ]);
  });

  test('fast-forward preserves recurrence count semantics', () {
    final event = CalendarEvent(
      id: 'finished-daily',
      title: '완료된 반복',
      startAt: DateTime(2000, 1, 1, 9),
      endAt: DateTime(2000, 1, 1, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      recurrence: const RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        count: 30,
      ),
      createdAt: DateTime(2000, 1, 1),
      updatedAt: DateTime(2000, 1, 1),
    );

    final occurrences = RecurrenceExpander().expand(
      event,
      DateTime(2026, 7, 1),
      DateTime(2026, 8, 1),
    );

    expect(occurrences, isEmpty);
  });

  test('includes the until date for timed daily recurrences', () {
    final occurrences = RecurrenceExpander().expand(
      _recurringEvent(
        startAt: DateTime(2026, 8, 24, 9),
        endAt: DateTime(2026, 8, 24, 10),
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2026, 8, 26),
        ),
      ),
      DateTime(2026, 8, 1),
      DateTime(2026, 9, 1),
    );

    expect(occurrences.map((event) => event.startAt.day), [24, 25, 26]);
  });

  test('includes the until date for all-day daily recurrences', () {
    final occurrences = RecurrenceExpander().expand(
      _recurringEvent(
        startAt: DateTime(2026, 8, 24),
        endAt: DateTime(2026, 8, 25),
        allDay: true,
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2026, 8, 26),
        ),
      ),
      DateTime(2026, 8, 1),
      DateTime(2026, 9, 1),
    );

    expect(occurrences.map((event) => event.startAt.day), [24, 25, 26]);
  });

  test('includes the until date across a year boundary and stops after it', () {
    final occurrences = RecurrenceExpander().expand(
      _recurringEvent(
        startAt: DateTime(2026, 12, 30, 23, 30),
        endAt: DateTime(2026, 12, 31, 0, 30),
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2027, 1, 1),
        ),
      ),
      DateTime(2026, 12, 1),
      DateTime(2027, 2, 1),
    );

    expect(occurrences.map((event) => event.startAt), [
      DateTime(2026, 12, 30, 23, 30),
      DateTime(2026, 12, 31, 23, 30),
      DateTime(2027, 1, 1, 23, 30),
    ]);
  });

  test(
    'includes matching until dates for every supported recurrence period',
    () {
      final cases =
          <
            ({
              RecurrenceFrequency frequency,
              DateTime start,
              DateTime until,
              List<DateTime> expected,
            })
          >[
            (
              frequency: RecurrenceFrequency.weekly,
              start: DateTime(2026, 8, 12, 9),
              until: DateTime(2026, 8, 26),
              expected: [
                DateTime(2026, 8, 12, 9),
                DateTime(2026, 8, 19, 9),
                DateTime(2026, 8, 26, 9),
              ],
            ),
            (
              frequency: RecurrenceFrequency.monthly,
              start: DateTime(2026, 10, 26, 9),
              until: DateTime(2027, 1, 26),
              expected: [
                DateTime(2026, 10, 26, 9),
                DateTime(2026, 11, 26, 9),
                DateTime(2026, 12, 26, 9),
                DateTime(2027, 1, 26, 9),
              ],
            ),
            (
              frequency: RecurrenceFrequency.yearly,
              start: DateTime(2024, 8, 26, 9),
              until: DateTime(2026, 8, 26),
              expected: [
                DateTime(2024, 8, 26, 9),
                DateTime(2025, 8, 26, 9),
                DateTime(2026, 8, 26, 9),
              ],
            ),
          ];

      for (final testCase in cases) {
        final occurrences = RecurrenceExpander().expand(
          _recurringEvent(
            startAt: testCase.start,
            endAt: testCase.start.add(const Duration(hours: 1)),
            recurrence: RecurrenceRule(
              frequency: testCase.frequency,
              until: testCase.until,
            ),
          ),
          DateTime(2024),
          DateTime(2028),
        );

        expect(
          occurrences.map((event) => event.startAt),
          testCase.expected,
          reason: testCase.frequency.name,
        );
      }
    },
  );

  group('daily and weekly repeats keep the local start time', () {
    // Run under a DST zone (e.g. TZ=America/New_York) to cover clock changes;
    // in zones without DST these still guard the plain wall-clock contract.
    for (final frequency in [
      RecurrenceFrequency.daily,
      RecurrenceFrequency.weekly,
    ]) {
      test('${frequency.name} occurrences, fast-forward and count agree', () {
        final start = DateTime(2026, 10, 25, 9, 30);
        final event = _recurringEvent(
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
          recurrence: RecurrenceRule(frequency: frequency, count: 40),
        );
        final expander = RecurrenceExpander();
        final all = expander.expand(
          event,
          DateTime(2026, 10, 1),
          DateTime(2028, 1, 1),
        );
        expect(all, hasLength(40));
        final step = frequency == RecurrenceFrequency.daily ? 1 : 7;
        for (var i = 0; i < all.length; i++) {
          expect(
            all[i].startAt,
            DateTime(2026, 10, 25 + step * i, 9, 30),
            reason: 'occurrence $i',
          );
        }
        // A far-away range uses the fast-forward path and must match the
        // occurrences generated from the first one.
        final open = event.copyWith(
          recurrence: RecurrenceRule(frequency: frequency),
        );
        final everything = expander.expand(
          open,
          DateTime(2026, 10, 1),
          DateTime(2027, 4, 1),
        );
        final late = expander.expand(
          open,
          DateTime(2027, 3, 1),
          DateTime(2027, 3, 20),
        );
        expect(late, isNotEmpty);
        for (final occurrence in late) {
          expect(occurrence.startAt.hour, 9);
          expect(occurrence.startAt.minute, 30);
          expect(
            everything.map((e) => e.startAt),
            contains(occurrence.startAt),
          );
        }
        expect(
          expander.lastCountedEnd(event).hour,
          10,
          reason: 'count-based last end keeps the local hour',
        );
      });
    }
  });
}

CalendarEvent _recurringEvent({
  required DateTime startAt,
  required DateTime endAt,
  required RecurrenceRule recurrence,
  bool allDay = false,
}) {
  return CalendarEvent(
    id: 'recurrence-${recurrence.frequency.name}-${startAt.toIso8601String()}',
    title: '반복 일정',
    startAt: startAt,
    endAt: endAt,
    allDay: allDay,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    recurrence: recurrence,
    createdAt: startAt,
    updatedAt: startAt,
  );
}
