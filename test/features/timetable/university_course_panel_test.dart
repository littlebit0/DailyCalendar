import 'dart:async';

import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _course(
  String id,
  String title, {
  String campus = 'seoul',
  int weekday = 1,
  int start = 540,
  int end = 600,
  List<String> departments = const ['컴퓨터과학과'],
  bool varyingCredits = false,
  String classification = '1전선',
  Map<String, String> remarks = const {},
}) => {
  'sourceId': id,
  'campus': campus,
  'academicYear': 2026,
  'semester': '2',
  'courseCode': id,
  'courseName': title,
  'section': '1',
  'professor': '담당 교수',
  'credits': varyingCredits ? null : 3,
  'departmentCredits': {
    for (final (index, department) in departments.indexed)
      department: varyingCredits ? index + 2 : 3,
  },
  'departments': departments,
  'departmentRemarks': remarks,
  'departmentClassifications': {
    for (final department in departments) department: classification,
  },
  'schedules': [
    {
      'weekday': weekday,
      'startMinute': start,
      'endMinute': end,
      'classroom': '강의실 101',
    },
  ],
};

const _longRemark =
    '수강 대상과 사전 준비 사항을 확인해 주세요. 수업 전 자료를 읽고 실습 환경을 준비해야 합니다. 수업 내용과 과제 안내는 해당 학과 공지에서 확인할 수 있으며 이 안내는 줄임표 없이 끝까지 표시되어야 합니다.\n마지막 안내: 준비물을 반드시 확인하세요.';

List<UniversityDataset> _catalog() => [
  UniversityDataset.fromJson({
    'schemaVersion': 1,
    'campus': 'seoul',
    'academicYear': 2026,
    'semester': '2',
    'publishedDate': '2026-09-23',
    'sourceUrl': 'https://www.smu.ac.kr/kor/life/notice.do?articleNo=767018',
    'courses': [
      _course(
        'alpha',
        '알고리즘',
        classification: '1전심',
        remarks: {'컴퓨터과학과': _longRemark},
      ),
      _course('boundary', '자료구조', start: 600, end: 660),
      _course('video', '운영체제', weekday: 2, classification: '교선'),
      _course(
        'cross',
        '미디어 수업',
        weekday: 3,
        departments: ['컴퓨터과학과', '미디어학과'],
        varyingCredits: true,
        remarks: {'컴퓨터과학과': '컴퓨터과학과 수강 안내', '미디어학과': '미디어학과 별도 준비 사항'},
      ),
    ],
  }),
  UniversityDataset.fromJson({
    'schemaVersion': 1,
    'campus': 'cheonan',
    'academicYear': 2026,
    'semester': '2',
    'publishedDate': '2026-09-18',
    'sourceUrl': 'https://www.smu.ac.kr/kor/life/notice.do?articleNo=767028',
    'courses': [
      _course('cheonan', '천안 수업', campus: 'cheonan', departments: ['천안학과']),
    ],
  }),
];

Future<TimetableStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final store = TimetableStore(await SharedPreferences.getInstance());
  await store.selectTerm(2026, '2');
  return store;
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  locale: const Locale('ko'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('university-course-panel')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 160, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'university filters isolate equally named campuses and preserve untimed course details',
    (tester) async {
      final store = await _store();
      final raw = _course(
        'dku-untimed',
        '단국 시간 미지정 강의',
        campus: 'cheonan',
        classification: '전필',
      );
      raw['schedules'] = <Object>[];
      raw['scheduleStatus'] = 'unscheduled';
      raw['sourceSchedule'] = '공식 시간 미지정';
      raw['sourceClassroom'] = '공학관 101';
      raw['departmentRemarks'] = {'컴퓨터과학과': '학과에 수강 가능 여부 확인'};
      final dankook = UniversityDataset.fromJson({
        'schemaVersion': 1,
        'universityId': 'dku',
        'campus': 'cheonan',
        'academicYear': 2026,
        'semester': '2',
        'publishedDate': '2026-09-26',
        'sourceUrl': 'https://webinfo.dankook.ac.kr',
        'courses': [raw],
      });
      var additions = 0;
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            university: 'dku',
            initialCampus: 'cheonan',
            loadCatalog: () async => [..._catalog(), dankook],
            onAdd: (_, _) async {
              additions++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('단국대학교'), findsOneWidget);
      expect(find.text('상명대학교'), findsNothing);
      expect(find.text('단국 시간 미지정 강의'), findsOneWidget);
      expect(find.text('천안 수업'), findsNothing);
      expect(find.text('시간 확인 필요'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('dku-untimed')));
      expect(find.text('공식 시간 미지정'), findsOneWidget);
      expect(find.text('공학관 101'), findsOneWidget);
      expect(find.text('학과에 수강 가능 여부 확인'), findsOneWidget);
      final add = find.byKey(const ValueKey('course-add-dku-untimed'));
      await tester.ensureVisible(add);
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('course-mode-dku-untimed')),
        findsNothing,
      );
      expect(additions, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'curriculum filters and code-section metadata remain distinct from titles',
    (tester) async {
      final store = await _store();
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onAdd: (_, _) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title =
          tester.widget<ListTile>(find.byKey(const ValueKey('alpha'))).title!
              as Text;
      expect(title.data, '알고리즘');
      expect(find.text('alpha-1'), findsOneWidget);
      expect(find.textContaining('알고리즘 ·'), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-category-advancedMajor')),
      );
      expect(find.text('수업 1개'), findsOneWidget);
      expect(find.byKey(const ValueKey('alpha')), findsOneWidget);
      expect(find.byKey(const ValueKey('boundary')), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-category-generalEducation')),
      );
      expect(find.text('수업 1개'), findsOneWidget);
      expect(find.byKey(const ValueKey('video')), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-category-all')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('course-search')),
        'ㅇㄱㄹㅈ',
      );
      await tester.pumpAndSettle();
      expect(find.text('수업 1개'), findsOneWidget);
      expect(find.byKey(const ValueKey('alpha')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile campus is a default and switching campuses retains query and saved classes while resetting department',
    (tester) async {
      final store = await _store();
      await store.save(
        _catalog().first.courses.first.toTimetable(
          id: 'seoul-saved',
          mode: LectureMode.inPerson,
        ),
      );
      final savedBefore = store.classes.single.toJson();
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            initialCampus: 'cheonan',
            loadCatalog: () async => _catalog(),
            onAdd: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final campus = find.byKey(const ValueKey('course-campus'));
      expect(campus.hitTestable(), findsOneWidget);
      expect(tester.widget<DropdownButton<String>>(campus).value, 'cheonan');
      expect(find.byKey(const ValueKey('cheonan')), findsOneWidget);
      expect(find.byKey(const ValueKey('alpha')), findsNothing);
      await _tapVisible(tester, campus);
      await tester.tap(find.text('서울캠퍼스').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('course-search')), '담당');
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-filters-toggle')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-department-seoul-null')),
      );
      await tester.tap(find.text('컴퓨터과학과').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('course-department-seoul-컴퓨터과학과')),
        findsOneWidget,
      );
      await _tapVisible(tester, campus);
      await tester.tap(find.text('천안캠퍼스').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<String>>(campus).value, 'cheonan');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('course-search')))
            .controller!
            .text,
        '담당',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('course-department-cheonan-null')),
            )
            .initialValue,
        '',
      );
      expect(find.byKey(const ValueKey('cheonan')), findsOneWidget);
      expect(store.classes.single.toJson(), savedBefore);
      await _tapVisible(tester, campus);
      await tester.tap(find.text('서울캠퍼스').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<String>>(campus).value, 'seoul');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('course-search')))
            .controller!
            .text,
        '담당',
      );
      expect(find.byKey(const ValueKey('alpha')), findsOneWidget);
      expect(store.classes.single.toJson(), savedBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search stays fixed and editable after scrolling a long catalog and expanding a later row',
    (tester) async {
      tester.view.physicalSize = const Size(393, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await _store();
      final catalog = UniversityDataset.fromJson({
        'schemaVersion': 1,
        'campus': 'seoul',
        'academicYear': 2026,
        'semester': '2',
        'publishedDate': '2026-09-23',
        'sourceUrl': 'https://www.smu.ac.kr',
        'courses': [
          for (var i = 0; i < 50; i++)
            _course('scroll-$i', '스크롤 강의 $i', remarks: {'컴퓨터과학과': _longRemark}),
        ],
      });
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            initialCampus: 'seoul',
            loadCatalog: () async => [catalog],
            onAdd: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('course-search'));
      await tester.enterText(search, '스크롤');
      await tester.pumpAndSettle();
      final originalTop = tester.getTopLeft(search).dy;
      final originalController = tester.widget<TextField>(search).controller;
      final results = find
          .descendant(
            of: find.byKey(const ValueKey('university-course-panel')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('scroll-20')),
        400,
        scrollable: results,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(search).dy, closeTo(originalTop, .01));
      expect(search.hitTestable(), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('scroll-20')));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-add-scroll-20')),
      );
      expect(find.text('강의 방식을 직접 선택해 주세요.'), findsOneWidget);
      expect(tester.getTopLeft(search).dy, closeTo(originalTop, .01));
      expect(search.hitTestable(), findsOneWidget);
      expect(
        tester.widget<TextField>(search).controller,
        same(originalController),
      );
      await tester.enterText(search, '스크롤 강의 49');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scroll-49')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('course-details-scroll-20')),
        findsNothing,
      );
      expect(tester.getTopLeft(search).dy, closeTo(originalTop, .01));
      expect(search.hitTestable(), findsOneWidget);
      expect(store.classes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline expanded result requires mode and keeps readable details after adding',
    (tester) async {
      final store = await _store();
      final previews = <UniversityCourse?>[];
      final receivedModes = <LectureMode>[];
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onPreviewChanged: previews.add,
            onAdd: (course, mode) async {
              receivedModes.add(mode);
              await store.save(course.toTimetable(id: 'saved', mode: mode));
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('alpha')));
      await tester.pumpAndSettle();
      expect(previews.single?.sourceId, 'alpha');
      expect(store.classes, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('course-add-dialog')), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.byKey(const ValueKey('course-details-alpha')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('course-search')), findsOneWidget);
      expect(
        ModalRoute.of(
          tester.element(find.byKey(const ValueKey('course-details-alpha'))),
        ),
        same(ModalRoute.of(tester.element(find.byType(UniversityCoursePanel)))),
      );
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-alpha')));
      expect(find.text('강의 방식을 직접 선택해 주세요.'), findsOneWidget);
      expect(receivedModes, isEmpty);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-mode-alpha')),
      );
      await tester.tap(find.text('실시간 비대면 강의').last);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-alpha')));
      expect(receivedModes, [LectureMode.liveOnline]);
      expect(store.classes.single.defaultMode, LectureMode.liveOnline);
      expect(previews.last, isNull);
      expect(
        find.byKey(const ValueKey('course-details-alpha')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('course-add-alpha')),
            )
            .onPressed,
        isNull,
      );
      expect(store.classes.single.note, _longRemark);
      expect(
        tester.widget<ListTile>(find.byKey(const ValueKey('alpha'))).onTap,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed direct addition retains candidate and selected mode for retry',
    (tester) async {
      final store = await _store();
      var attempts = 0;
      final previews = <UniversityCourse?>[];
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onPreviewChanged: previews.add,
            onAdd: (course, mode) async {
              attempts++;
              if (attempts == 1) return false;
              await store.save(course.toTimetable(id: 'saved', mode: mode));
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('alpha')));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-mode-alpha')),
      );
      await tester.tap(find.text('대면 강의').last);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-alpha')));
      expect(find.text('강의를 추가하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
      expect(store.classes, isEmpty);
      expect(previews.length, 1);
      expect(find.text('대면 강의'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-alpha')));
      expect(attempts, 2);
      expect(store.classes.single.sourceId, 'alpha');
      expect(previews.last, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-row collapse and filtering clear selection without saving',
    (tester) async {
      final store = await _store();
      final previews = <UniversityCourse?>[];
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onPreviewChanged: previews.add,
            onAdd: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('alpha')));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('alpha')));
      expect(find.byKey(const ValueKey('course-details-alpha')), findsNothing);
      expect(store.classes, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('course-search')), '자료');
      await tester.pumpAndSettle();
      expect(previews.last, isNull);
      expect(find.byKey(const ValueKey('alpha')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('boundary')));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('boundary')));
      expect(
        find.byKey(const ValueKey('course-details-boundary')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('course-filters-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-campus')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('천안캠퍼스').last);
      await tester.pumpAndSettle();
      expect(previews.last, isNull);
      await tester.enterText(find.byKey(const ValueKey('course-search')), '');
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('cheonan')));
      expect(previews.last?.sourceId, 'cheonan');
      await _tapVisible(tester, find.byKey(const ValueKey('cheonan')));
      await store.selectTerm(2026, '1');
      await tester.pumpAndSettle();
      expect(previews.last, isNull);
      expect(
        find.text('선택한 학기의 학교 데이터가 없습니다. 직접 수업을 추가할 수 있습니다.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only one row expands and choosing another row resets lecture mode',
    (tester) async {
      final store = await _store();
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onAdd: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('alpha')));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-mode-alpha')),
      );
      await tester.tap(find.text('대면 강의').last);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('boundary')));
      expect(find.byKey(const ValueKey('course-details-alpha')), findsNothing);
      expect(
        find.byKey(const ValueKey('course-details-boundary')),
        findsOneWidget,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-add-boundary')),
      );
      expect(find.text('강의 방식을 직접 선택해 주세요.'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('boundary')));
      expect(
        find.byKey(const ValueKey('course-details-boundary')),
        findsNothing,
      );
      expect(store.classes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px double text and keyboard keep full remarks and retry controls reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = await _store();
      var attempts = 0;
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onAdd: (course, mode) async {
              if (++attempts == 1) return false;
              await store.save(
                course.toTimetable(id: 'saved-remarks', mode: mode),
              );
              return true;
            },
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('course-search')), '알고');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('alpha')));
      final remark = find.text(_longRemark);
      expect(remark, findsOneWidget);
      expect(tester.widget<Text>(remark).maxLines, isNull);
      expect(
        tester.widget<Text>(remark).overflow,
        isNot(TextOverflow.ellipsis),
      );
      expect(
        tester.renderObject<RenderParagraph>(remark).didExceedMaxLines,
        isFalse,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-mode-alpha')),
      );
      await tester.tap(find.text('대면 강의').last);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-alpha')));
      expect(find.text('강의를 추가하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('대면 강의'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-alpha')));
      expect(attempts, 2);
      expect(store.classes.single.note, _longRemark);
      expect(
        find.byKey(const ValueKey('course-details-alpha')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saving inline course blocks navigation and repeated additions until persistence finishes',
    (tester) async {
      final store = await _store();
      final finish = Completer<void>();
      addTearDown(() {
        if (!finish.isCompleted) finish.complete();
      });
      var attempts = 0;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-search'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Search route')),
                    body: UniversityCoursePanel(
                      store: store,
                      loadCatalog: () async => _catalog(),
                      onAdd: (course, mode) async {
                        attempts++;
                        await finish.future;
                        await store.save(
                          course.toTimetable(id: 'saved-once', mode: mode),
                        );
                        return true;
                      },
                    ),
                  ),
                ),
              ),
              child: const Text('Open search'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-search')));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('alpha')));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-mode-alpha')),
      );
      await tester.tap(find.text('대면 강의').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('course-add-alpha')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-add-alpha')));
      // A second tap before the disabled-state frame must still save only once.
      await tester.tap(
        find.byKey(const ValueKey('course-add-alpha')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(attempts, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('course-add-alpha')),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(UniversityCoursePanel), findsOneWidget);
      expect(store.classes, isEmpty);
      finish.complete();
      await tester.pumpAndSettle();
      expect(store.classes, hasLength(1));
      expect(attempts, 1);
      expect(
        find.byKey(const ValueKey('course-details-alpha')),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(UniversityCoursePanel), findsNothing);
      expect(find.byKey(const ValueKey('open-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected row keeps lecture mode when external conflict filtering removes a preceding row',
    (tester) async {
      final store = await _store();
      final receivedModes = <LectureMode>[];
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onAdd: (course, mode) async {
              receivedModes.add(mode);
              await store.save(
                course.toTimetable(id: 'saved-boundary', mode: mode),
              );
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-filters-toggle')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-hide-conflicts')),
      );
      await _tapVisible(tester, find.byKey(const ValueKey('boundary')));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-mode-boundary')),
      );
      await tester.tap(find.text('실시간 비대면 강의').last);
      await tester.pumpAndSettle();
      await store.save(
        TimetableClass(
          id: 'external',
          title: '외부 변경 수업',
          academicYear: 2026,
          semester: '2',
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('alpha')), findsNothing);
      expect(
        find.byKey(const ValueKey('course-details-boundary')),
        findsOneWidget,
      );
      expect(find.text('실시간 비대면 강의'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('course-add-boundary')),
      );
      expect(receivedModes, [LectureMode.liveOnline]);
      expect(
        store.activeClasses
            .where((course) => course.sourceId == 'boundary')
            .single
            .defaultMode,
        LectureMode.liveOnline,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'conflict filter is strict at boundaries and ignores saved video classes',
    (tester) async {
      final store = await _store();
      await store.save(
        TimetableClass(
          id: 'busy',
          title: '기존 강의',
          academicYear: 2026,
          semester: '2',
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await store.save(
        TimetableClass(
          id: 'recorded',
          title: '영상 강의',
          academicYear: 2026,
          semester: '2',
          defaultMode: LectureMode.video,
          meetings: const [
            ClassMeeting(id: 'm', weekday: 2, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onAdd: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-filters-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-hide-conflicts')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('alpha')), findsNothing);
      expect(find.byKey(const ValueKey('boundary')), findsOneWidget);
      expect(find.byKey(const ValueKey('video')), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('cross')));
      expect(find.text('학과별 학점이 다릅니다. 원문을 확인해 주세요.'), findsOneWidget);
      expect(find.text('컴퓨터과학과: 2'), findsOneWidget);
      expect(find.text('미디어학과: 3'), findsOneWidget);
      expect(find.textContaining('컴퓨터과학과 수강 안내'), findsOneWidget);
      expect(find.textContaining('미디어학과 별도 준비 사항'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short embedded panel keeps search and results scrollable with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(393, 260);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = await _store();
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async => _catalog(),
            onAdd: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('course-search')), '알고');
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const ValueKey('alpha')));
      await _tapVisible(tester, find.byKey(const ValueKey('course-add-alpha')));
      expect(find.text('강의 방식을 직접 선택해 주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalog errors offer retry without silently showing empty results',
    (tester) async {
      final store = await _store();
      var attempts = 0;
      await tester.pumpWidget(
        _app(
          UniversityCoursePanel(
            store: store,
            loadCatalog: () async {
              if (++attempts == 1) {
                throw const FormatException('Invalid catalog');
              }
              return _catalog();
            },
            onAdd: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('강의 목록을 불러오지 못했습니다.'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('alpha')), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
