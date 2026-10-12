import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UniversityDataset _dataset() => UniversityDataset.fromJson(
  jsonDecode(
        File('assets/timetable/dju-main-2026-summer.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);

void main() {
  test('disabled Daejeon is absent from the active catalog', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await UniversityCatalog.load(university: 'dju'), isEmpty);
  });

  test(
    'archived planned rows remain intact while timetable support is disabled',
    () {
      final dataset = _dataset();
      expect(dataset.courses.length, 46);
      expect(dataset.sourceNotice, contains('개설예정'));
      expect(dataset.sourceNotice, contains('2026-05-26'));
      expect(dataset.courses.where((c) => c.meetings.isNotEmpty).length, 17);
      expect(dataset.courses.where((c) => c.meetings.isEmpty).length, 29);
      final physiology = dataset.courses.singleWhere(
        (c) => c.codeAndSection == '006757-01',
      );
      expect(physiology.meetings.map((m) => m.weekday), [1, 2, 3, 4, 5]);
      expect(
        physiology.meetings.every(
          (m) =>
              m.originalStartMinute == 540 &&
              m.originalEndMinute == 720 &&
              m.classroom == '기초과학관(7호관) 7506',
        ),
        isTrue,
      );
      final remote = dataset.courses.singleWhere(
        (c) => c.codeAndSection == '013345-01',
      );
      expect(remote.sourceSchedule, '월(7),화(7),수(7),목(7),금(7)');
      expect(remote.meetings, isEmpty);
      expect(remote.scheduleStatus, 'unrecognized');
      for (final course in dataset.courses) {
        expect(course.semester, '여름');
        expect(course.remarks, contains('개설예정'));
        expect(course.period!.start, DateTime(2026, 6, 23));
        expect(course.period!.end, DateTime(2026, 7, 13));
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.inPerson,
        );
        expect(saved.note, contains('개설예정'));
        expect(
          classOccurrences(
            [saved],
            [DateTime(2026, 6, 22), DateTime(2026, 7, 14)],
          ),
          isEmpty,
        );
      }
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000095',
        universityName: '대전대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, isNull);
      expect(profile.timetableSupported, isFalse);
      expect(profile.academicSourceId, 'dju');
      expect(profile.timetableCampus, isNull);
    },
  );

  testWidgets('preliminary source notice is visible in summer search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = TimetableStore(await SharedPreferences.getInstance());
    await store.selectTerm(2026, '여름');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UniversityCoursePanel(
            store: store,
            university: 'dju',
            initialCampus: 'main',
            loadCatalog: () async => [_dataset()],
            onAdd: (_, _) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('course-source-notice')), findsOneWidget);
    expect(find.textContaining('개설예정 자료'), findsOneWidget);
    expect(find.text('대전대학교'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
