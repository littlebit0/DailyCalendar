import 'dart:async';

import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:daily/features/events/domain/event_template.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _template = EventTemplate(
  id: 't1',
  name: '저녁 운동',
  title: '운동',
  startMinutes: 19 * 60,
  endMinutes: 20 * 60,
  categoryId: EventCategory.basic.id,
);

Future<void> _open(
  WidgetTester tester,
  EventEditorDialog dialog, {
  ValueChanged<EventDraft?>? onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final draft = await showDialog<EventDraft>(
                context: context,
                builder: (_) => dialog,
              );
              onClosed?.call(draft);
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'one tap saves once, closes only after the save, and reports success',
    (tester) async {
      final save = Completer<void>();
      final added = <EventTemplate>[];
      final dates = <DateTime>[];
      var closed = false;
      await _open(
        tester,
        EventEditorDialog(
          initialDate: DateTime(2026, 10, 30),
          templates: [_template],
          onQuickAdd: (template, date) {
            added.add(template);
            dates.add(date);
            return save.future;
          },
        ),
        onClosed: (_) => closed = true,
      );

      await tester.tap(find.text('저녁 운동'));
      await tester.pump();
      // A second tap while the first save runs is ignored.
      await tester.tap(find.text('저녁 운동'), warnIfMissed: false);
      await tester.pump();
      expect(added, [_template]);
      expect(dates, [DateTime(2026, 10, 30)]);
      expect(closed, isFalse);
      expect(find.byType(SnackBar), findsNothing);

      save.complete();
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(find.text('\'운동\' 일정을 추가했습니다.'), findsOneWidget);
    },
  );

  testWidgets('quick add uses the start date currently shown in the editor', (
    tester,
  ) async {
    final dates = <DateTime>[];
    await _open(
      tester,
      EventEditorDialog(
        initialDate: DateTime(2026, 10, 30),
        templates: [_template],
        onQuickAdd: (_, date) async => dates.add(date),
      ),
    );
    final startPicker = find.byIcon(Icons.calendar_today_outlined).first;
    await tester.ensureVisible(startPicker);
    await tester.tap(startPicker);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('31'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저녁 운동'));
    await tester.tap(find.text('저녁 운동'));
    await tester.pumpAndSettle();
    expect(dates, [DateTime(2026, 10, 31)]);
  });

  testWidgets('a failed quick add keeps the dialog open with the reason', (
    tester,
  ) async {
    var closed = false;
    var attempts = 0;
    await _open(
      tester,
      EventEditorDialog(
        initialDate: DateTime(2026, 10, 30),
        templates: [_template],
        onQuickAdd: (_, _) async {
          attempts++;
          throw const EventTemplateUnavailable('템플릿의 분류가 삭제되었습니다.');
        },
      ),
      onClosed: (_) => closed = true,
    );

    await tester.tap(find.text('저녁 운동'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('템플릿의 분류가 삭제되었습니다.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // The template can be retried; it is never consumed.
    await tester.tap(find.text('저녁 운동'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('many templates scroll with the form instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(
      tester,
      EventEditorDialog(
        initialDate: DateTime(2026, 10, 30),
        templates: [
          for (var i = 0; i < 40; i++)
            EventTemplate(
              id: 't$i',
              name: '템플릿 이름 $i',
              title: '운동',
              categoryId: EventCategory.basic.id,
            ),
        ],
        onQuickAdd: (_, _) async {},
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('제목'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('제목'), findsOneWidget);
  });

  testWidgets('quick add is offered only while creating an event', (
    tester,
  ) async {
    final start = DateTime(2026, 10, 30, 9);
    final event = EventDraft(
      title: '기존',
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
    ).toEvent(id: 'e1', now: start, deviceId: 'd');
    await _open(
      tester,
      EventEditorDialog(
        initialDate: start,
        event: event,
        templates: [_template],
        onQuickAdd: (_, _) async {},
      ),
    );
    expect(find.text('빠른 추가'), findsNothing);
  });

  testWidgets('save as template passes the edited draft and keeps the dialog', (
    tester,
  ) async {
    EventDraft? stored;
    var closed = false;
    await _open(
      tester,
      EventEditorDialog(
        initialDate: DateTime(2026, 10, 30),
        onSaveTemplate: (draft) async => stored = draft,
      ),
      onClosed: (_) => closed = true,
    );
    await tester.enterText(find.byType(TextField).first, '스터디');
    await tester.tap(find.text('템플릿으로 저장'));
    await tester.pumpAndSettle();
    expect(stored!.title, '스터디');
    expect(closed, isFalse);
  });

  testWidgets('an all-day span saved from the editor keeps every day', (
    tester,
  ) async {
    EventDraft? stored;
    await _open(
      tester,
      EventEditorDialog(
        // Ends on the US fall-back day, which has 25 hours in DST zones.
        initialDate: DateTime(2026, 10, 31),
        initialEndDate: DateTime(2026, 11, 1),
        initialAllDay: true,
        onSaveTemplate: (draft) async => stored = draft,
      ),
    );
    await tester.enterText(find.byType(TextField).first, '주말');
    await tester.tap(find.text('템플릿으로 저장'));
    await tester.pumpAndSettle();
    expect(stored!.endAt, DateTime(2026, 11, 2));
    expect(
      EventTemplate.fromDraft(stored!, id: 'w', name: '주말').endDayOffset,
      1,
    );
  });

  testWidgets('template mode hides repeat, weather and quick add', (
    tester,
  ) async {
    final seed = _template
        .draftOn(DateTime(2026, 10, 30), EventCategory.basic)
        .toEvent(id: 't1', now: DateTime(2026, 10, 30), deviceId: '');
    EventDraft? saved;
    await _open(
      tester,
      EventEditorDialog(
        initialDate: seed.startAt,
        event: seed,
        templateMode: true,
        templates: [_template],
        onQuickAdd: (_, _) async {},
        onSaveTemplate: (_) async {},
      ),
      onClosed: (draft) => saved = draft,
    );
    expect(find.text('템플릿 수정'), findsOneWidget);
    expect(find.text('반복'), findsNothing);
    expect(find.text('날씨'), findsNothing);
    expect(find.text('빠른 추가'), findsNothing);
    expect(find.text('템플릿으로 저장'), findsNothing);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(saved!.startAt, DateTime(2026, 10, 30, 19));
  });
}
