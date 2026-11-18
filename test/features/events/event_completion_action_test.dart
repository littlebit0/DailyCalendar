import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:daily/features/events/presentation/event_completion_action.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final start = DateTime(2026, 11, 16, 9);
  CalendarEvent event({RecurrenceRule recurrence = const RecurrenceRule()}) =>
      CalendarEvent(
        id: 'searched',
        title: '검색한 일정',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: start,
        updatedAt: start,
        recurrence: recurrence,
      );

  /// Double-taps [shown] the way a search result row does; returns the stored
  /// events afterwards.
  Future<List<CalendarEvent>> doubleTap(
    WidgetTester tester, {
    required CalendarEvent stored,
    required CalendarEvent shown,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftEventRepository(database);
    await tester.runAsync(() => repository.save(stored));
    VoidCallback? toggle;
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
            body: EventCompletionAction(
              event: shown,
              builder: (onDoubleTap) {
                toggle = onDoubleTap;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    toggle!();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final events = await tester.runAsync(repository.allEventsForSync);
    await tester.pumpWidget(const SizedBox.shrink());
    return events!;
  }

  testWidgets('a searched repeating series is not completed as a whole', (
    tester,
  ) async {
    final series = event(
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
    );
    // Search returns the stored row: no occurrenceId.
    final events = await doubleTap(tester, stored: series, shown: series);
    expect(events.single.completed, isFalse);
    expect(events.single.recurrence.excludedDates, isEmpty);
    expect(events.single.syncStatus, series.syncStatus);
  });

  testWidgets('a searched single event is still completed', (tester) async {
    final single = event();
    final events = await doubleTap(tester, stored: single, shown: single);
    expect(events.single.completed, isTrue);
  });

  testWidgets('an expanded occurrence still completes only itself', (
    tester,
  ) async {
    final series = event(
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
    );
    final next = start.add(const Duration(days: 7));
    final events = await doubleTap(
      tester,
      stored: series,
      shown: series.copyWith(
        occurrenceId: '${series.id}@${next.toIso8601String()}',
        startAt: next,
        endAt: next.add(const Duration(hours: 1)),
      ),
    );
    expect(events, hasLength(2));
    final stored = events.singleWhere((e) => e.id == series.id);
    expect(stored.completed, isFalse);
    expect(events.singleWhere((e) => e.id != series.id).completed, isTrue);
  });
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
