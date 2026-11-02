import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Kookmin dated special lectures keep non-teaching weeks absent after restore',
    () {
      final rows =
          jsonDecode(
                File(
                  'test/fixtures/academic/kookmin-research-dated-courses.json',
                ).readAsStringSync(),
              )
              as List;
      final courses = rows
          .map(
            (row) => UniversityCourse.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
      for (final course in courses) {
        final restored = TimetableClass.fromJson(
          course
              .toTimetable(id: course.sourceId, mode: LectureMode.inPerson)
              .toJson(),
        );
        expect(restored.isValid, isTrue);
        expect(restored.meetings.every((m) => m.date != null), isTrue);
        final dates = restored.meetings.map((m) => m.date).toSet();
        if (course.code == '0368203') {
          expect(dates, hasLength(12));
          expect(dates, isNot(contains('2026-09-24')));
          expect(dates, isNot(contains('2026-10-22')));
          expect(dates, isNot(contains('2026-12-10')));
        } else {
          expect(dates, hasLength(13));
          expect(dates, contains('2026-09-23'));
          expect(dates, isNot(contains('2026-10-21')));
          expect(dates, isNot(contains('2026-12-09')));
        }
      }
    },
  );
  test(
    'Kookmin research fixture preserves periods through actual saved classes',
    () {
      final rows =
          jsonDecode(
                File(
                  'test/fixtures/academic/kookmin-research-courses.json',
                ).readAsStringSync(),
              )
              as List;
      final courses = rows
          .map(
            (row) => UniversityCourse.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
      expect(courses, hasLength(7));
      final ends = {
        '1231701': DateTime(2026, 10, 21),
        '0716902': DateTime(2026, 10, 23),
        '0395402': DateTime(2026, 10, 26),
      };
      for (final course in courses) {
        if (!course.hasSchedulableMeetings) continue;
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.inPerson,
        );
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue);
        if (ends.containsKey(course.code)) {
          expect(restored.period!.start, DateTime(2026, 9, 1));
          expect(restored.period!.end, ends[course.code]);
          expect(restored.period!.contains(DateTime(2026, 11, 1)), isFalse);
        }
      }
      for (final code in ['1095100', '0294104']) {
        final course = courses.singleWhere((c) => c.code == code);
        expect(course.hasSchedulableMeetings, isFalse);
        expect(course.meetings, isEmpty);
        expect(course.sourceSchedule, isNotEmpty);
        expect(course.remarks, contains('실제 적용 수업일·기간 확인 필요'));
      }
    },
  );
}
