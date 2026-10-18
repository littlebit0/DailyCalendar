import 'package:daily/core/notifications/reminder_delivery_plan.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schedules the requested reminder time when it is still in the future',
    () {
      final now = DateTime(2026, 5, 29, 9);
      final reminderAt = now.add(const Duration(minutes: 10));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: now.add(const Duration(hours: 1)),
        eventEndAt: now.add(const Duration(hours: 2)),
        now: now,
        allowImmediate: true,
      );

      expect(plan.type, ReminderDeliveryType.scheduled);
      expect(plan.deliverAt, reminderAt);
    },
  );

  test(
    'immediately delivers a newly saved ongoing event whose reminder is late',
    () {
      final now = DateTime(2026, 5, 29, 9, 10);
      final reminderAt = now.subtract(const Duration(minutes: 10));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: now.subtract(const Duration(minutes: 10)),
        eventEndAt: now.add(const Duration(hours: 1)),
        now: now,
        allowImmediate: true,
      );

      expect(plan.type, ReminderDeliveryType.immediate);
      expect(plan.deliverAt, reminderAt);
    },
  );

  test(
    'immediately delivers when a new event is inside an already missed reminder window',
    () {
      final now = DateTime(2026, 5, 29, 9, 55);
      final startsAt = DateTime(2026, 5, 29, 10);
      final reminderAt = startsAt.subtract(const Duration(hours: 1));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: startsAt,
        eventEndAt: startsAt.add(const Duration(hours: 1)),
        now: now,
        allowImmediate: true,
      );

      expect(plan.type, ReminderDeliveryType.immediate);
      expect(plan.deliverAt, reminderAt);
    },
  );

  test(
    'startup reschedule falls back to event start without immediate spam',
    () {
      final now = DateTime(2026, 5, 29, 9, 55);
      final startsAt = DateTime(2026, 5, 29, 10);
      final reminderAt = startsAt.subtract(const Duration(hours: 1));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: startsAt,
        eventEndAt: startsAt.add(const Duration(hours: 1)),
        now: now,
        allowImmediate: false,
      );

      expect(plan.type, ReminderDeliveryType.scheduled);
      expect(plan.deliverAt, startsAt);
    },
  );

  test('startup reschedule does not re-emit a just-fired reminder', () {
    final now = DateTime(2026, 5, 29, 10, 1);
    final startsAt = DateTime(2026, 5, 29, 10);

    final plan = resolveReminderDeliveryPlan(
      reminderAt: startsAt,
      fallbackAt: startsAt,
      eventEndAt: startsAt.add(const Duration(hours: 1)),
      now: now,
      allowImmediate: false,
    );

    expect(plan.type, ReminderDeliveryType.none);
    expect(plan.deliverAt, isNull);
  });

  test('skips ended events whose reminder and fallback are both stale', () {
    final now = DateTime(2026, 5, 29, 12);

    final plan = resolveReminderDeliveryPlan(
      reminderAt: now.subtract(const Duration(hours: 3)),
      fallbackAt: now.subtract(const Duration(hours: 2)),
      eventEndAt: now.subtract(const Duration(hours: 1)),
      now: now,
      allowImmediate: true,
    );

    expect(plan.type, ReminderDeliveryType.none);
    expect(plan.deliverAt, isNull);
  });

  group('planRecurringReminders', () {
    CalendarEvent repeating(
      DateTime start,
      RecurrenceRule rule, {
      bool allDay = false,
      Duration length = const Duration(hours: 1),
    }) => CalendarEvent(
      id: 'series',
      title: '반복',
      startAt: start,
      endAt: start.add(length),
      allDay: allDay,
      category: EventCategory.basic,
      colorValue: 1,
      createdAt: start,
      updatedAt: start,
      recurrence: rule,
    );

    List<RecurringReminderRequest> plan(
      CalendarEvent event, {
      int minutes = 10,
      required DateTime now,
      bool immediate = false,
    }) => planRecurringReminders(
      event: event,
      reminderMinutes: minutes,
      baseTime: (occurrence) => occurrence.startAt,
      now: now,
      allowImmediate: immediate,
    );

    test('daily series with a count schedules every later occurrence', () {
      final event = repeating(
        DateTime(2026, 10, 14, 9),
        const RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 3),
      );
      final requests = plan(event, now: DateTime(2026, 10, 14, 8));
      expect(requests.map((r) => r.plan.deliverAt), [
        DateTime(2026, 10, 14, 8, 50),
        DateTime(2026, 10, 15, 8, 50),
        DateTime(2026, 10, 16, 8, 50),
      ]);
      expect(requests.map((r) => r.slot), [0, 1, 2]);
    });

    test(
      'a series that started long ago still reminds its next occurrences',
      () {
        final event = repeating(
          DateTime(2026, 9, 1, 9),
          const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
        );
        final requests = plan(event, now: DateTime(2026, 10, 14, 12));
        expect(requests, hasLength(recurringReminderSlotsPerOffset));
        expect(requests.first.plan.deliverAt, DateTime(2026, 10, 20, 8, 50));
        expect(requests[1].plan.deliverAt, DateTime(2026, 10, 27, 8, 50));
      },
    );

    test('request times match the occurrences the calendar shows', () {
      final now = DateTime(2026, 10, 14, 12);
      for (final rule in [
        const RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: 3),
        const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
        const RecurrenceRule(frequency: RecurrenceFrequency.monthly),
        const RecurrenceRule(frequency: RecurrenceFrequency.yearly),
      ]) {
        final event = repeating(DateTime(2026, 9, 8, 9), rule);
        final shown = RecurrenceExpander()
            .expand(event, now, now.add(const Duration(days: 800)))
            .map((o) => o.startAt)
            .take(recurringReminderSlotsPerOffset);
        final requests = plan(event, now: now);
        expect(
          requests.map((r) => r.occurrence.startAt),
          shown,
          reason: rule.frequency.name,
        );
        expect(
          requests.map((r) => r.plan.deliverAt),
          shown.map((s) => s.subtract(const Duration(minutes: 10))),
        );
      }
    });

    test(
      'a first occurrence beyond the usual horizon still gets its reminder',
      () {
        final event = repeating(
          DateTime(2029, 1, 1, 9),
          const RecurrenceRule(frequency: RecurrenceFrequency.yearly),
        );
        final requests = plan(event, now: DateTime(2026, 10, 18));
        expect(requests.first.plan.deliverAt, DateTime(2029, 1, 1, 8, 50));
        final triennial = repeating(
          DateTime(2020, 5, 1, 9),
          const RecurrenceRule(
            frequency: RecurrenceFrequency.yearly,
            interval: 3,
          ),
        );
        expect(
          plan(triennial, now: DateTime(2026, 10, 18)).first.occurrence.startAt,
          DateTime(2029, 5, 1, 9),
        );
      },
    );

    test('zero slots plan nothing', () {
      final event = repeating(
        DateTime(2026, 10, 14, 9),
        const RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      expect(
        planRecurringReminders(
          event: event,
          reminderMinutes: 10,
          baseTime: (o) => o.startAt,
          now: DateTime(2026, 10, 14, 8),
          allowImmediate: false,
          slots: 0,
        ),
        isEmpty,
      );
    });

    test('excluded dates and ended series produce no requests', () {
      final event = repeating(
        DateTime(2026, 10, 14, 9),
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2026, 10, 17),
          excludedDates: [DateTime(2026, 10, 15)],
        ),
      );
      final requests = plan(event, now: DateTime(2026, 10, 14, 8));
      expect(requests.map((r) => r.occurrence.startAt.day), [14, 16, 17]);
      expect(plan(event, now: DateTime(2026, 10, 18)), isEmpty);
    });

    test(
      'an occurrence in progress is delivered immediately only when allowed',
      () {
        final event = repeating(
          DateTime(2026, 10, 14, 9),
          const RecurrenceRule(frequency: RecurrenceFrequency.daily),
          length: const Duration(hours: 2),
        );
        final now = DateTime(2026, 10, 15, 9, 30);
        expect(
          plan(event, now: now).first.plan.type,
          ReminderDeliveryType.scheduled,
        );
        final immediate = plan(event, now: now, immediate: true);
        expect(immediate.first.plan.type, ReminderDeliveryType.immediate);
        expect(immediate[1].plan.type, ReminderDeliveryType.scheduled);
      },
    );
  });
}
