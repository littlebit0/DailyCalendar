import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<UniversityDataset>> _catalog() async => [
  UniversityDataset.fromJson({
    'schemaVersion': 1,
    'campus': 'seoul',
    'academicYear': 2026,
    'semester': '2',
    'publishedDate': '2026-09-23',
    'sourceUrl': 'https://www.smu.ac.kr/kor/life/notice.do?articleNo=767018',
    'courses': [
      for (final (id, title, day) in [
        ('data', '자료구조', 1),
        ('algorithms', '알고리즘', 2),
      ])
        {
          'sourceId': id,
          'campus': 'seoul',
          'academicYear': 2026,
          'semester': '2',
          'courseCode': id,
          'courseName': title,
          'section': '1',
          'professor': '교수',
          'credits': 3,
          'departmentCredits': {'컴퓨터과학과': 3},
          'departments': ['컴퓨터과학과'],
          'schedules': [
            {
              'weekday': day,
              'startMinute': 540,
              'endMinute': 600,
              'classroom': '강의실 101',
            },
          ],
        },
    ],
  }),
];

Future<SettingsRepository> _settings() async {
  SharedPreferences.setMockInitialValues({});
  final repo = SettingsRepository(
    preferences: await SharedPreferences.getInstance(),
  );
  await repo.timetableStore.selectTerm(2026, '2');
  return repo;
}

Widget _app(SettingsRepository repo, {double textScale = 1}) => ProviderScope(
  overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: const Locale('ko'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: DailyTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const Scaffold(body: TimetablePage(loadCatalog: _catalog)),
  ),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.ensureVisible(find.byType(UniversityCoursePanel));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('university-course-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _search => find.byKey(const ValueKey('course-search'));
EditableText _editable(WidgetTester tester) => tester.widget<EditableText>(
  find.descendant(of: _search, matching: find.byType(EditableText)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'timetable footer follows pending store acknowledgement without claiming upload success',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.text('시간표는 Google Drive로 동기화됩니다.'), findsOneWidget);
      await repo.timetableStore.renameActive('클라우드 학기');
      await tester.pumpAndSettle();
      expect(find.text('시간표 Google Drive 동기화 대기 중'), findsOneWidget);

      // This exercises the store notification only; no live Drive upload occurs.
      await repo.timetableStore.acknowledgeSyncDocument(
        repo.timetableStore.syncDocument(),
      );
      await tester.pumpAndSettle();
      expect(find.text('시간표는 Google Drive로 동기화됩니다.'), findsOneWidget);
      expect(find.text('동기화 완료'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search text and focus survive keyboard height threshold and wide layout transition',
    (tester) async {
      _viewport(tester, const Size(393, 700));
      final repo = await _settings();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-search')));
      await tester.pumpAndSettle();
      await tester.enterText(_search, '자료');
      await tester.pumpAndSettle();
      final controller = _editable(tester).controller;
      final focusNode = _editable(tester).focusNode;
      expect(focusNode.hasFocus, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      expect(_editable(tester).controller, same(controller));
      expect(controller.text, '자료');
      expect(_editable(tester).focusNode, same(focusNode));
      expect(focusNode.hasFocus, isTrue);
      expect(find.byType(UniversityCoursePanel), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.physicalSize = const Size(1000, 600);
      await tester.pumpAndSettle();
      expect(_editable(tester).controller, same(controller));
      expect(controller.text, '자료');
      expect(_editable(tester).focusNode, same(focusNode));
      expect(focusNode.hasFocus, isTrue);
      expect(find.byKey(const ValueKey('data')), findsOneWidget);
      expect(find.byKey(const ValueKey('algorithms')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'candidate, lecture mode and filters survive mobile wide and keyboard resize',
    (tester) async {
      _viewport(tester, const Size(393, 852));
      final repo = await _settings();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-search')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-filters-toggle')));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-hide-conflicts')),
      );
      await _tapVisible(tester, find.byKey(const ValueKey('data')));
      await _tapVisible(tester, find.byKey(const ValueKey('course-mode-data')));
      await tester.tap(find.text('실시간 비대면 강의').last);
      await tester.pumpAndSettle();
      final panelState = tester.state(find.byType(UniversityCoursePanel));
      expect(find.byType(UniversityCoursePage), findsOneWidget);

      tester.view.physicalSize = const Size(1000, 600);
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(UniversityCoursePanel)),
        same(panelState),
      );
      expect(find.byKey(const ValueKey('course-details-data')), findsOneWidget);
      expect(find.text('실시간 비대면 강의'), findsOneWidget);
      expect(find.byType(UniversityCoursePage), findsOneWidget);

      tester.view.physicalSize = const Size(393, 700);
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(UniversityCoursePanel)),
        same(panelState),
      );
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-data')));
      expect(
        repo.timetableStore.activeClasses.single.defaultMode,
        LectureMode.liveOnline,
      );
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-filters-toggle')),
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('course-hide-conflicts')),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320px browser with doubled text keeps add action accessible', (
    tester,
  ) async {
    _viewport(tester, const Size(320, 700));
    final repo = await _settings();
    await tester.pumpWidget(_app(repo, textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timetable-search')));
    await tester.pumpAndSettle();
    await tester.enterText(_search, '자료');
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 370);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const ValueKey('data')));
    await _tapVisible(tester, find.byKey(const ValueKey('course-mode-data')));
    await tester.tap(find.text('대면 강의').last);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const ValueKey('course-add-data')));
    expect(repo.timetableStore.activeClasses.single.title, '자료구조');
    expect(tester.takeException(), isNull);
  });
}
