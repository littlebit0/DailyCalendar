import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (campus, rowCount, sectionCount, unscheduledCount) in [
    ('jukjeon', 5900, 2722, 157),
    ('cheonan', 3251, 2562, 22),
  ]) {
    test(
      'all $campus public sections retain their data and valid meetings',
      () {
        final json =
            jsonDecode(
                  File(
                    'assets/timetable/dku-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(json);
        expect(dataset.universityId, 'dku');
        expect(dataset.campus, campus);
        expect(json['sourceRowCount'], rowCount);
        expect(dataset.courses, hasLength(sectionCount));
        expect(
          dataset.courses.where((c) => !c.hasSchedulableMeetings),
          hasLength(unscheduledCount),
        );
        final rawCourses = json['courses'] as List;
        var crossListed = 0;
        for (final (index, course) in dataset.courses.indexed) {
          final raw = rawCourses[index] as Map;
          expect(raw['universityId'], 'dku');
          expect(
            course.sourceId,
            'dku/$campus/2026/2/${course.code}/${course.section}',
          );
          expect(course.sourceSchedule, raw['sourceSchedule']);
          expect(
            course.departmentCredits.keys.toSet(),
            course.departments.toSet(),
          );
          expect(
            course.departmentClassifications.keys.toSet(),
            course.departments.toSet(),
          );
          for (final classification
              in course.departmentClassifications.values) {
            expect(
              courseCategory(classification),
              classification.isEmpty
                  ? CourseCategory.unknown
                  : isNot(CourseCategory.unknown),
              reason: '${course.sourceId}: $classification',
            );
          }
          expect(
            course.departmentRemarks.keys.toSet(),
            course.departments.toSet(),
          );
          expect(
            course.departmentCredits.values.every((v) => v == course.credits),
            isTrue,
          );
          if (course.departments.length > 1) crossListed++;
          if (!course.hasSchedulableMeetings) {
            expect(course.scheduleStatus, 'unscheduled');
            expect(course.sourceSchedule, isEmpty);
            expect(course.meetings, isEmpty);
            expect(course.matchesQuery(course.codeAndSection), isTrue);
            continue;
          }
          expect(course.scheduleStatus, 'scheduled');
          expect(course.sourceSchedule, isNotEmpty);
          expect(course.meetings.every((meeting) => meeting.isValid), isTrue);
          for (final (meetingIndex, meeting) in course.meetings.indexed) {
            final source = (raw['schedules'] as List)[meetingIndex] as Map;
            expect(meeting.originalStartMinute, source['startMinute']);
            expect(meeting.originalEndMinute, source['endMinute']);
            expect(meeting.startMinute % 30, 0);
            expect(meeting.endMinute % 30, 0);
          }
          final added = course.toTimetable(
            id: 'course-$index',
            mode: LectureMode.inPerson,
          );
          expect(added.isValid, isTrue, reason: course.sourceId);
          expect(added.sourceId, course.sourceId);
          expect(added.note, course.remarks);
          expect(added.defaultMode, LectureMode.inPerson);
          final reloaded = TimetableClass.fromJson(added.toJson());
          expect(reloaded.isValid, isTrue);
          expect(reloaded.note, course.remarks);
          expect(
            reloaded.meetings.map((m) => m.toJson()),
            added.meetings.map((m) => m.toJson()),
          );
        }
        expect(crossListed, greaterThan(0));
      },
    );
  }

  test(
    'host departments keep their college while convergence majors stay grouped',
    () {
      final mappings =
          (jsonDecode(
                    File(
                      'assets/timetable/organizations/dku.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['mappings']
              as List;
      Map<String, dynamic> mapping(String label, String campus) =>
          mappings.cast<Map<String, dynamic>>().singleWhere(
            (m) => m['sourceLabel'] == label && m['campus'] == campus,
          );
      for (final (label, campus, college) in [
        ('공공인재대학 / 공공정책학과', 'cheonan', '공공인재대학'),
        ('과학기술대학 / 수학과', 'cheonan', '과학기술대학'),
        ('과학기술대학 / 제약공학과', 'cheonan', '과학기술대학'),
        ('과학기술대학 / 화학과', 'cheonan', '과학기술대학'),
        ('바이오융합대학 / 의생명과학부 생명과학전공', 'cheonan', '바이오융합대학'),
        ('경영경제대학 / 경영학부 경영학전공', 'jukjeon', '경영경제대학'),
        ('경영경제대학 / 무역학과', 'jukjeon', '경영경제대학'),
        ('사회과학대학 / 행정학과', 'jukjeon', '사회과학대학'),
      ]) {
        final entry = mapping(label, campus);
        expect(entry['college'], college, reason: label);
        expect(entry['group'], isNull, reason: label);
      }
      // Genuine convergence programs keep their own group.
      expect(
        mappings.cast<Map<String, dynamic>>().any((m) => m['group'] == '융합전공'),
        isTrue,
      );
    },
  );
}
