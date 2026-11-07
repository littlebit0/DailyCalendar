import 'dart:async';

import 'package:daily/core/notifications/local_notification_service.dart';
import 'package:daily/core/notifications/reminder_delivery_plan.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves a fixed event list and counts full-list reads.
class _CountingRepository implements EventRepository {
  _CountingRepository(this.events);

  final List<CalendarEvent> events;
  var reads = 0;
  var failNextRead = false;

  @override
  Future<List<CalendarEvent>> allEventsForSync() async {
    reads++;
    if (failNextRead) {
      failNextRead = false;
      throw StateError('read failed');
    }
    return events;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _anchor = DateTime.now();

DateTime _day(int offset, [int hour = 10]) =>
    DateTime(_anchor.year, _anchor.month, _anchor.day + offset, hour);

const _rules = [
  RecurrenceRule(frequency: RecurrenceFrequency.daily),
  RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: 3),
  RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 5),
  RecurrenceRule(frequency: RecurrenceFrequency.weekly),
  RecurrenceRule(frequency: RecurrenceFrequency.weekly, byDay: ['MO', 'TH']),
  RecurrenceRule(frequency: RecurrenceFrequency.monthly, anchorDay: 31),
  RecurrenceRule(frequency: RecurrenceFrequency.monthly, byDay: ['-1FR']),
  RecurrenceRule(frequency: RecurrenceFrequency.yearly),
  RecurrenceRule(frequency: RecurrenceFrequency.yearly, interval: 4),
];

RecurrenceRule _rule(int i) {
  final rule = _rules[i % _rules.length];
  return switch (i % 3) {
    1 => RecurrenceRule(
      frequency: rule.frequency,
      interval: rule.interval,
      count: rule.count,
      anchorDay: rule.anchorDay,
      byDay: rule.byDay,
      until: _day(40 + i),
      excludedDates: [_day(1), _day(2), _day(9)],
    ),
    _ => rule,
  };
}

/// A mix of repeating (every rule kind, some with until/exclusions, some
/// started in the past), single-shot, all-day, D-day and skipped events.
List<CalendarEvent> _events(int n) => [
  for (var i = 0; i < n; i++)
    () {
      final repeating = i % 4 != 3;
      final start = _day((i % 7) - 3 + (repeating ? 0 : 5), 9 + i % 8);
      return CalendarEvent(
        id: 'event-$i',
        title: 'event $i',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: i % 5 == 0,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: start,
        updatedAt: start,
        // Single-shot and D-day requests are never trimmed to the iOS limit,
        // so keep them at most 53 for any run date; repeating events fill the
        // remaining room and are trimmed.
        reminderMinutesBeforeList: i % 2 == 0
            ? [10]
            : (repeating || i < 40 ? [0, 60] : [0]),
        showDday: i % 6 == 0 && i < 36,
        completed: i % 17 == 16,
        recurrence: repeating ? _rule(i) : const RecurrenceRule(),
      );
    }(),
];

class _Run {
  _Run(this.pending, this.reads, this.occurrences, this.cancels);

  final Map<int, Map<Object?, Object?>> pending;
  final int reads;
  final int occurrences;
  final int cancels;
}

Future<_Run> _reconcile(
  List<CalendarEvent> events, {
  required bool shared,
  int limit = 64,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsRepository(
    preferences: await SharedPreferences.getInstance(),
  );
  final pending = <int, Map<Object?, Object?>>{};
  var cancels = 0;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('daily/native_notifications'),
        (call) async {
          if (call.method == 'initialize') return true;
          final args = call.arguments as Map;
          if (call.method == 'schedule') pending[args['id'] as int] = args;
          if (call.method == 'cancel' || call.method == 'cancelPending') {
            cancels++;
            pending.remove(args['id']);
          }
          return null;
        },
      );
  final repository = _CountingRepository(events);
  final service = LocalNotificationService(
    settingsRepository: settings,
    eventRepository: repository,
    pendingRequestLimit: limit,
  )..shareReconciliationSnapshot = shared;
  await service.initialize();
  debugRecurringReminderOccurrences = 0;
  // Same steps as the app-start reconciliation in daily_app.dart.
  await runNotificationReconciliation(() async {
    for (final event in events) {
      await service.cancelEventReminder(
        event.id,
        reminderMinutesBeforeList: event.reminderMinutesBeforeList,
      );
      await service.scheduleEventReminder(event);
    }
  });
  return _Run(
    pending,
    repository.reads,
    debugRecurringReminderOccurrences,
    cancels,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('daily/native_notifications'),
          null,
        );
  });

  test('probing short windows plans the same reminders as the full search', () {
    for (var i = 0; i < 60; i++) {
      final event = _events(60)[i];
      if (!event.recurrence.isRepeating) continue;
      for (final now in [_anchor, _day(-20), _day(30, 23), _day(400)]) {
        for (final slots in [0, 1, 3, recurringReminderSlotsPerOffset]) {
          for (final immediate in [false, true]) {
            List<String> plan(List<int> probeDays) => [
              for (final r in planRecurringReminders(
                event: event,
                reminderMinutes: 30,
                baseTime: (o) => o.allDay ? _day(0, 9) : o.startAt,
                now: now,
                allowImmediate: immediate,
                slots: slots,
                probeDays: probeDays,
              ))
                '${r.slot} ${r.occurrence.startAt} ${r.base} '
                    '${r.plan.type} ${r.plan.deliverAt}',
            ];
            expect(
              plan(recurringReminderProbeDays),
              plan(const []),
              reason: '${event.id} now=$now slots=$slots',
            );
          }
        }
      }
    }
  });

  for (final n in [10, 100]) {
    test(
      'batch reconciliation of $n events schedules the same requests',
      () async {
        final events = _events(n);
        // Every reminder and due-grace boundary is a whole minute and both
        // runs read the real clock, so run them inside the same minute.
        final second = DateTime.now().second;
        if (second >= 40) {
          await Future<void>.delayed(Duration(seconds: 61 - second));
        }
        final before = await _reconcile(events, shared: false);
        final after = await _reconcile(events, shared: true);

        // Same ids, times, titles, bodies and payloads within the iOS limit.
        expect(after.pending, before.pending);
        expect(after.pending.length, lessThanOrEqualTo(64));
        expect(after.pending, isNotEmpty);

        // One event list read and one allowance plan for the whole batch.
        expect(after.reads, 1);
        expect(before.reads, greaterThanOrEqualTo(2 * events.length));
        expect(after.occurrences, lessThan(before.occurrences ~/ n));
        expect(after.cancels, lessThanOrEqualTo(before.cancels));
        debugPrint(
          'N=$n reads ${before.reads}->${after.reads}, '
          'occurrences ${before.occurrences}->${after.occurrences}, '
          'OS cancels ${before.cancels}->${after.cancels}',
        );
      },
    );
  }

  test(
    'a call from outside the batch makes the batch re-read events',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsRepository(preferences: preferences);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('daily/native_notifications'),
            (call) async => call.method == 'initialize' ? true : null,
          );
      final events = _events(4);
      final repository = _CountingRepository(events);
      final service = LocalNotificationService(
        settingsRepository: settings,
        eventRepository: repository,
        pendingRequestLimit: 64,
      );
      await runNotificationReconciliation(() async {
        await service.scheduleEventReminder(events[0]);
        await service.scheduleEventReminder(events[1]);
        expect(repository.reads, 1);
        // An edit outside the batch (another zone) reads the latest events.
        await Future(() {}).then(
          (_) => Zone.root.run(() => service.scheduleEventReminder(events[2])),
        );
        expect(repository.reads, 2);
        // ...and invalidates the batch snapshot, so its next step re-reads too.
        await service.scheduleEventReminder(events[3]);
        expect(repository.reads, 3);
        // A changed reminder setting also takes a fresh snapshot.
        await preferences.setInt('allDayReminderHour', 7);
        await service.scheduleEventReminder(events[0]);
        expect(repository.reads, 4);
      });
      // A failed read is not cached: the retry in a new batch reads again.
      repository.failNextRead = true;
      await expectLater(
        runNotificationReconciliation(
          () => service.scheduleEventReminder(events[1]),
        ),
        throwsStateError,
      );
      await runNotificationReconciliation(
        () => service.scheduleEventReminder(events[1]),
      );
      expect(repository.reads, 6);
    },
  );
}
