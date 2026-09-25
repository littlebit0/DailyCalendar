import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> source(String campus) =>
    jsonDecode(
          File('assets/timetable/jnu-$campus-2026-2.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  for (final (campus, rows, total, scheduled, unrecognized, unscheduled) in [
    ('gwangju', 16871, 3166, 3072, 93, 1),
    ('yeosu', 3344, 696, 662, 34, 0),
  ]) {
    test('all $campus public courses survive catalog import and round trip', () {
      final raw = source(campus);
      final dataset = UniversityDataset.fromJson(raw);
      expect(dataset.university, 'jnu');
      expect(dataset.campus, campus);
      expect(raw['sourceRowCount'], rows);
      expect(raw['sourceQueryCount'], 575);
      expect(dataset.courses, hasLength(total));
      expect(dataset.courses.map((c) => c.sourceId).toSet(), hasLength(total));
      expect(
        dataset.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(scheduled),
      );
      expect(
        dataset.courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(unrecognized),
      );
      expect(
        dataset.courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(unscheduled),
      );

      for (final (index, course) in dataset.courses.indexed) {
        final original = (raw['courses'] as List)[index] as Map;
        expect(
          course.sourceId,
          'jnu-$campus-2026-2-${course.code}-${course.section}',
        );
        expect(course.sourceSchedule, original['sourceSchedule']);
        expect(course.sourceClassroom, original['sourceClassroom']);
        expect(
          course.departmentCredits.keys.toSet(),
          course.departments.toSet(),
        );
        expect(
          course.departmentClassifications.keys.toSet(),
          course.departments.toSet(),
        );
        expect(
          course.departmentRemarks.keys.toSet(),
          course.departments.toSet(),
        );
        expect(
          course.categoriesFor(),
          isNot(contains(CourseCategory.unknown)),
          reason: course.sourceId,
        );
        expect(course.matchesQuery(course.codeAndSection), isTrue);
        if (!course.hasSchedulableMeetings) {
          expect(course.meetings, isEmpty);
          expect(course.scheduleStatus, anyOf('unrecognized', 'unscheduled'));
          if (course.scheduleStatus == 'unrecognized') {
            expect(course.sourceSchedule, isNotEmpty);
          } else {
            expect(course.sourceSchedule, isEmpty);
          }
          // Only courses with verified meetings enter the add/round-trip path.
          continue;
        }
        expect(course.scheduleStatus, 'scheduled');
        for (final (meetingIndex, meeting) in course.meetings.indexed) {
          final originalMeeting =
              (original['schedules'] as List)[meetingIndex] as Map;
          expect(meeting.originalStartMinute, originalMeeting['startMinute']);
          expect(meeting.originalEndMinute, originalMeeting['endMinute']);
          expect(meeting.startMinute % 30, 0);
          expect(meeting.endMinute % 30, 0);
          expect(meeting.isValid, isTrue);
        }
        final added = course.toTimetable(
          id: 'course-$index',
          mode: LectureMode.inPerson,
        );
        expect(added.isValid, isTrue, reason: course.sourceId);
        expect(added.note, course.remarks);
        expect(added.sourceId, course.sourceId);
        final reloaded = TimetableClass.fromJson(added.toJson());
        expect(reloaded.isValid, isTrue);
        expect(reloaded.note, course.remarks);
        expect(
          reloaded.meetings.map((m) => m.toJson()),
          added.meetings.map((m) => m.toJson()),
        );
      }
    });
  }

  test(
    'official ambiguous tokens stay searchable while verified Saturday adds',
    () {
      final courses = UniversityDataset.fromJson(source('gwangju')).courses;
      final ambiguous = courses.singleWhere(
        (c) => c.code == 'JAU0002' && c.section == '1',
      );
      expect(ambiguous.sourceSchedule, '****');
      expect(ambiguous.scheduleStatus, 'unrecognized');
      expect(ambiguous.hasSchedulableMeetings, isFalse);
      expect(ambiguous.matchesQuery('자유과제2'), isTrue);

      final late = courses.singleWhere(
        (c) => c.code == 'BIO3078' && c.section == '1',
      );
      expect(late.sourceSchedule, '수10수11수12수13');
      expect(late.scheduleStatus, 'unrecognized');
      expect(late.meetings, isEmpty);

      final saturday = courses.singleWhere(
        (c) => c.code == 'HRT4038' && c.section == '1',
      );
      expect(saturday.sourceSchedule, '토0토1토2토3');
      expect(saturday.hasSchedulableMeetings, isTrue);
      expect(saturday.meetings.single.weekday, DateTime.saturday);
      expect(saturday.meetings.single.originalStartMinute, 480);
      expect(saturday.meetings.single.originalEndMinute, 710);
      expect(saturday.meetings.single.endMinute, 720);
    },
  );

  test('empty course meetings require explicit source status', () {
    final raw = (source('gwangju')['courses'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere(
          (c) => c['courseCode'] == 'KTM2073' && c['section'] == '5',
        );
    expect(UniversityCourse.fromJson(raw).scheduleStatus, 'unscheduled');
    expect(
      () => UniversityCourse.fromJson({...raw}..remove('scheduleStatus')),
      throwsFormatException,
    );
    expect(
      () => UniversityCourse.fromJson({...raw, 'scheduleStatus': 'scheduled'}),
      throwsFormatException,
    );
  });
}
