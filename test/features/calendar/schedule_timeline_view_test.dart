import 'dart:async';

import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/features/calendar/widgets/schedule_timeline_view.dart';
import 'package:daily/features/calendar/widgets/calendar_event_drag_layer.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/widgets/smooth_mouse_wheel_scroll_controller.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Windows mouse wheel smoothly accumulates time-axis scroll without changing the day',
    (tester) async {
      DateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: ScheduleTimelineView(
              days: [DateTime(2026, 8, 27)],
              events: const [],
              selectedDate: DateTime(2026, 8, 27),
              use24HourTime: true,
              showAllDayEvents: true,
              holidayBackgroundEnabled: true,
              holidayColorValue: EventCategory.holiday.colorValue,
              onShowAllDayEventsChanged: (_) {},
              onDateSelected: (date) => selectedDate = date,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final timeScroll = find.byKey(const ValueKey('schedule-time-scroll'));
      final controller = tester
          .widget<SingleChildScrollView>(timeScroll)
          .controller!;
      final initialOffset = controller.offset;
      controller.position.pointerScroll(120);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.offset, greaterThan(initialOffset));
      expect(controller.offset, lessThan(initialOffset + 120));

      controller.position.pointerScroll(120);
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(initialOffset + 240, 0.1));

      controller.position.pointerScroll(120);
      await tester.pump(const Duration(milliseconds: 40));
      controller.position.pointerScroll(-120);
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(initialOffset + 240, 0.1));

      controller.jumpTo(controller.position.maxScrollExtent - 40);
      controller.position.pointerScroll(120);
      await tester.pumpAndSettle();

      expect(controller.offset, controller.position.maxScrollExtent);
      expect(selectedDate, isNull);
    },
  );

  testWidgets('non-Windows schedule keeps the default scroll controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 27)],
            events: const [],
            selectedDate: DateTime(2026, 8, 27),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey('schedule-time-scroll')),
        )
        .controller!;

    expect(controller, isNot(isA<SmoothMouseWheelScrollController>()));
    expect(controller.offset, 7 * 64);
  });

  testWidgets('all-day area is absent when there are no all-day events', (
    tester,
  ) async {
    await _pumpAllDaySchedule(tester, eventCount: 0);

    expect(find.byKey(const ValueKey('schedule-all-day-area')), findsNothing);
  });

  testWidgets('all-day area height follows visible event rows', (tester) async {
    await _pumpAllDaySchedule(tester, eventCount: 1);
    final oneEventHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 3);
    final threeEventHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 6);
    final sixEventHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    expect(threeEventHeight, greaterThan(oneEventHeight));
    expect(sixEventHeight, greaterThan(threeEventHeight));
    expect(sixEventHeight, lessThan(130));
    expect(find.text('종일 일정 6'), findsOneWidget);
    expect(find.text('+2'), findsNothing);
  });

  testWidgets('all-day area grows with the app text scale', (tester) async {
    await _pumpAllDaySchedule(tester, eventCount: 4, textScale: 1);
    final basicHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 4, textScale: 1.15);
    final largeHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 4, textScale: 1.3);
    final extraLargeHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    expect(largeHeight, greaterThan(basicHeight));
    expect(extraLargeHeight, greaterThan(basicHeight));
    expect(extraLargeHeight, greaterThan(largeHeight));
  });

  testWidgets('week all-day overflow remains reachable by internal scroll', (
    tester,
  ) async {
    await _pumpAllDaySchedule(tester, eventCount: 6, weekMode: true);

    final allDayScroll = find.byKey(const ValueKey('schedule-all-day-scroll'));
    final scrollable = find.descendant(
      of: allDayScroll,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));

    await tester.drag(allDayScroll, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(find.text('종일 일정 6'), findsOneWidget);
  });

  testWidgets('week schedule colors weekends and holidays', (tester) async {
    final days = List.generate(7, (index) => DateTime(2026, 8, 23 + index));
    final holiday = CalendarEvent(
      id: 'holiday',
      title: '공휴일',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.holiday,
      colorValue: EventCategory.holiday.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      holiday: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: ScheduleTimelineView(
            days: days,
            events: [holiday],
            selectedDate: DateTime(2026, 8, 24),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: 0xffef4444,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _headerColor(tester, DateTime(2026, 8, 23)),
      const Color(0xffef4444),
    );
    expect(
      _headerColor(tester, DateTime(2026, 8, 24)),
      ThemeData.light().colorScheme.onPrimaryContainer,
    );
    expect(
      _headerColor(tester, DateTime(2026, 8, 27)),
      const Color(0xffef4444),
    );
    expect(
      _headerColor(tester, DateTime(2026, 8, 29)),
      const Color(0xff2563eb),
    );
  });

  testWidgets('day schedule keeps weekend color when the day is not selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 23)],
            events: const [],
            selectedDate: DateTime(2026, 8, 24),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: 0xffef4444,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _headerColor(tester, DateTime(2026, 8, 23)),
      const Color(0xffef4444),
    );
  });

  testWidgets('monday-start week retains the selected weekend color', (
    tester,
  ) async {
    final theme = ThemeData.dark();
    final days = List.generate(7, (index) => DateTime(2026, 8, 24 + index));

    await tester.pumpWidget(
      MaterialApp(
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: ScheduleTimelineView(
            days: days,
            events: const [],
            selectedDate: DateTime(2026, 8, 29),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: 0xffef4444,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _headerColor(tester, DateTime(2026, 8, 29)),
      const Color(0xff2563eb),
    );
    expect(
      _headerColor(tester, DateTime(2026, 8, 30)),
      const Color(0xffef4444),
    );
  });

  testWidgets('schedule holiday keeps weekend text without a red background', (
    tester,
  ) async {
    const holidayColor = Color(0xff10b981);
    final holiday = CalendarEvent(
      id: 'holiday',
      title: '공휴일',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.holiday.copyWith(
        colorValue: holidayColor.toARGB32(),
      ),
      colorValue: holidayColor.toARGB32(),
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      holiday: true,
    );

    Future<void> pump({required bool enabled}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ScheduleTimelineView(
              days: [DateTime(2026, 8, 27)],
              events: [holiday],
              selectedDate: DateTime(2026, 8, 26),
              use24HourTime: true,
              showAllDayEvents: true,
              holidayBackgroundEnabled: enabled,
              holidayColorValue: holidayColor.toARGB32(),
              onShowAllDayEventsChanged: (_) {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(enabled: true);
    expect(
      _headerBackgroundColor(tester, DateTime(2026, 8, 27)),
      Colors.transparent,
    );

    await pump(enabled: false);
    expect(_headerColor(tester, DateTime(2026, 8, 27)), holidayColor);
    expect(
      _headerBackgroundColor(tester, DateTime(2026, 8, 27)),
      Colors.transparent,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'today retains its holiday color and selected background in $brightness',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final theme = ThemeData(
          brightness: brightness,
          platform: TargetPlatform.macOS,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ScheduleTimelineView(
                days: List.generate(
                  7,
                  (index) => today.add(Duration(days: index)),
                ),
                events: const [],
                selectedDate: today,
                holidayDates: {today},
                holidayColorValue: 0xff10b981,
                holidayBackgroundEnabled: false,
                use24HourTime: true,
                showAllDayEvents: false,
                onShowAllDayEventsChanged: (_) {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_headerColor(tester, today), const Color(0xff10b981));
        expect(
          _headerBackgroundColor(tester, today),
          theme.colorScheme.primaryContainer,
        );
      },
    );
  }

  testWidgets('schedule all-day titles honor center alignment', (tester) async {
    final event = CalendarEvent(
      id: 'alignment',
      title: '정렬 테스트',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 27)],
            events: [event],
            selectedDate: DateTime(2026, 8, 27),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            centerEventTitles: true,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('정렬 테스트')).textAlign,
      TextAlign.center,
    );
  });

  testWidgets('completed schedule event uses a visible single strike', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'completed-schedule',
      title: '완료 일정',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      completed: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 27)],
            events: [event],
            selectedDate: DateTime(2026, 8, 27),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final style = tester.widget<Text>(find.text('완료 일정')).style!;
    expect(style.decoration, TextDecoration.lineThrough);
    expect(style.decorationStyle, TextDecorationStyle.solid);
    expect(style.decorationThickness, lessThan(2));
    expect(style.color, Color(EventCategory.basic.colorValue));
    final eventContainer = tester.widget<Container>(
      find
          .ancestor(of: find.text('완료 일정'), matching: find.byType(Container))
          .first,
    );
    expect(
      (eventContainer.decoration! as BoxDecoration).color,
      Color(EventCategory.basic.colorValue).withValues(alpha: 0.17),
    );
  });

  testWidgets('schedule event can be long-pressed and dropped on another day', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'move-schedule',
      title: '이동 일정',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    DateTime? droppedDate;
    final dragStates = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 27), DateTime(2026, 8, 28)],
            events: [event],
            selectedDate: DateTime(2026, 8, 27),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            onEventDropped: (event, date, index) async {
              droppedDate = date;
            },
            onEventDragStateChanged: dragStates.add,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('이동 일정')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final target = find.byKey(
      const ValueKey('schedule-day-background-2026-8-28'),
    );
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(droppedDate, DateTime(2026, 8, 28));
    expect(dragStates, containsAllInOrder([true, false]));
  });

  testWidgets('timed schedule drop keeps its center aligned to 30 minutes', (
    tester,
  ) async {
    final day = DateTime(2026, 8, 27);
    final event = CalendarEvent(
      id: 'move-timed-schedule',
      title: '시간 이동 일정',
      startAt: DateTime(2026, 8, 27, 9),
      endAt: DateTime(2026, 8, 27, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    DateTime? droppedStart;
    final saveCompleter = Completer<void>();
    final dragStates = <bool>[];
    final interactionStates = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [day],
            events: [event],
            selectedDate: day,
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            onEventTimeDropped: (event, targetStart) async {
              droppedStart = targetStart;
              await saveCompleter.future;
            },
            onEventDragStateChanged: dragStates.add,
            onEventDragInteractionStateChanged: interactionStates.add,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final eventBlock = find.byKey(
      ValueKey('schedule-event-${event.id}-${day.toIso8601String()}'),
    );
    final gesture = await tester.startGesture(tester.getCenter(eventBlock));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, 4.5 * 64));
    await tester.pump(const Duration(milliseconds: 220));
    final movingPreview = find.byKey(
      ValueKey('schedule-event-${event.id}-${day.toIso8601String()}-preview'),
    );
    expect(movingPreview, findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: movingPreview,
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      0.48,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 220));

    expect(droppedStart, DateTime(2026, 8, 27, 13, 30));
    expect(dragStates, [true]);
    expect(interactionStates, [true, false]);
    final acceptedPreview = find.byKey(
      ValueKey('schedule-event-${event.id}-${day.toIso8601String()}-preview'),
    );
    expect(acceptedPreview, findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: acceptedPreview,
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      1,
    );
    expect(
      find.byKey(const ValueKey('schedule-time-drop-target')),
      findsNothing,
    );

    saveCompleter.complete();
    await tester.pumpAndSettle();
    expect(dragStates, [true, false]);
    expect(acceptedPreview, findsNothing);
  });

  testWidgets('sidebar schedule drop changes only the date', (tester) async {
    final event = CalendarEvent(
      id: 'sidebar-schedule',
      title: '사이드바 일정',
      startAt: DateTime(2026, 8, 27, 9, 20),
      endAt: DateTime(2026, 8, 27, 11, 20),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    DateTime? droppedStart;
    var dragActive = false;
    var interactionActive = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Row(
              children: [
                SizedBox(
                  width: 150,
                  child: CalendarEventDraggable(
                    event: event,
                    origin: CalendarEventDragOrigin.sidebar,
                    onDragStateChanged: (active) =>
                        setState(() => dragActive = active),
                    onDragInteractionStateChanged: (active) =>
                        setState(() => interactionActive = active),
                    child: const SizedBox(
                      key: ValueKey('sidebar-schedule-source'),
                      height: 64,
                      child: Text('사이드바 일정'),
                    ),
                  ),
                ),
                Expanded(
                  child: ScheduleTimelineView(
                    days: [DateTime(2026, 8, 28)],
                    events: [event],
                    selectedDate: DateTime(2026, 8, 28),
                    use24HourTime: true,
                    showAllDayEvents: true,
                    holidayBackgroundEnabled: true,
                    holidayColorValue: EventCategory.holiday.colorValue,
                    externalEventDragActive: dragActive,
                    externalEventDragInteractionActive: interactionActive,
                    onEventTimeDropped: (event, targetStart) async {
                      droppedStart = targetStart;
                    },
                    onShowAllDayEventsChanged: (_) {},
                    onDateSelected: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('sidebar-schedule-source'))),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final target = find.byKey(const ValueKey('schedule-time-drop-target'));
    expect(target, findsOneWidget);
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(droppedStart, DateTime(2026, 8, 28, 9, 20));
  });

  testWidgets('overlapping schedule lanes follow category order', (
    tester,
  ) async {
    const work = EventCategory(id: 'work', label: '업무', colorValue: 0xff2563eb);
    const personal = EventCategory(
      id: 'personal',
      label: '개인',
      colorValue: 0xff10b981,
    );
    CalendarEvent event(String id, EventCategory category) {
      return CalendarEvent(
        id: id,
        title: id,
        startAt: DateTime(2026, 8, 27, 9),
        endAt: DateTime(2026, 8, 27, 11),
        allDay: false,
        category: category,
        colorValue: category.colorValue,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
    }

    Future<void> pump(List<String> categoryOrder) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleTimelineView(
              days: [DateTime(2026, 8, 27)],
              events: [event('personal', personal), event('work', work)],
              selectedDate: DateTime(2026, 8, 27),
              use24HourTime: true,
              showAllDayEvents: true,
              holidayBackgroundEnabled: true,
              holidayColorValue: EventCategory.holiday.colorValue,
              eventSortPriority: CalendarEventSortPriority.category,
              categoryOrder: categoryOrder,
              onShowAllDayEventsChanged: (_) {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final workFinder = find.byKey(
      ValueKey(
        'schedule-event-work-${DateTime(2026, 8, 27).toIso8601String()}',
      ),
    );
    final personalFinder = find.byKey(
      ValueKey(
        'schedule-event-personal-${DateTime(2026, 8, 27).toIso8601String()}',
      ),
    );

    await pump(const ['work', 'personal']);
    expect(
      tester.getTopLeft(workFinder).dx,
      lessThan(tester.getTopLeft(personalFinder).dx),
    );

    await pump(const ['personal', 'work']);
    expect(
      tester.getTopLeft(personalFinder).dx,
      lessThan(tester.getTopLeft(workFinder).dx),
    );
  });
}

Future<void> _pumpAllDaySchedule(
  WidgetTester tester, {
  required int eventCount,
  double textScale = 1,
  bool weekMode = false,
}) async {
  final events = List.generate(
    eventCount,
    (index) => CalendarEvent(
      id: 'all-day-$index',
      title: '종일 일정 ${index + 1}',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ScheduleTimelineView(
          days: weekMode
              ? List.generate(7, (index) => DateTime(2026, 8, 23 + index))
              : [DateTime(2026, 8, 27)],
          events: events,
          selectedDate: DateTime(2026, 8, 27),
          use24HourTime: true,
          showAllDayEvents: true,
          holidayBackgroundEnabled: true,
          holidayColorValue: EventCategory.holiday.colorValue,
          onShowAllDayEventsChanged: (_) {},
          onDateSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _headerColor(WidgetTester tester, DateTime day) {
  final text = tester.widget<Text>(
    find.byKey(
      ValueKey('schedule-day-header-${day.year}-${day.month}-${day.day}'),
    ),
  );
  return text.style?.color;
}

Color? _headerBackgroundColor(WidgetTester tester, DateTime day) {
  final container = tester.widget<Container>(
    find.byKey(
      ValueKey('schedule-day-background-${day.year}-${day.month}-${day.day}'),
    ),
  );
  return (container.decoration! as BoxDecoration).color;
}
