import 'dart:convert';
import 'dart:io';

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/theme/event_completion_palette.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fixed category dots remain distinguishable against light and dark surfaces',
    () {
      for (final theme in [DailyTheme.light(), DailyTheme.dark()]) {
        for (final category in CourseCategory.values) {
          for (final surface in [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLow,
          ]) {
            expect(
              calendarEventContrast(courseCategoryColor(category), surface),
              greaterThanOrEqualTo(3),
              reason: '${theme.brightness} ${category.name}',
            );
          }
        }
      }
    },
  );
  List<UniversityDataset> datasets() => [
    for (final campus in ['seoul', 'cheonan'])
      UniversityDataset.fromJson(
        jsonDecode(
              File(
                'assets/timetable/smu-$campus-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      ),
  ];

  test('every official section preserves its department curriculum codes', () {
    final courses = datasets().expand((d) => d.courses).toList();
    expect(courses, hasLength(2193));
    for (final course in courses) {
      expect(
        course.departmentClassifications.keys.toSet(),
        course.departments.toSet(),
        reason: course.sourceId,
      );
      expect(
        course.categoriesFor(),
        isNot(contains(CourseCategory.unknown)),
        reason: course.sourceId,
      );
      for (final meeting in course.meetings) {
        expect(meeting.startMinute % 30, 0);
        expect(meeting.endMinute % 30, 0);
        expect(
          meeting.originalStartMinute,
          greaterThanOrEqualTo(meeting.startMinute),
        );
        expect(meeting.originalEndMinute, lessThanOrEqualTo(meeting.endMinute));
      }
    }
    final crossListed = courses.singleWhere(
      (c) => c.code == 'HABH0025' && c.section == '1',
    );
    expect(crossListed.categoriesFor().toSet(), {
      CourseCategory.advancedMajor,
      CourseCategory.electiveMajor,
    });
    for (final entry in crossListed.departmentClassifications.entries) {
      expect(crossListed.categoriesFor(entry.key), [
        courseCategory(entry.value),
      ]);
    }
  });

  test(
    'all official department remarks survive, including enrollment restriction lines',
    () {
      final catalog = datasets();
      expect(
        catalog[0].courses.where((course) => course.remarks.isNotEmpty),
        hasLength(292),
      );
      expect(
        catalog[1].courses.where((course) => course.remarks.isNotEmpty),
        hasLength(438),
      );
      var nonemptyRows = 0;
      for (final course in catalog.expand((dataset) => dataset.courses)) {
        expect(
          course.departmentRemarks.keys.toSet(),
          course.departments.toSet(),
          reason: course.sourceId,
        );
        nonemptyRows += course.departmentRemarks.values
            .where((value) => value.isNotEmpty)
            .length;
      }
      expect(nonemptyRows, 835);
      final seoul = catalog[0].courses.singleWhere(
        (course) => course.code == 'HAAA6005' && course.section == '2',
      );
      expect(seoul.remarks, '1학년 이외 모든 학년학생및\n재수강학생신청 가능 분반');
      final cheonan = catalog[1].courses.singleWhere(
        (course) => course.code == 'HBHI0004' && course.section == '1',
      );
      expect(cheonan.remarks, '글로벌지역학부 1,6분반만\n신청,이중설강제선정교과목');
      final added = cheonan.toTimetable(
        id: 'chosen',
        mode: LectureMode.inPerson,
      );
      expect(added.note, cheonan.remarks);
      expect(added.defaultMode, LectureMode.inPerson);
      expect(added.sourceId, cheonan.sourceId);
      expect(TimetableClass.fromJson(added.toJson()).note, cheonan.remarks);
    },
  );

  test(
    'different department restrictions are labeled without flattening or guessing',
    () {
      final raw =
          (jsonDecode(
                    File(
                      'assets/timetable/smu-seoul-2026-2.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['courses'][0]
              as Map<String, dynamic>;
      UniversityCourse course(Map<String, String> remarks) =>
          UniversityCourse.fromJson({
            ...raw,
            'departments': remarks.keys.toList(),
            'departmentRemarks': remarks,
          });
      final distinct = course({
        '컴퓨터과학과': '신입생 전용\n재수강 신청 제한',
        '미디어학과': '미디어학과 학생 신청 가능',
        '융합학과': '',
      });
      expect(
        distinct.remarks,
        '컴퓨터과학과\n신입생 전용\n재수강 신청 제한\n\n미디어학과\n미디어학과 학생 신청 가능',
      );
      expect(distinct.remarkForDepartment('컴퓨터과학과'), '신입생 전용\n재수강 신청 제한');
      expect(distinct.remarkForDepartment('융합학과'), '');
      expect(distinct.remarkForDepartment('미등록 학과'), '');
      expect(
        course({'A': '공통 비고\n둘째 줄', 'B': '공통 비고\n둘째 줄'}).remarks,
        '공통 비고\n둘째 줄',
      );
      expect(course({'A': '', 'B': ''}).remarks, '');
      expect(
        () => distinct.departmentRemarks['컴퓨터과학과'] = '변경',
        throwsUnsupportedError,
      );
      final legacy = UniversityCourse.fromJson(
        {...raw}..remove('departmentRemarks'),
      );
      expect(legacy.remarks, '');
      expect(
        legacy.toTimetable(id: 'legacy', mode: LectureMode.video).note,
        '',
      );
    },
  );

  test(
    'search accepts course-code section, professor, classroom and Korean initials',
    () {
      final course = datasets().first.courses.singleWhere(
        (c) => c.code == 'HAAA0010' && c.section == '1',
      );
      expect(course.codeAndSection, 'HAAA0010-1');
      expect(course.title, '한국근세사');
      expect(course.matchesQuery('haaa0010-1'), isTrue);
      expect(course.matchesQuery('ㅎㄱㄱㅅㅅ'), isTrue);
      expect(course.matchesQuery('한국근세사 R107'), isTrue);
      expect(course.matchesQuery('전심'), isTrue);
      expect(course.matchesQuery('전선'), isFalse);
      expect(course.matchesQuery('haaa0010-2'), isFalse);
    },
  );

  test(
    'half-hour slot projection preserves original serialization and meeting identity',
    () {
      for (final (start, end, slotStart, slotEnd) in [
        (540, 590, 540, 600),
        (540, 615, 540, 630),
        (570, 645, 570, 660),
        (545, 601, 540, 630),
        (1380, 1430, 1380, 1440),
        (570, 600, 570, 600),
      ]) {
        final raw = <String, dynamic>{
          'id': 'original',
          'weekday': 1,
          'startMinute': start,
          'endMinute': end,
          'classroom': 'R101',
        };
        final meeting = ClassMeeting.fromJson(raw);
        expect(meeting.startMinute, slotStart);
        expect(meeting.endMinute, slotEnd);
        expect(meeting.toJson(), raw);
        expect(meeting.isValid, isTrue);
        final course = TimetableClass(
          id: 'legacy',
          title: 'Original',
          meetings: [meeting],
          academicYear: 2026,
          semester: '2',
        );
        final occurrence = classOccurrences(
          [course],
          [DateTime(2026, 9, 21)],
        ).single;
        expect(
          occurrence.start,
          DateTime(2026, 9, 21, slotStart ~/ 60, slotStart % 60),
        );
        expect(
          occurrence.end,
          DateTime(2026, 9, 21, slotEnd ~/ 60, slotEnd % 60),
        );
        expect(occurrence.id, 'timetable/legacy/original/2026-09-21');
      }
      expect(
        const ClassMeeting(
          id: 'invalid',
          weekday: 1,
          startMinute: 600,
          endMinute: 600,
        ).isValid,
        isFalse,
      );
      expect(
        const ClassMeeting(
          id: 'invalid',
          weekday: 1,
          startMinute: 1380,
          endMinute: 1441,
        ).isValid,
        isFalse,
      );
    },
  );
}
