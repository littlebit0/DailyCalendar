import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Sunmoon public subset keeps actual clocks, closure exclusions and blank fields',
    () {
      const path = 'assets/timetable/sunmoon-unknown-2026-2.json';
      final raw =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final dataset = UniversityDataset.fromJson(raw);
      expect(dataset.courses.length, 10);
      expect(dataset.campus, 'unknown');
      expect(dataset.courses.where((c) => c.meetings.isNotEmpty).length, 7);
      final recorded = dataset.courses
          .where((c) => c.meetings.isEmpty)
          .toList();
      expect(recorded.length, 3);
      expect(recorded.every((c) => c.scheduleStatus == 'unscheduled'), isTrue);
      expect(recorded.every((c) => c.code.isEmpty), isTrue);
      final english = dataset.courses.singleWhere((c) => c.code == '053510');
      expect(english.codeAndSection, '053510-14');
      expect(english.categoriesFor(), [
        CourseCategory.requiredGeneralEducation,
      ]);
      expect(english.meetings.single.originalStartMinute, 750);
      expect(english.meetings.single.originalEndMinute, 860);
      expect(english.meetings.single.classroom, isEmpty);
      final programming = dataset.courses.singleWhere(
        (c) => c.code == '210116',
      );
      expect(
        programming.meetings.map(
          (m) => (m.weekday, m.originalStartMinute, m.originalEndMinute),
        ),
        [(2, 570, 620), (4, 570, 680)],
      );
      expect(programming.classificationLabelsFor(), isEmpty);
      expect(
        dataset.courses.any(
          (c) => ['080168', '053511', '080167'].contains(c.code),
        ),
        isFalse,
      );
      final uncoded = dataset.courses.singleWhere(
        (c) => c.title == '디지털 사회와 범죄',
      );
      expect(uncoded.codeAndSection, isEmpty);
      expect(uncoded.meetings.single.originalStartMinute, 870);
      expect(uncoded.meetings.single.originalEndMinute, 1040);
      for (final row in raw['courses'] as List) {
        expect(row['rowEvidence'], isNotEmpty);
        expect(row['periodEvidence'], isNotEmpty);
      }
      for (final course in dataset.courses) {
        expect(course.period!.start, DateTime(2026, 9, 1));
        expect(course.period!.end, DateTime(2026, 12, 14));
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.inPerson,
        );
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(
          classOccurrences(
            [restored],
            [DateTime(2026, 8, 31), DateTime(2026, 12, 15)],
          ),
          isEmpty,
        );
        expect(
          restored.meetings.map((m) => m.toJson()),
          saved.meetings.map((m) => m.toJson()),
        );
      }
      expect(
        (jsonDecode(File('assets/timetable/catalog.json').readAsStringSync())
                as List)
            .where((p) => p == path)
            .length,
        1,
      );
      final periods =
          jsonDecode(
                File('assets/timetable/term-periods.json').readAsStringSync(),
              )
              as Map;
      final school = (periods['additionalUniversities'] as List).singleWhere(
        (s) => s['university'] == 'sunmoon',
      );
      expect(school['terms'].single['start'], '2026-09-01');
      expect(school['terms'].single['end'], '2026-12-14');
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000129',
        universityName: '선문대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'sunmoon');
      expect(profile.timetableCampus, 'unknown');
    },
  );
}
