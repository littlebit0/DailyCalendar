// Calendar-date expectations that hold in every time zone. They only catch a
// regression when run under a daylight-saving zone, e.g.
// `TZ=America/New_York flutter test` (2026: starts 03-08, ends 11-01) (#858).
import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/local_notification_service.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  final expander = RecurrenceExpander();

  test('an all-day weekly occurrence on the 23-hour day ends at midnight', () {
    final event = _event(
      start: DateTime(2026, 3, 1),
      end: DateTime(2026, 3, 2),
      allDay: true,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
    );
    final occurrence = expander
        .expand(event, DateTime(2026, 3, 8), DateTime(2026, 3, 9))
        .single;
    expect(occurrence.startAt, DateTime(2026, 3, 8));
    expect(occurrence.endAt, DateTime(2026, 3, 9));
    // Nothing of it reaches into the next day.
    expect(
      expander.expand(event, DateTime(2026, 3, 9), DateTime(2026, 3, 10)),
      isEmpty,
    );
  });

  test('a detailed all-day rule also ends its occurrences at midnight', () {
    final event = _event(
      start: DateTime(2026, 3, 1),
      end: DateTime(2026, 3, 2),
      allDay: true,
      recurrence: const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        byDay: ['SU'],
      ),
    );
    final occurrence = expander
        .expand(event, DateTime(2026, 3, 8), DateTime(2026, 3, 9))
        .single;
    expect(occurrence.endAt, DateTime(2026, 3, 9));
  });

  test('the last planned end of an all-day series is a midnight', () {
    final event = _event(
      start: DateTime(2026, 10, 30),
      end: DateTime(2026, 10, 31),
      allDay: true,
      recurrence: const RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        count: 4,
      ),
    );
    expect(expander.lastPlannedEnd(event), DateTime(2026, 11, 3));
  });

  test('a three-day all-day event keeps three days across the 25-hour day', () {
    final event = _event(
      start: DateTime(2026, 10, 20),
      end: DateTime(2026, 10, 23),
      allDay: true,
    );
    final moved = shiftCalendarEventToDate(
      event,
      DateTime(2026, 10, 31),
    ).normalizeAllDayBounds();
    expect(moved.startAt, DateTime(2026, 10, 31));
    expect(moved.endAt, DateTime(2026, 11, 3));
  });

  test('a timed event keeps its elapsed length when moved', () {
    final event = _event(
      start: DateTime(2026, 10, 20, 22),
      end: DateTime(2026, 10, 21, 1),
    );
    final moved = shiftCalendarEventToDate(event, DateTime(2026, 10, 31));
    expect(moved.startAt, DateTime(2026, 10, 31, 22));
    expect(moved.endAt.difference(moved.startAt), const Duration(hours: 3));
  });

  test('D-day and briefing times keep the wall clock across a change', () {
    // D-7 of an event on 03-10, and the days after 10-30.
    expect(
      wallClockOnDay(DateTime(2026, 3, 10), -7, 9, 0),
      DateTime(2026, 3, 3, 9),
    );
    expect(
      wallClockOnDay(DateTime(2026, 3, 3, 15), 7, 9, 0),
      DateTime(2026, 3, 10, 9),
    );
    for (var day = 0; day < 14; day++) {
      final at = wallClockOnDay(DateTime(2026, 10, 30, 7, 30), day, 7, 30);
      expect((at.hour, at.minute), (7, 30));
      expect(at.day, DateTime(2026, 10, 30 + day).day);
    }
  });

  testWidgets('"this and following" delete ends the series the day before', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final base = _event(
      start: DateTime(2026, 3, 2, 10),
      end: DateTime(2026, 3, 2, 11),
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
    );
    // The occurrence on the day after the 23-hour day.
    final shown = base.copyWith(
      occurrenceId: '${base.id}@2026-03-09',
      startAt: DateTime(2026, 3, 9, 10),
      endAt: DateTime(2026, 3, 9, 11),
    );
    final repository = _Repository(base, shown);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          eventRepositoryProvider.overrideWithValue(repository),
          eventCommandServiceProvider.overrideWithValue(
            EventCommandService(
              repository: repository,
              settingsRepository: settings,
              notificationService: _Notifications(),
              syncService: _Sync(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EventDetailsPanel(date: shown.startAt, events: [shown]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('event-delete-${base.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이후 일정'));
    await tester.pumpAndSettle();

    expect(repository.stored.recurrence.until, DateTime(2026, 3, 8));
  });
}

CalendarEvent _event({
  required DateTime start,
  required DateTime end,
  bool allDay = false,
  RecurrenceRule recurrence = const RecurrenceRule(),
}) => CalendarEvent(
  id: 'dst-event',
  title: '서머타임 일정',
  startAt: start,
  endAt: end,
  allDay: allDay,
  category: EventCategory.basic,
  colorValue: EventCategory.basic.colorValue,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  recurrence: recurrence,
);

/// Stores one series and shows one expanded occurrence of it.
class _Repository extends Fake implements EventRepository {
  _Repository(this.stored, this.shown);

  CalendarEvent stored;
  final CalendarEvent shown;

  @override
  Future<CalendarEvent?> findById(String id) async => stored;

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => [shown];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value([shown]);

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => [stored];

  @override
  Future<void> save(CalendarEvent event) async => stored = event;
}

class _Sync implements SyncService {
  @override
  Future<void> start() async {}
  @override
  Future<void> queueEventDelete(String id) async {}
  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {}
  @override
  Future<void> queueSettingsBackup() async {}
}

class _Notifications implements NotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {}
  @override
  Future<void> cancelEventReminder(
    String id, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {}
  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
  @override
  Future<void> cancelMorningBriefing() async {}
  @override
  Future<int> pendingNotificationCount() async => 0;
  @override
  Future<String> permissionSummary() async => 'test';
}
