import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<TimetableStore> store() async {
    SharedPreferences.setMockInitialValues({});
    final result = TimetableStore(await SharedPreferences.getInstance());
    await result.selectTerm(2026, '2');
    return result;
  }

  final dataset = UniversityDataset.fromJson({
    'schemaVersion': 1,
    'campus': 'seoul',
    'academicYear': 2026,
    'semester': '2',
    'publishedDate': '2026-09-23',
    'sourceUrl': 'https://www.smu.ac.kr',
    'courses': [
      for (final (code, weekday, start, end) in [
        ('A', 1, 540, 600),
        ('B', 1, 600, 660),
        ('C', 1, 570, 630),
        ('D', 2, 540, 600),
      ])
        {
          'sourceId': code,
          'campus': 'seoul',
          'academicYear': 2026,
          'semester': '2',
          'courseCode': code,
          'courseName': 'Course $code',
          'section': '1',
          'professor': 'Professor',
          'credits': 3,
          'departmentCredits': {'Department': 3},
          'departments': ['Department'],
          'schedules': [
            {
              'weekday': weekday,
              'startMinute': start,
              'endMinute': end,
              'classroom': 'R101',
            },
          ],
        },
    ],
  });

  Widget app(
    TimetableStore store, {
    bool dark = false,
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
    home: UniversityCoursePage(
      store: store,
      loadCatalog: () async => [dataset],
    ),
  );

  testWidgets(
    'conflict filter respects boundaries, weekdays, term and recorded lectures',
    (tester) async {
      final saved = await store();
      await saved.save(
        TimetableClass(
          id: 'existing',
          title: 'Existing class',
          academicYear: 2026,
          semester: '2',
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await saved.save(
        TimetableClass(
          id: 'other-semester',
          title: 'Other semester',
          academicYear: 2026,
          semester: '1',
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 600, endMinute: 660),
          ],
        ),
      );
      await saved.save(
        TimetableClass(
          id: 'recorded',
          title: 'Recorded class',
          academicYear: 2026,
          semester: '2',
          defaultMode: LectureMode.video,
          meetings: const [
            ClassMeeting(id: 'm', weekday: 2, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await tester.pumpWidget(app(saved));
      await tester.pumpAndSettle();
      expect(find.text('수업 4개'), findsOneWidget);
      final first = find.byKey(const ValueKey('A'));
      expect(tester.widget<ListTile>(first).onTap, isNotNull);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.text('시간 겹침: Existing class'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<LectureMode>), findsOneWidget);
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('course-filters-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-filters-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('course-hide-conflicts')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-hide-conflicts')));
      await tester.pumpAndSettle();
      expect(find.text('수업 2개'), findsOneWidget);
      expect(find.byKey(const ValueKey('A')), findsNothing);
      expect(find.byKey(const ValueKey('B')), findsOneWidget);
      expect(find.byKey(const ValueKey('D')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('course-search')),
        'Course A',
      );
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
      await tester.tap(find.text('검색 조건 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('수업 4개'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('course-hide-conflicts')),
            )
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'added course remains visible with conflict filter and cannot be duplicated',
    (tester) async {
      final saved = await store();
      await saved.save(
        dataset.courses.first.toTimetable(
          id: 'saved',
          mode: LectureMode.inPerson,
        ),
      );
      await tester.pumpWidget(app(saved));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-filters-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('course-hide-conflicts')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-hide-conflicts')));
      await tester.pumpAndSettle();
      expect(find.text('수업 3개'), findsOneWidget);
      final first = find.byKey(const ValueKey('A'));
      expect(tester.widget<ListTile>(first).onTap, isNotNull);
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('course-details-A')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('course-add-A')))
            .onPressed,
        isNull,
      );
      expect(find.text('추가됨'), findsWidgets);
      expect(
        saved.activeClasses.where((course) => course.sourceId == 'A'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, dark) in [
    (const Size(320, 568), false),
    (const Size(568, 320), true),
  ]) {
    testWidgets('catalog remains scrollable with keyboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final saved = await store();
      await tester.pumpWidget(
        app(saved, dark: dark, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('course-search')),
        'no matching course',
      );
      await tester.pumpAndSettle();
      final searchTop = tester
          .getTopLeft(find.byKey(const ValueKey('course-search')))
          .dy;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No search results.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('course-search'))).dy,
        closeTo(searchTop, .01),
      );
      expect(
        find.byKey(const ValueKey('course-search')).hitTestable(),
        findsOneWidget,
      );
    });
  }
}
