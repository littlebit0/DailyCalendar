import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/calendar/widgets/calendar_event_drag_layer.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ko'));

  testWidgets('event detail shows all fields and actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final event = _event();
    final repository = await _pumpPanel(tester, event: event);

    await tester.tap(find.text('비밀 회의').first);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('event-detail-todo-meeting-event')),
      findsOneWidget,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(repository.event.completed, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    expect(find.text('시간'), findsOneWidget);
    expect(find.text('장소'), findsOneWidget);
    expect(find.text('서울시청'), findsWidgets);
    expect(find.text('지도 바로가기'), findsWidgets);
    expect(find.text('URI'), findsOneWidget);
    expect(find.text('https://example.com/meeting'), findsWidgets);
    expect(find.text('날씨'), findsOneWidget);
    expect(find.text('맑음'), findsWidgets);
    expect(find.text('메모'), findsOneWidget);
    expect(find.text('준비물 확인'), findsWidgets);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('event card and action boxes respond across their full bounds', (
    tester,
  ) async {
    final event = _event();
    await _pumpPanel(tester, event: event);

    final openArea = find.byKey(ValueKey('event-open-${event.id}'));
    for (final point in _insetCorners(tester.getRect(openArea))) {
      await tester.tapAt(point);
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      expect(find.text('시간'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    final editArea = find.byKey(ValueKey('event-edit-${event.id}'));
    for (final point in _insetCorners(tester.getRect(editArea))) {
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.byType(EventEditorDialog), findsOneWidget);
      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();
    }

    final deleteArea = find.byKey(ValueKey('event-delete-${event.id}'));
    for (final point in _insetCorners(tester.getRect(deleteArea))) {
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.text('일정 삭제'), findsOneWidget);
      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('repeating delete uses the delete-specific all scope label', (
    tester,
  ) async {
    final event = _event().copyWith(
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
    );
    await _pumpPanel(tester, event: event);

    await tester.tap(find.byKey(ValueKey('event-delete-${event.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(find.text('전체 삭제'), findsOneWidget);
    expect(find.text('전체 반복'), findsNothing);
  });

  testWidgets(
    'long press keeps the day panel visible and exposes an order target',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final event = _event();
      DateTime? droppedDate;
      int? droppedIndex;
      CalendarEvent? droppedEvent;
      final dragStates = <bool>[];
      await _pumpPanel(
        tester,
        event: event,
        onEventDropped: (event, date, index) async {
          droppedEvent = event;
          droppedDate = date;
          droppedIndex = index;
        },
        onEventDragStateChanged: dragStates.add,
      );

      final draggable = find.byKey(const ValueKey('event-drag-meeting-event'));
      final gesture = await tester.startGesture(tester.getCenter(draggable));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('event-date-drop-overlay')),
        findsNothing,
      );
      expect(find.textContaining('2026'), findsWidgets);
      final target = find.byKey(
        const ValueKey('event-order-drop-meeting-event'),
      );
      expect(target, findsOneWidget);
      await gesture.moveTo(tester.getBottomRight(target) - const Offset(8, 4));
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(droppedDate, DateTime(2026, 7, 17, 10));
      expect(droppedEvent?.id, event.id);
      expect(droppedEvent?.occurrenceId, event.occurrenceId);
      expect(droppedIndex, 1);
      expect(dragStates, containsAllInOrder([true, false]));
    },
  );

  testWidgets('empty day panel accepts a calendar event for its date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final event = _event();
    final repository = _SingleEventRepository(event);
    final commandService = EventCommandService(
      repository: repository,
      settingsRepository: settingsRepository,
      notificationService: _NoopNotificationService(),
      syncService: _NoopSyncService(),
    );
    final targetDate = DateTime(2026, 7, 20);
    DateTime? droppedDate;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          eventRepositoryProvider.overrideWithValue(repository),
          eventCommandServiceProvider.overrideWithValue(commandService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 240,
                  height: 64,
                  child: CalendarEventDraggable(
                    event: event,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
                Expanded(
                  child: EventDetailsPanel(
                    date: targetDate,
                    events: const [],
                    onEventDropped: (event, date, index) async {
                      droppedDate = date;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('일정이 없습니다.'), findsOneWidget);
    final source = find.byType(CalendarEventDraggable).first;
    final target = find.byKey(const ValueKey('event-details-date-drop-target'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(droppedDate, targetDate);
  });

  testWidgets(
    'reordering lifts the full title and moves events around the insertion gap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = _event().copyWith(
        id: 'reorder-first',
        title: '첫 번째 일정',
        startAt: DateTime(2026, 7, 18, 9),
        endAt: DateTime(2026, 7, 18, 10),
      );
      final second = _event().copyWith(
        id: 'reorder-second',
        title: '두 번째 일정',
        startAt: DateTime(2026, 7, 18, 11),
        endAt: DateTime(2026, 7, 18, 12),
        completed: true,
      );
      int? droppedIndex;
      await _pumpEventList(
        tester,
        events: [first, second],
        onEventDropped: (event, date, index) async {
          droppedIndex = index;
        },
      );

      final firstDrag = find.byKey(const ValueKey('event-drag-reorder-first'));
      final secondDrag = find.byKey(
        const ValueKey('event-drag-reorder-second'),
      );
      final firstRect = tester.getRect(firstDrag);
      final firstTopBefore = firstRect.top;
      final gesture = await tester.startGesture(tester.getCenter(secondDrag));
      await tester.pump(const Duration(milliseconds: 400));

      final feedback = find.byKey(
        const ValueKey('calendar-event-drag-feedback-reorder-second'),
      );
      expect(feedback, findsOneWidget);
      expect(
        find.descendant(of: feedback, matching: find.text('두 번째 일정')),
        findsOneWidget,
      );

      await gesture.moveTo(Offset(firstRect.center.dx, firstRect.top + 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      final firstGap = find.byKey(const ValueKey('event-reorder-gap-0'));
      expect(tester.getSize(firstGap).height, greaterThan(40));
      expect(tester.getTopLeft(firstDrag).dy, greaterThan(firstTopBefore + 40));

      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(droppedIndex, 0);
      expect(feedback, findsNothing);
    },
  );

  testWidgets('accepted drag stays lifted until the save finishes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = _event().copyWith(
      id: 'pending-first',
      startAt: DateTime(2026, 7, 18, 9),
      endAt: DateTime(2026, 7, 18, 10),
    );
    final second = _event().copyWith(
      id: 'pending-second',
      startAt: DateTime(2026, 7, 18, 11),
      endAt: DateTime(2026, 7, 18, 12),
    );
    final saveCompleter = Completer<void>();
    final dragStates = <bool>[];
    final interactionStates = <bool>[];
    await _pumpEventList(
      tester,
      events: [first, second],
      onEventDropped: (event, date, index) => saveCompleter.future,
      onEventDragStateChanged: dragStates.add,
      onEventDragInteractionStateChanged: interactionStates.add,
    );

    final firstDrag = find.byKey(const ValueKey('event-drag-pending-first'));
    final secondDrag = find.byKey(const ValueKey('event-drag-pending-second'));
    final gesture = await tester.startGesture(tester.getCenter(secondDrag));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(tester.getTopLeft(firstDrag) + const Offset(8, 2));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(dragStates, [true]);
    expect(interactionStates, [true, false]);
    final pendingEntry = find.byKey(
      const ValueKey('event-reorder-entry-pending-second'),
    );
    final entryAligns = tester.widgetList<Align>(
      find.descendant(of: pendingEntry, matching: find.byType(Align)),
    );
    expect(entryAligns.any((align) => align.heightFactor == 0), isTrue);
    expect(
      find.byKey(const ValueKey('event-accepted-preview-pending-second')),
      findsOneWidget,
    );

    saveCompleter.complete();
    await tester.pump();
    await tester.pump();
    expect(dragStates, [true, false]);
    expect(
      find.byKey(const ValueKey('event-accepted-preview-pending-second')),
      findsNothing,
    );
    final settledEntryAligns = tester.widgetList<Align>(
      find.descendant(of: pendingEntry, matching: find.byType(Align)),
    );
    expect(
      settledEntryAligns.any(
        (align) => align.heightFactor != null && align.heightFactor! < 1,
      ),
      isFalse,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('sidebar drag feedback morphs to a month flag and back', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final event = _event().copyWith(title: '형태가 바뀌는 일정');
    final compactFeedback = ValueNotifier(false);
    addTearDown(compactFeedback.dispose);
    await _pumpEventList(
      tester,
      events: [event],
      onEventDropped: (_, _, _) async {},
      compactDragFeedbackListenable: compactFeedback,
    );

    final draggable = find.byKey(const ValueKey('event-drag-meeting-event'));
    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('calendar-event-source-feedback')),
      findsOneWidget,
    );
    compactFeedback.value = true;
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      find.byKey(const ValueKey('calendar-event-compact-feedback')),
      findsOneWidget,
    );
    expect(find.text('형태가 바뀌는 일정'), findsWidgets);

    compactFeedback.value = false;
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      find.byKey(const ValueKey('calendar-event-source-feedback')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('sidebar feedback adopts the target schedule geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final event = _event().copyWith(title: '크기가 바뀌는 일정');
    final feedbackSpec = ValueNotifier(
      const CalendarEventDragFeedbackSpec.source(),
    );
    addTearDown(feedbackSpec.dispose);
    await _pumpEventList(
      tester,
      events: [event],
      onEventDropped: (_, _, _) async {},
      dragFeedbackSpecListenable: feedbackSpec,
    );

    final draggable = find.byKey(const ValueKey('event-drag-meeting-event'));
    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(const Duration(milliseconds: 400));
    final sourceFeedback = find.byKey(
      const ValueKey('calendar-event-drag-feedback-meeting-event'),
    );
    final sourceSize = tester.getSize(sourceFeedback);

    feedbackSpec.value = const CalendarEventDragFeedbackSpec.target(
      style: CalendarEventDragFeedbackStyle.schedule,
      width: 132,
      height: 94,
    );
    await tester.pump();
    final targetFeedback = find.byKey(
      const ValueKey('calendar-event-target-feedback-schedule'),
    );
    expect(targetFeedback, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 85));
    final shrinkingSize = tester.getSize(targetFeedback);
    expect(shrinkingSize.width, lessThan(sourceSize.width));
    expect(shrinkingSize.width, greaterThan(132));
    expect(shrinkingSize.height, lessThan(sourceSize.height));
    expect(shrinkingSize.height, greaterThan(94));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(targetFeedback), const Size(132, 94));
    expect(
      find.descendant(
        of: targetFeedback,
        matching: find.textContaining('크기가 바뀌는 일정'),
      ),
      findsOneWidget,
    );

    feedbackSpec.value = const CalendarEventDragFeedbackSpec.source();
    await tester.pump();
    expect(tester.getSize(sourceFeedback), const Size(132, 94));
    await tester.pump(const Duration(milliseconds: 85));
    final growingSize = tester.getSize(sourceFeedback);
    expect(growingSize.width, inExclusiveRange(132, sourceSize.width));
    expect(growingSize.height, inExclusiveRange(94, sourceSize.height));
    expect(
      find.descendant(of: sourceFeedback, matching: find.text(event.title)),
      findsOneWidget,
    );

    feedbackSpec.value = const CalendarEventDragFeedbackSpec.target(
      style: CalendarEventDragFeedbackStyle.schedule,
      width: 132,
      height: 94,
    );
    await tester.pump();
    expect(tester.getSize(sourceFeedback), growingSize);
    await tester.pump(const Duration(milliseconds: 85));
    expect(
      tester.getSize(sourceFeedback).width,
      inExclusiveRange(132, growingSize.width),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(sourceFeedback), const Size(132, 94));

    feedbackSpec.value = const CalendarEventDragFeedbackSpec.source();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getSize(sourceFeedback), sourceSize);
    expect(
      find.byKey(const ValueKey('calendar-event-source-feedback')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  test(
    'all-delete label is translated in every supported non-Korean locale',
    () {
      expect(const AppLocalizations(Locale('en')).text('전체 삭제'), 'Delete All');
      expect(const AppLocalizations(Locale('ja')).text('전체 삭제'), 'すべて削除');
      expect(
        const AppLocalizations(
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ).text('전체 삭제'),
        '全部刪除',
      );
    },
  );
}

List<Offset> _insetCorners(Rect rect) => [
  rect.topLeft + const Offset(4, 4),
  rect.topRight + const Offset(-4, 4),
  rect.bottomLeft + const Offset(4, -4),
  rect.bottomRight + const Offset(-4, -4),
];

Future<_SingleEventRepository> _pumpPanel(
  WidgetTester tester, {
  required CalendarEvent event,
  CalendarEventDropCallback? onEventDropped,
  ValueChanged<bool>? onEventDragStateChanged,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final settingsRepository = SettingsRepository(preferences: preferences);
  final repository = _SingleEventRepository(event);
  final commandService = EventCommandService(
    repository: repository,
    settingsRepository: settingsRepository,
    notificationService: _NoopNotificationService(),
    syncService: _NoopSyncService(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        eventRepositoryProvider.overrideWithValue(repository),
        eventCommandServiceProvider.overrideWithValue(commandService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EventDetailsPanel(
            date: event.startAt,
            events: [event],
            onEventDropped: onEventDropped,
            onEventDragStateChanged: onEventDragStateChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _pumpEventList(
  WidgetTester tester, {
  required List<CalendarEvent> events,
  required CalendarEventDropCallback onEventDropped,
  ValueChanged<bool>? onEventDragStateChanged,
  ValueChanged<bool>? onEventDragInteractionStateChanged,
  ValueListenable<bool>? compactDragFeedbackListenable,
  ValueListenable<CalendarEventDragFeedbackSpec>? dragFeedbackSpecListenable,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final settingsRepository = SettingsRepository(preferences: preferences);
  final repository = _MultipleEventRepository(events);
  final commandService = EventCommandService(
    repository: repository,
    settingsRepository: settingsRepository,
    notificationService: _NoopNotificationService(),
    syncService: _NoopSyncService(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        eventRepositoryProvider.overrideWithValue(repository),
        eventCommandServiceProvider.overrideWithValue(commandService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EventDetailsPanel(
            date: events.first.startAt,
            events: events,
            onEventDropped: onEventDropped,
            onEventDragStateChanged: onEventDragStateChanged,
            onEventDragInteractionStateChanged:
                onEventDragInteractionStateChanged,
            compactDragFeedbackListenable: compactDragFeedbackListenable,
            dragFeedbackSpecListenable: dragFeedbackSpecListenable,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CalendarEvent _event() {
  return CalendarEvent(
    id: 'meeting-event',
    title: '비밀 회의',
    memo: '준비물 확인',
    location: '서울시청',
    url: 'https://example.com/meeting',
    weather: '맑음',
    startAt: DateTime(2026, 7, 17, 10),
    endAt: DateTime(2026, 7, 17, 11),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: DateTime(2026, 7, 16),
    updatedAt: DateTime(2026, 7, 16),
  );
}

class _SingleEventRepository implements EventRepository {
  _SingleEventRepository(this.event);

  CalendarEvent event;

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => [event];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => [event];

  @override
  Future<CalendarEvent?> findById(String id) async => event;

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => [event];

  @override
  Future<void> save(CalendarEvent event) async {
    this.event = event;
  }

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {
    for (final event in events) {
      await save(event);
    }
  }

  @override
  Future<List<CalendarEvent>> search(String query) async => [event];

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value([event]);
}

class _MultipleEventRepository extends _SingleEventRepository {
  _MultipleEventRepository(this.events) : super(events.first);

  final List<CalendarEvent> events;

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => events;

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value(events);
}

class _NoopNotificationService implements NotificationService {
  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {}

  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<String> permissionSummary() async => '';

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {}

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
}

class _NoopSyncService implements SyncService {
  @override
  Future<void> queueEventDelete(String eventId) async {}

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {}

  @override
  Future<void> queueSettingsBackup() async {}

  @override
  Future<void> start() async {}
}
