import 'dart:convert';
import 'dart:io';

import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child, {bool dark = false}) => MaterialApp(
  locale: const Locale('ko'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: dark ? ThemeData.dark() : ThemeData.light(),
  home: Scaffold(body: child),
);

void main() {
  test('existing SMU DKU weekly rows remain unchanged in both campuses', () {
    for (final file in [
      'smu-seoul',
      'smu-cheonan',
      'dku-jukjeon',
      'dku-cheonan',
    ]) {
      final dataset = UniversityDataset.fromJson(
        jsonDecode(
              File('assets/timetable/$file-2026-2.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final course in dataset.courses) {
        final expected = <(int, int, int, String)>{};
        final rows = <ClassMeeting>[];
        for (final meeting in course.meetings) {
          if (expected.add((
            meeting.weekday,
            meeting.startMinute,
            meeting.endMinute,
            meeting.classroom,
          ))) {
            rows.add(meeting);
          }
        }
        expect(timetableDisplayMeetings(course.meetings), rows);
      }
    }
  });

  final meetings = [
    for (var week = 0; week < 15; week++)
      ClassMeeting(
        id: 'm$week',
        weekday: 3,
        startMinute: 600,
        endMinute: 710,
        classroom: 'N101',
        date: timetableDateKey(DateTime(2026, 9, 2 + week * 7)),
      ),
    const ClassMeeting(
      id: 'different-room',
      weekday: 3,
      startMinute: 600,
      endMinute: 710,
      classroom: 'N102',
      date: '2026-12-16',
    ),
    const ClassMeeting(
      id: 'different-time',
      weekday: 5,
      startMinute: 660,
      endMinute: 710,
      classroom: 'N101',
      date: '2026-09-04',
    ),
  ];
  final course = TimetableClass(
    id: 'dated',
    title: '경영학원론',
    academicYear: 2026,
    semester: '2',
    meetings: meetings,
  );

  test(
    'display deduplication preserves dates, exceptions, original clocks and restore',
    () {
      expect(timetableDisplayMeetings(meetings), hasLength(3));
      final restored = TimetableClass.fromJson(
        jsonDecode(jsonEncode(course.toJson())) as Map<String, dynamic>,
      );
      expect(
        restored.meetings.map((m) => m.toJson()),
        meetings.map((m) => m.toJson()),
      );
      expect(restored.meetings.first.originalEndMinute, 710);
      expect(
        classOccurrences([restored], [DateTime(2026, 9, 2)]),
        hasLength(1),
      );
      expect(
        classOccurrences([restored], [DateTime(2026, 12, 16)]),
        hasLength(1),
      );
      expect(classOccurrences([restored], [DateTime(2026, 12, 23)]), isEmpty);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'dated search keeps baseline compact rows and addition ($dark)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = TimetableStore(await SharedPreferences.getInstance());
        await store.selectTerm(2026, '2');
        final dataset = UniversityDataset.fromJson({
          'schemaVersion': 2,
          'universityId': 'test',
          'campus': 'main',
          'academicYear': 2026,
          'semester': '2',
          'publishedDate': '2026-09-01',
          'sourceUrl': 'https://example.test/courses',
          'courses': [
            {
              'sourceId': 'dated',
              'campus': 'main',
              'academicYear': 2026,
              'semester': '2',
              'courseCode': '00080',
              'courseName': '경영학원론',
              'section': '02',
              'professor': '남대엽',
              'credits': 3,
              'departments': ['경영학과'],
              'departmentCredits': {'경영학과': 3},
              'departmentClassifications': {'경영학과': '전선'},
              'departmentRemarks': {'경영학과': '수강 제한 비고'},
              'schedules': meetings.map((m) => m.toJson()).toList(),
            },
          ],
        });
        await tester.pumpWidget(
          app(
            UniversityCoursePanel(
              store: store,
              university: 'test',
              initialCampus: 'main',
              loadCatalog: () async => [dataset],
              onAdd: (selected, mode) async {
                await store.save(selected.toTimetable(id: 'saved', mode: mode));
                return true;
              },
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('수 10:00–12:00 · N101'), findsOneWidget);
        expect(find.text('수 10:00–12:00 · N102'), findsOneWidget);
        expect(find.text('금 11:00–12:00 · N101'), findsOneWidget);
        expect(find.text('00080-02'), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('course-card-dated')))
              .height,
          lessThan(250),
        );
        expect(find.textContaining('2026-09-02'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('dated')));
        await tester.pumpAndSettle();
        expect(find.text('수강 제한 비고'), findsOneWidget);
        final mode = find.byKey(const ValueKey('course-mode-dated'));
        await tester.ensureVisible(mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('대면 강의').last);
        await tester.pumpAndSettle();
        final add = find.text('시간표에 추가');
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(store.classes.single.meetings, hasLength(meetings.length));
        expect(
          store.classes.single.meetings.map((m) => m.date),
          meetings.map((m) => m.date),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saved details uses same weekday rows without semester date list',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = TimetableStore(await SharedPreferences.getInstance());
      late BuildContext context;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appSettingsProvider.overrideWith((_) => AppSettings())],
          child: app(
            Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final closed = showTimetableClassDetails(context, store, course);
      await tester.pumpAndSettle();
      expect(find.text('N101'), findsNWidgets(2));
      expect(find.text('N102'), findsOneWidget);
      expect(find.textContaining('2026-09-02'), findsNothing);
      expect(find.byKey(const ValueKey('class-details-edit')), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await closed;
      expect(tester.takeException(), isNull);
    },
  );
}
