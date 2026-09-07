import 'dart:async';

import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps today and lunar day labels on the same row', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final neighbor = today.weekday == DateTime.sunday
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));
    final event = CalendarEvent(
      id: 'single',
      title: '일정',
      startAt: today,
      endAt: today.add(const Duration(days: 1)),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: today,
      updatedAt: today,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(today.year, today.month),
              selectedDate: today,
              events: [event],
              weekStartsOnMonday: true,
              showLunarDates: true,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final todayNumber = find.byKey(
      ValueKey('day-number-${today.year}-${today.month}-${today.day}'),
    );
    final neighborNumber = find.byKey(
      ValueKey('day-number-${neighbor.year}-${neighbor.month}-${neighbor.day}'),
    );
    final flag = find.byKey(
      ValueKey(
        'event-span-single-${_weekStart(today).year}-${_weekStart(today).month}-${_weekStart(today).day}',
      ),
    );

    expect(todayNumber, findsOneWidget);
    expect(neighborNumber, findsOneWidget);
    expect(flag, findsOneWidget);
    expect(
      tester.getTopLeft(todayNumber).dy,
      closeTo(tester.getTopLeft(neighborNumber).dy, 0.1),
    );
    expect(
      tester.getTopLeft(flag).dy - tester.getBottomLeft(todayNumber).dy,
      inInclusiveRange(1, 8),
    );
  });

  testWidgets('renders a multi-day event as one spanning flag in a week row', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 1);
    final event = CalendarEvent(
      id: 'trip',
      title: '부산 여행',
      startAt: DateTime(2026, 5, 4),
      endAt: DateTime(2026, 5, 8),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 4),
              events: [event],
              weekStartsOnMonday: true,
              showLunarDates: true,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final flag = find.byKey(const ValueKey('event-span-trip-2026-5-4'));
    expect(flag, findsOneWidget);
    expect(find.text('부산 여행'), findsOneWidget);
    expect(tester.getSize(flag).width, greaterThan(300));
  });

  testWidgets('hides adjacent-month dates and clips their event spans', (
    tester,
  ) async {
    DateTime? selectedDate;
    (DateTime, DateTime)? selectedRange;
    final event = CalendarEvent(
      id: 'month-boundary',
      title: '월 경계 일정',
      startAt: DateTime(2026, 4, 29),
      endAt: DateTime(2026, 5, 3),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 1),
              events: [event],
              weekStartsOnMonday: true,
              showLunarDates: true,
              showAdjacentMonthDates: false,
              onDateSelected: (date) => selectedDate = date,
              onDateRangeSelected: (start, end) async {
                selectedRange = (start, end);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('day-cell-2026-4-27')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-number-2026-4-27')), findsNothing);
    expect(find.byKey(const ValueKey('day-number-2026-5-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-cell-2026-4-27')));
    await tester.pump();
    expect(selectedDate, isNull);

    final blankCell = find.byKey(const ValueKey('day-cell-2026-4-30'));
    final blankCenter = tester.getCenter(blankCell);
    final blankClick = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await blankClick.down(blankCenter);
    await blankClick.moveBy(const Offset(8, 3));
    await blankClick.up();
    await tester.pump();
    expect(selectedRange, isNull);

    final rangeDrag = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await rangeDrag.down(
      tester.getCenter(find.byKey(const ValueKey('day-cell-2026-5-1'))),
    );
    await rangeDrag.moveTo(blankCenter);
    await rangeDrag.up();
    await tester.pump();
    expect(selectedRange?.$1, DateTime(2026, 4, 30));
    expect(selectedRange?.$2, DateTime(2026, 5, 1));

    final flag = find.byKey(
      const ValueKey('event-span-month-boundary-2026-4-27'),
    );
    expect(flag, findsOneWidget);
    expect(tester.getSize(flag).width, inInclusiveRange(170, 190));
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('shows adjacent-month dates when enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 4),
              selectedDate: DateTime(2026, 4, 1),
              events: const [],
              weekStartsOnMonday: true,
              showLunarDates: false,
              showAdjacentMonthDates: true,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('day-number-2026-3-30')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-number-2026-5-3')), findsOneWidget);
  });

  testWidgets('uses the configured holiday color only when enabled', (
    tester,
  ) async {
    const holidayColor = Color(0xff10b981);
    final holidayCategory = EventCategory.holiday.copyWith(
      colorValue: holidayColor.toARGB32(),
    );
    final holiday = CalendarEvent(
      id: 'holiday',
      title: '공휴일',
      startAt: DateTime(2026, 5, 5),
      endAt: DateTime(2026, 5, 6),
      allDay: true,
      category: holidayCategory,
      colorValue: holidayCategory.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      holiday: true,
    );

    Future<void> pump({
      required bool enabled,
      Brightness brightness = Brightness.light,
      DateTime? selectedDate,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 420,
              child: CalendarMonthGrid(
                month: DateTime(2026, 5),
                selectedDate: selectedDate ?? DateTime(2026, 5, 4),
                events: [holiday],
                weekStartsOnMonday: true,
                showLunarDates: false,
                holidayBackgroundEnabled: enabled,
                holidayColorValue: holidayCategory.colorValue,
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(enabled: true);
    var cell = tester.widget<Container>(
      find.byKey(const ValueKey('day-cell-2026-5-5')),
    );
    expect(
      (cell.decoration! as BoxDecoration).color,
      holidayColor.withValues(alpha: 0.14),
    );

    await pump(enabled: false);
    cell = tester.widget<Container>(
      find.byKey(const ValueKey('day-cell-2026-5-5')),
    );
    expect((cell.decoration! as BoxDecoration).color, Colors.transparent);

    await pump(enabled: true, brightness: Brightness.dark);
    cell = tester.widget<Container>(
      find.byKey(const ValueKey('day-cell-2026-5-5')),
    );
    expect(
      (cell.decoration! as BoxDecoration).color,
      holidayColor.withValues(alpha: 0.22),
    );

    await pump(
      enabled: true,
      brightness: Brightness.dark,
      selectedDate: DateTime(2026, 5, 5),
    );
    cell = tester.widget<Container>(
      find.byKey(const ValueKey('day-cell-2026-5-5')),
    );
    expect(
      (cell.decoration! as BoxDecoration).color,
      ThemeData.dark().colorScheme.primaryContainer.withValues(alpha: 0.45),
    );
  });

  testWidgets('keeps month event height while changing title alignment', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'alignment',
      title: '정렬 테스트',
      startAt: DateTime(2026, 5, 5),
      endAt: DateTime(2026, 5, 6),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

    Future<Size> pump({required bool centered}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 420,
              child: CalendarMonthGrid(
                month: DateTime(2026, 5),
                selectedDate: DateTime(2026, 5, 4),
                events: [event],
                weekStartsOnMonday: true,
                showLunarDates: false,
                centerEventTitles: centered,
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(
        find.byKey(const ValueKey('event-span-alignment-2026-5-4')),
      );
    }

    final leadingSize = await pump(centered: false);
    expect(tester.widget<Text>(find.text('정렬 테스트')).textAlign, TextAlign.start);

    final centeredSize = await pump(centered: true);
    expect(
      tester.widget<Text>(find.text('정렬 테스트')).textAlign,
      TextAlign.center,
    );
    expect(centeredSize.height, leadingSize.height);
  });

  testWidgets('month event lanes follow the selected sort priority', (
    tester,
  ) async {
    const work = EventCategory(id: 'work', label: '업무', colorValue: 0xff2563eb);
    const personal = EventCategory(
      id: 'personal',
      label: '개인',
      colorValue: 0xff10b981,
    );
    final workEvent = CalendarEvent(
      id: 'work-late',
      title: '업무',
      startAt: DateTime(2026, 5, 5, 18),
      endAt: DateTime(2026, 5, 5, 19),
      allDay: false,
      category: work,
      colorValue: work.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
    final personalEvent = CalendarEvent(
      id: 'personal-early',
      title: '개인',
      startAt: DateTime(2026, 5, 5, 9),
      endAt: DateTime(2026, 5, 5, 10),
      allDay: false,
      category: personal,
      colorValue: personal.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

    Future<void> pump(CalendarEventSortPriority priority) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 420,
              child: CalendarMonthGrid(
                month: DateTime(2026, 5),
                selectedDate: DateTime(2026, 5, 4),
                events: [personalEvent, workEvent],
                weekStartsOnMonday: true,
                showLunarDates: false,
                eventSortPriority: priority,
                categoryOrder: const ['work', 'personal'],
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    const workFlag = ValueKey('event-span-work-late-2026-5-4');
    const personalFlag = ValueKey('event-span-personal-early-2026-5-4');

    await pump(CalendarEventSortPriority.category);
    expect(
      tester.getTopLeft(find.byKey(workFlag)).dy,
      lessThan(tester.getTopLeft(find.byKey(personalFlag)).dy),
    );

    await pump(CalendarEventSortPriority.time);
    expect(
      tester.getTopLeft(find.byKey(personalFlag)).dy,
      lessThan(tester.getTopLeft(find.byKey(workFlag)).dy),
    );
  });

  testWidgets('month event lanes update to the date-specific manual order', (
    tester,
  ) async {
    final first = CalendarEvent(
      id: 'first',
      title: '첫 번째',
      startAt: DateTime(2026, 5, 5, 9),
      endAt: DateTime(2026, 5, 5, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
    final second = CalendarEvent(
      id: 'second',
      title: '두 번째',
      startAt: DateTime(2026, 5, 5, 18),
      endAt: DateTime(2026, 5, 5, 19),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

    Future<void> pump(List<String> manualOrder) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 420,
              child: CalendarMonthGrid(
                month: DateTime(2026, 5),
                selectedDate: DateTime(2026, 5, 5),
                events: [first, second],
                weekStartsOnMonday: true,
                showLunarDates: false,
                manualEventOrders: {
                  '2026-05-05': CalendarManualEventOrder(
                    eventKeys: manualOrder,
                    updatedAt: DateTime(
                      2026,
                      5,
                      1,
                      manualOrder.first == 'first' ? 1 : 2,
                    ),
                    deviceId: 'test-device',
                  ),
                },
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    const firstFlag = ValueKey('event-span-first-2026-5-4');
    const secondFlag = ValueKey('event-span-second-2026-5-4');

    await pump(const ['first', 'second']);
    expect(
      tester.getTopLeft(find.byKey(firstFlag)).dy,
      lessThan(tester.getTopLeft(find.byKey(secondFlag)).dy),
    );

    await pump(const ['second', 'first']);
    expect(
      tester.getTopLeft(find.byKey(secondFlag)).dy,
      lessThan(tester.getTopLeft(find.byKey(firstFlag)).dy),
    );
  });

  testWidgets('uses fixed iPhone-width event capacity in month cells', (
    tester,
  ) async {
    await _expectVisibleEventFlags(
      tester,
      width: 375,
      height: 812,
      expectedVisible: 4,
    );
    await _expectVisibleEventFlags(
      tester,
      width: 430,
      height: 932,
      expectedVisible: 5,
    );
    await _expectVisibleEventFlags(
      tester,
      width: 440,
      height: 956,
      expectedVisible: 6,
    );
  });

  testWidgets('shows four event rows in a compact macOS month area', (
    tester,
  ) async {
    await _expectVisibleEventFlags(
      tester,
      width: 800,
      height: 570,
      expectedVisible: 4,
    );
  });

  testWidgets('does not reserve an empty sixth row for a five-week month', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 570,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 1),
              events: const [],
              weekStartsOnMonday: true,
              showLunarDates: false,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(_dayNumberKey(DateTime(2026, 5, 31)), findsOneWidget);
    expect(_dayNumberKey(DateTime(2026, 6, 1)), findsNothing);
  });

  testWidgets('rounds each visible cross-month range segment', (tester) async {
    Future<BoxDecoration> pumpRangeMonth(DateTime month) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 420,
              child: CalendarMonthGrid(
                month: month,
                selectedDate: month,
                events: const [],
                weekStartsOnMonday: true,
                showLunarDates: false,
                showAdjacentMonthDates: false,
                continuous: true,
                externalRangeStart: DateTime(2026, 8, 31),
                externalRangeEnd: DateTime(2026, 9, 2),
                enableRangeGestures: false,
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      final highlight = find.byKey(const ValueKey('selected-range-2026-8-31'));
      expect(highlight, findsOneWidget);
      return tester.widget<DecoratedBox>(highlight).decoration as BoxDecoration;
    }

    final augustDecoration = await pumpRangeMonth(DateTime(2026, 8));
    expect(augustDecoration.borderRadius, BorderRadius.circular(8));

    final septemberDecoration = await pumpRangeMonth(DateTime(2026, 9));
    expect(septemberDecoration.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('selects a date range with a primary mouse drag', (tester) async {
    final now = DateTime(2026, 5, 1);
    final holiday = CalendarEvent(
      id: 'holiday',
      title: '공휴일',
      startAt: DateTime(2026, 5, 6),
      endAt: DateTime(2026, 5, 7),
      allDay: true,
      category: EventCategory.holiday,
      colorValue: EventCategory.holiday.colorValue,
      createdAt: now,
      updatedAt: now,
      readOnly: true,
      systemEvent: true,
      holiday: true,
    );
    DateTime? selectedStart;
    DateTime? selectedEnd;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 1),
              events: [holiday],
              weekStartsOnMonday: true,
              showLunarDates: false,
              onDateSelected: (_) {},
              onDateRangeSelected: (start, end) async {
                selectedStart = start;
                selectedEnd = end;
              },
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(_dayNumberKey(DateTime(2026, 5, 4))),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(tester.getCenter(_dayNumberKey(DateTime(2026, 5, 8))));
    await tester.pump();

    final rangeHighlight = find.byKey(
      const ValueKey('selected-range-2026-5-4'),
    );
    expect(rangeHighlight, findsOneWidget);
    expect(tester.getSize(rangeHighlight).width, greaterThan(400));
    final holidayCell = tester.widget<Container>(
      find.byKey(const ValueKey('day-cell-2026-5-6')),
    );
    final holidayCellDecoration = holidayCell.decoration! as BoxDecoration;
    expect(holidayCellDecoration.color, Colors.transparent);

    await gesture.up();
    await tester.pump();

    expect(selectedStart, DateTime(2026, 5, 4));
    expect(selectedEnd, DateTime(2026, 5, 8));
  });

  testWidgets('selects a date with a stationary mouse click', (tester) async {
    DateTime? selectedDate;
    final targetDate = DateTime(2026, 5, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 1),
              events: const [],
              weekStartsOnMonday: true,
              showLunarDates: false,
              onDateSelected: (date) => selectedDate = date,
              onDateRangeSelected: (_, _) async {},
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(_dayNumberKey(targetDate)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.up();
    await tester.pump();

    expect(selectedDate, targetDate);
  });

  testWidgets('selects a date with a touch tap', (tester) async {
    DateTime? selectedDate;
    final targetDate = DateTime(2026, 5, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 1),
              events: const [],
              weekStartsOnMonday: true,
              showLunarDates: false,
              onDateSelected: (date) => selectedDate = date,
              onDateRangeSelected: (_, _) async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(_dayNumberKey(targetDate));
    await tester.pump();

    expect(selectedDate, targetDate);
  });

  testWidgets('tapping a multi-day event selects the date under the pointer', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'tap-event',
      title: '연속 일정',
      startAt: DateTime(2026, 5, 4),
      endAt: DateTime(2026, 5, 7),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
    DateTime? selectedDate;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 1),
              events: [event],
              weekStartsOnMonday: true,
              showLunarDates: false,
              onDateSelected: (date) => selectedDate = date,
              onEventDropped: (_, _, _) async {},
            ),
          ),
        ),
      ),
    );

    final flag = find.byKey(const ValueKey('event-span-tap-event-2026-5-4'));
    final rect = tester.getRect(flag);
    await tester.tapAt(Offset(rect.left + rect.width * 5 / 6, rect.center.dy));
    await tester.pump(kDoubleTapTimeout);

    expect(selectedDate, DateTime(2026, 5, 6));
  });

  testWidgets('long-press dragging an event drops it on another date', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'drag-event',
      title: '이동할 일정',
      startAt: DateTime(2026, 5, 4, 9),
      endAt: DateTime(2026, 5, 4, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
    CalendarEvent? droppedEvent;
    DateTime? droppedDate;
    int? droppedIndex;
    final dragStates = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 4),
              events: [event],
              weekStartsOnMonday: true,
              showLunarDates: false,
              onDateSelected: (_) {},
              onEventDropped: (event, date, index) async {
                droppedEvent = event;
                droppedDate = date;
                droppedIndex = index;
              },
              onEventDragStateChanged: dragStates.add,
            ),
          ),
        ),
      ),
    );

    final flag = find.byKey(const ValueKey('event-span-drag-event-2026-5-4'));
    final target = _dayNumberKey(DateTime(2026, 5, 6));
    final gesture = await tester.startGesture(
      tester.getCenter(flag),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 360));

    final feedback = find.byKey(
      const ValueKey('calendar-event-drag-feedback-drag-event'),
    );
    expect(feedback, findsOneWidget);
    final feedbackTitle = find.descendant(
      of: feedback,
      matching: find.textContaining('이동할 일정'),
    );
    expect(feedbackTitle, findsOneWidget);
    expect(
      tester.widget<Material>(feedback).color,
      isNot(Color(event.colorValue)),
    );
    expect(
      tester.widget<Text>(feedbackTitle).style?.color,
      Color(event.colorValue),
    );

    await gesture.moveTo(tester.getCenter(target) + const Offset(0, 35));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(droppedEvent?.id, 'drag-event');
    expect(droppedDate, DateTime(2026, 5, 6));
    expect(droppedIndex, isNotNull);
    expect(dragStates, containsAllInOrder([true, false]));
  });

  testWidgets('month drag opens an insertion lane before the drop', (
    tester,
  ) async {
    CalendarEvent event(String id, int hour) => CalendarEvent(
      id: id,
      title: id,
      startAt: DateTime(2026, 5, 4, hour),
      endAt: DateTime(2026, 5, 4, hour + 1),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
    final first = event('first-lane', 9);
    final second = event('second-lane', 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 4),
              events: [first, second],
              weekStartsOnMonday: true,
              showLunarDates: false,
              onDateSelected: (_) {},
              onEventDropped: (_, _, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const firstFlag = ValueKey('event-span-first-lane-2026-5-4');
    const secondFlag = ValueKey('event-span-second-lane-2026-5-4');
    final firstTop = tester.getTopLeft(find.byKey(firstFlag)).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(secondFlag)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(tester.getCenter(find.byKey(firstFlag)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const ValueKey('event-span-second-lane-2026-5-4-preview')),
      findsOneWidget,
    );
    final previewOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(
          const ValueKey('event-span-second-lane-2026-5-4-preview'),
        ),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(previewOpacity.opacity, 0);
    final previewTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('event-span-second-lane-2026-5-4-preview')),
        )
        .dy;
    expect(
      tester.getTopLeft(find.byKey(firstFlag)).dy,
      allOf(greaterThan(firstTop + 10), greaterThan(previewTop)),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('external event drag enables the month date drop targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 4),
              events: const [],
              weekStartsOnMonday: true,
              showLunarDates: false,
              externalEventDragActive: true,
              externalEventDragInteractionActive: true,
              onDateSelected: (_) {},
              onEventDropped: (_, _, _) async {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('event-drop-target-2026-5-6')),
      findsOneWidget,
    );
  });

  testWidgets(
    'accepted iOS month drag releases input while its save is pending',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final event = CalendarEvent(
        id: 'pending-month-drag',
        title: '저장 중 일정',
        startAt: DateTime(2026, 5, 4, 9),
        endAt: DateTime(2026, 5, 4, 10),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final saveCompleter = Completer<void>();
      final visualStates = <bool>[];
      final interactionStates = <bool>[];
      DateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 720,
              child: CalendarMonthGrid(
                month: DateTime(2026, 5),
                selectedDate: DateTime(2026, 5, 4),
                events: [event],
                weekStartsOnMonday: true,
                showLunarDates: false,
                onDateSelected: (date) => selectedDate = date,
                onEventDropped: (_, _, _) => saveCompleter.future,
                onEventDragStateChanged: visualStates.add,
                onEventDragInteractionStateChanged: interactionStates.add,
              ),
            ),
          ),
        ),
      );

      final source = find.byKey(
        const ValueKey('event-span-pending-month-drag-2026-5-4'),
      );
      final target = _dayNumberKey(DateTime(2026, 5, 6));
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(milliseconds: 360));
      await gesture.moveTo(tester.getCenter(target) + const Offset(0, 35));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 220));

      expect(interactionStates, [true, false]);
      expect(visualStates, [true]);
      expect(
        find.byKey(const ValueKey('event-drop-target-2026-5-6')),
        findsNothing,
      );
      final acceptedPreview = find.byKey(
        const ValueKey('event-span-pending-month-drag-2026-5-4-preview'),
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

      await tester.tap(target);
      await tester.pump();
      expect(selectedDate, DateTime(2026, 5, 6));

      saveCompleter.complete();
      await tester.pumpAndSettle();
      expect(visualStates, [true, false]);
      expect(acceptedPreview, findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test('defines the requested full-app text scale choices', () {
    expect(AppTextSize.basic.scale, 0.8);
    expect(AppTextSize.large.scale, 1.0);
  });
}

DateTime _weekStart(DateTime day) {
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - DateTime.monday));
}

Finder _dayNumberKey(DateTime day) {
  return find.byKey(ValueKey('day-number-${day.year}-${day.month}-${day.day}'));
}

Future<void> _expectVisibleEventFlags(
  WidgetTester tester, {
  required double width,
  required double height,
  required int expectedVisible,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final now = DateTime(2026, 5, 1);
  final events = List.generate(
    7,
    (index) => CalendarEvent(
      id: 'density-$index',
      title: '일정 ${index + 1}',
      startAt: DateTime(2026, 5, 4, 9 + index),
      endAt: DateTime(2026, 5, 4, 10 + index),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: now,
      updatedAt: now,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 4),
              events: events,
              weekStartsOnMonday: true,
              showLunarDates: true,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  for (var index = 0; index < expectedVisible; index++) {
    expect(
      find.byKey(ValueKey('event-span-density-$index-2026-5-4')),
      findsOneWidget,
      reason: '$width px should show event lane ${index + 1}.',
    );
  }
  expect(
    find.byKey(ValueKey('event-span-density-$expectedVisible-2026-5-4')),
    findsNothing,
    reason: '$width px should overflow after $expectedVisible visible events.',
  );
  final lastVisibleFlag = find.byKey(
    ValueKey('event-span-density-${expectedVisible - 1}-2026-5-4'),
  );
  final overflowLabel = find.text('+${events.length - expectedVisible}');
  expect(overflowLabel, findsOneWidget);
  expect(
    tester.getTopLeft(overflowLabel).dy,
    greaterThanOrEqualTo(tester.getBottomLeft(lastVisibleFlag).dy),
    reason: '$width px overflow label should not overlap visible events.',
  );
}
