import 'dart:ui' show SemanticsAction;

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/theme/event_completion_palette.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/weekly_timetable_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monday = DateTime(2026, 9, 21);
  final weekdays = List.generate(
    5,
    (index) => monday.add(Duration(days: index)),
  );
  ClassOccurrence occurrence(
    String id,
    int start,
    int end, {
    int weekday = 1,
    LectureMode mode = LectureMode.inPerson,
    int color = 0xff2563eb,
  }) {
    final meeting = ClassMeeting(
      id: 'meeting',
      weekday: weekday,
      startMinute: start,
      endMinute: end,
      classroom: '공학관 201',
    );
    final course = TimetableClass(
      id: id,
      title: '자료구조 $id',
      meetings: [meeting],
      academicYear: 2026,
      semester: '2',
      colorValue: color,
    );
    return ClassOccurrence(
      course,
      meeting,
      monday.add(Duration(days: weekday - 1)),
      mode,
    );
  }

  Widget app({
    List<DateTime>? days,
    List<ClassOccurrence> courses = const [],
    ValueChanged<ClassOccurrence>? onOccurrenceTap,
    void Function(int, int)? onEmptySlotTap,
    bool dark = false,
    bool showDates = false,
    bool use24HourTime = true,
    bool compact = false,
    Set<String> previewCourseIds = const {},
    double textScale = 1,
    Locale locale = const Locale('ko'),
  }) => MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: dark ? DailyTheme.dark() : DailyTheme.light(),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: WeeklyTimetableGrid(
          days: days ?? weekdays,
          occurrences: courses,
          use24HourTime: use24HourTime,
          showDates: showDates,
          compact: compact,
          previewCourseIds: previewCourseIds,
          onOccurrenceTap: onOccurrenceTap ?? (_) {},
          onEmptySlotTap: onEmptySlotTap ?? (_, _) {},
        ),
      ),
    ),
  );

  testWidgets('screen reader can add an empty slot and open a class', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final course = occurrence('accessible', 600, 660);
      (int, int)? selectedSlot;
      ClassOccurrence? selectedCourse;
      await tester.pumpWidget(
        app(
          courses: [course],
          onEmptySlotTap: (day, time) => selectedSlot = (day, time),
          onOccurrenceTap: (value) => selectedCourse = value,
        ),
      );
      await tester.pumpAndSettle();
      final slotNode = tester.getSemantics(
        find.byKey(const ValueKey('timetable-slot-5-540')),
      );
      expect(
        slotNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      slotNode.owner!.performAction(slotNode.id, SemanticsAction.tap);
      expect(selectedSlot, (5, 540));
      final classNode = tester.getSemantics(
        find.byKey(ValueKey('timetable-occurrence-${course.id}')),
      );
      expect(
        classNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      classNode.owner!.performAction(classNode.id, SemanticsAction.tap);
      expect(selectedCourse, same(course));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'a 50 minute source class occupies the full hour and keeps its classroom',
    (tester) async {
      final short = occurrence('fifty', 540, 590);
      final full = occurrence('hour', 540, 600, weekday: 2);
      await tester.pumpWidget(app(courses: [short, full]));
      await tester.pumpAndSettle();
      final shortBlock = find.byKey(
        ValueKey('timetable-occurrence-${short.id}'),
      );
      final fullBlock = find.byKey(ValueKey('timetable-occurrence-${full.id}'));
      expect(
        tester.getSize(shortBlock).height,
        tester.getSize(fullBlock).height,
      );
      expect(
        find.descendant(of: shortBlock, matching: find.text('공학관 201')),
        findsOneWidget,
      );
      expect(short.meeting.toJson()['endMinute'], 590);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text in landscape retains all weekdays and scrolls class content',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(720, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final days = List.generate(
        7,
        (index) => monday.add(Duration(days: index)),
      );
      await tester.pumpWidget(
        app(
          days: days,
          courses: [
            occurrence('a', 540, 630),
            occurrence('b', 570, 630),
            occurrence('video', 600, 675, weekday: 7, mode: LectureMode.video),
          ],
          textScale: 2,
          showDates: true,
          use24HourTime: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('timetable-day-7'))).right,
        lessThanOrEqualTo(720),
      );
      await tester.drag(
        find.byKey(const ValueKey('timetable-grid-scroll')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('weekdays follow the selected locale', (tester) async {
    await tester.pumpWidget(app(locale: const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);
    expect(find.text('화'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'unsaved candidates have a readable outline and a distinct accessible label in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final saved = occurrence('saved', 540, 630);
          final preview = occurrence('preview/course', 570, 660);
          ClassOccurrence? selected;
          await tester.pumpWidget(
            app(
              courses: [saved, preview],
              dark: dark,
              previewCourseIds: {preview.course.id},
              onOccurrenceTap: (value) => selected = value,
            ),
          );
          await tester.pumpAndSettle();
          final previewFinder = find.byKey(
            ValueKey('timetable-occurrence-${preview.id}'),
          );
          final savedFinder = find.byKey(
            ValueKey('timetable-occurrence-${saved.id}'),
          );
          expect(
            tester.getSemantics(previewFinder).label,
            startsWith('추가 미리보기, 자료구조 preview/course'),
          );
          expect(
            tester.getSemantics(savedFinder).label,
            isNot(contains('추가 미리보기')),
          );
          final outline = tester.widget<Material>(
            find.byKey(
              ValueKey('timetable-preview-border-${preview.course.id}'),
            ),
          );
          final border = outline.shape! as RoundedRectangleBorder;
          expect(border.side.width, 2);
          expect(
            calendarEventContrast(border.side.color, outline.color!),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            find.byKey(
              ValueKey('timetable-preview-badge-${preview.course.id}'),
            ),
            findsOneWidget,
          );
          expect(
            tester.getRect(savedFinder).right,
            lessThanOrEqualTo(tester.getRect(previewFinder).left),
          );
          await tester.tap(previewFinder);
          expect(selected, isNull);
          expect(
            tester
                .getSemantics(previewFinder)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isFalse,
          );
          await tester.tap(savedFinder);
          expect(selected, same(saved));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'compact picker grid fits five days and keeps headers fixed when scrolled',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 180));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saved = occurrence('saved', 540, 600);
      final preview = occurrence('preview/course', 540, 660);
      await tester.pumpWidget(
        app(
          courses: [saved, preview],
          previewCourseIds: {preview.course.id},
          compact: true,
        ),
      );
      await tester.pumpAndSettle();
      for (var day = 1; day <= 5; day++) {
        expect(
          tester.getRect(find.byKey(ValueKey('timetable-day-$day'))).right,
          lessThanOrEqualTo(393),
        );
      }
      final slot = find.byKey(const ValueKey('timetable-slot-5-540'));
      expect(tester.getSize(slot).height, 22);
      final header = find.byKey(const ValueKey('timetable-day-5'));
      final before = tester.getRect(header);
      await tester.drag(
        find.byKey(const ValueKey('timetable-grid-scroll')),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(header), before);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(app(courses: [saved]));
      await tester.pumpAndSettle();
      expect(tester.getSize(slot).height, 48);
      final title = tester.widget<Text>(find.text('자료구조 saved'));
      expect(title.style!.fontSize, 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact preview preserves early and late weekend candidates at large text sizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 210));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final early = occurrence('early', 420, 470);
      final preview = occurrence('preview/late', 1380, 1440, weekday: 7);
      final days = List.generate(
        7,
        (index) => monday.add(Duration(days: index)),
      );
      await tester.pumpWidget(
        app(
          days: days,
          courses: [early, preview],
          previewCourseIds: {preview.course.id},
          compact: true,
          textScale: 2.5,
          showDates: true,
          use24HourTime: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('timetable-slot-1-420')))
            .height,
        greaterThanOrEqualTo(28),
      );
      final header = find.byKey(const ValueKey('timetable-day-7'));
      final before = tester.getRect(header);
      expect(before.right, lessThanOrEqualTo(393));
      final previewBlock = find.byKey(
        ValueKey('timetable-occurrence-${preview.id}'),
      );
      await tester.scrollUntilVisible(
        previewBlock,
        150,
        scrollable: find.byType(Scrollable),
      );
      expect(tester.getRect(header), before);
      expect(tester.getRect(previewBlock).bottom, lessThanOrEqualTo(210));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all five weekdays and Friday slots fit a phone without horizontal scrolling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      (int, int)? selected;
      await tester.pumpWidget(
        app(onEmptySlotTap: (day, minute) => selected = (day, minute)),
      );
      await tester.pumpAndSettle();
      for (var day = 1; day <= 5; day++) {
        final rect = tester.getRect(find.byKey(ValueKey('timetable-day-$day')));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(393));
      }
      final friday = find.byKey(const ValueKey('timetable-slot-5-540'));
      final fridayRect = tester.getRect(friday);
      expect(fridayRect.right, lessThanOrEqualTo(393));
      await tester.tap(friday);
      expect(selected, (5, 540));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'overlapping classes occupy separate lanes and adjacent classes use full width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = occurrence('a', 540, 630);
      final second = occurrence('b', 570, 630);
      final adjacent = occurrence('c', 630, 690);
      ClassOccurrence? selected;
      await tester.pumpWidget(
        app(
          courses: [first, second, adjacent],
          onOccurrenceTap: (value) => selected = value,
        ),
      );
      await tester.pumpAndSettle();
      Finder block(ClassOccurrence course) =>
          find.byKey(ValueKey('timetable-occurrence-${course.id}'));
      final firstRect = tester.getRect(block(first));
      final secondRect = tester.getRect(block(second));
      final adjacentRect = tester.getRect(block(adjacent));
      expect(firstRect.right, lessThanOrEqualTo(secondRect.left));
      expect(adjacentRect.width, greaterThan(firstRect.width * 1.8));
      expect(adjacentRect.top, greaterThanOrEqualTo(firstRect.bottom));
      await tester.tap(block(second));
      expect(selected, same(second));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'early and late weekend courses expand the range while day headers stay fixed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final early = occurrence('early', 420, 470);
      final late = occurrence('late', 1380, 1440, weekday: 7);
      final days = List.generate(
        7,
        (index) => monday.add(Duration(days: index)),
      );
      await tester.pumpWidget(
        app(days: days, courses: [early, late], showDates: true),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('timetable-day-7'));
      final headerBefore = tester.getRect(header);
      expect(headerBefore.right, lessThanOrEqualTo(393));
      expect(
        find.byKey(const ValueKey('timetable-slot-1-420')),
        findsOneWidget,
      );
      final lateBlock = find.byKey(ValueKey('timetable-occurrence-${late.id}'));
      await tester.scrollUntilVisible(
        lateBlock,
        400,
        scrollable: find.byType(Scrollable),
      );
      expect(tester.getRect(header), headerBefore);
      expect(tester.getRect(lateBlock).bottom, lessThanOrEqualTo(500));
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'mode icons and readable palette survive narrow blocks in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cancelled = occurrence(
          'cancelled',
          540,
          600,
          mode: LectureMode.cancelled,
          color: 0xffffff00,
        );
        final video = occurrence(
          'video',
          540,
          615,
          weekday: 2,
          mode: LectureMode.video,
          color: 0xff000000,
        );
        final short = occurrence('short', 555, 560, weekday: 3);
        await tester.pumpWidget(
          app(courses: [cancelled, video, short], dark: dark, textScale: 1.5),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.block), findsOneWidget);
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
        final title = tester.widget<Text>(find.text('자료구조 cancelled'));
        expect(title.style!.decoration, TextDecoration.lineThrough);
        final block = find.byKey(
          ValueKey('timetable-occurrence-${cancelled.id}'),
        );
        final material = tester.widget<Material>(
          find.descendant(of: block, matching: find.byType(Material)).first,
        );
        expect(
          calendarEventContrast(title.style!.color!, material.color!),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
