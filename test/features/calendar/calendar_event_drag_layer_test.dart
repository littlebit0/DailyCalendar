import 'package:daily/features/calendar/widgets/calendar_event_drag_layer.dart';
import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mac sidebar shrinks to real centered month card and restores', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'crossing',
      title: 'Original title',
      startAt: DateTime(2026),
      endAt: DateTime(2026, 1, 1, 1),
      allDay: true,
      category: EventCategory.basic,
      colorValue: 0xff2244ff,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 76,
              child: CalendarEventDraggable(
                event: event,
                origin: CalendarEventDragOrigin.sidebar,
                child: const Text(
                  'Original title',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final source = find.byType(CalendarEventDraggable);
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 400));
    final feedback = find.byKey(
      const ValueKey('calendar-event-drag-feedback-crossing'),
    );
    activeCalendarEventDragFeedbackSpec.value =
        CalendarEventDragFeedbackSpec.target(
          style: CalendarEventDragFeedbackStyle.month,
          width: 110,
          height: 19,
          builder: (_) => calendarMonthDragCard(
            event,
            centerTitle: true,
            showTime: false,
            compact: false,
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    expect(tester.getSize(feedback).width, inExclusiveRange(110, 320));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(feedback), const Size(110, 19));
    final title = tester.widget<Text>(
      find.descendant(of: feedback, matching: find.text('Original title')),
    );
    expect(title.textAlign, TextAlign.center);
    expect(title.style!.color, const Color(0xff2244ff));
    activeCalendarEventDragFeedbackSpec.value =
        const CalendarEventDragFeedbackSpec.source();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    expect(tester.getSize(feedback).width, inExclusiveRange(110, 320));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(feedback), const Size(320, 76));
    expect(tester.getCenter(feedback), tester.getCenter(source));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final platform in TargetPlatform.values) {
    for (final size in [
      const Size(110, 24),
      const Size(140, 140),
      const Size(320, 80),
    ]) {
      testWidgets(
        '$platform preserves constrained card $size and centered rich text',
        (tester) async {
          final event = CalendarEvent(
            id: 'original',
            title: '일정',
            startAt: DateTime(2026),
            endAt: DateTime(2026, 1, 1, 1),
            allDay: false,
            category: EventCategory.basic,
            colorValue: 0xff2244ff,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          );
          const style = TextStyle(
            fontSize: 11,
            color: Color(0xff2244ff),
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.white,
          );
          final card = Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xff121a30),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text.rich(
              TextSpan(
                text: '일정 제목',
                style: style,
                children: [TextSpan(text: '\n09:00')],
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: Center(
                  child: SizedBox.fromSize(
                    size: size,
                    child: CalendarEventDraggable(event: event, child: card),
                  ),
                ),
              ),
            ),
          );
          final source = find.byType(CalendarEventDraggable);
          final gesture = await tester.startGesture(tester.getCenter(source));
          await tester.pump(const Duration(milliseconds: 400));
          final feedback = find.byKey(
            const ValueKey('calendar-event-drag-feedback-original'),
          );
          for (final target in CalendarEventDragFeedbackStyle.values) {
            activeCalendarEventDragFeedbackSpec.value =
                target == CalendarEventDragFeedbackStyle.source
                ? const CalendarEventDragFeedbackSpec.source()
                : CalendarEventDragFeedbackSpec.target(
                    style: target,
                    width: 50,
                    height: 10,
                  );
            await gesture.moveBy(const Offset(1, 1));
            await tester.pump();
            expect(tester.getSize(feedback), size);
            final text = tester.widget<Text>(
              find.descendant(of: feedback, matching: find.byType(Text)),
            );
            expect(text.textAlign, TextAlign.center);
            expect(text.textSpan!.style, style);
            expect(text.textSpan!.toPlainText(), '일정 제목\n09:00');
          }
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(feedback, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
