import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WSU public general offerings preserve native gaps and semester bounds', () {
    final raw = jsonDecode(
      File('assets/timetable/wsu-ecis-sis-2026-2.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final dataset = UniversityDataset.fromJson(raw);
    final prior = UniversityDataset.fromJson(
      jsonDecode(File('assets/timetable/wsu-unknown-2026-2.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(dataset.courses, hasLength(121));
    expect(prior.courses, hasLength(19));
    expect(dataset.courses.where((c) => c.hasSchedulableMeetings), hasLength(101));
    expect(dataset.courses.where((c) => c.scheduleStatus == 'unrecognized'), hasLength(13));
    expect(dataset.courses.where((c) => c.scheduleStatus == 'unscheduled'), hasLength(7));
    expect(
      dataset.courses.map((c) => c.sourceId).toSet()
          .intersection(prior.courses.map((c) => c.sourceId).toSet()),
      isEmpty,
    );
    for (final course in dataset.courses) {
      expect(course.code, isEmpty);
      expect(course.credits, isNull); // Contact hours are not published credits.
      expect(course.classificationLabelsFor(), ['교양']);
      expect(course.meetings.every((m) => m.date == null), isTrue);
      final restored = TimetableClass.fromJson(
        course.toTimetable(id: course.sourceId, mode: LectureMode.inPerson).toJson(),
      );
      expect(classOccurrences([restored], [DateTime(2026, 8, 31), DateTime(2026, 12, 16)]), isEmpty);
    }
    final clock = dataset.courses.singleWhere(
      (c) => c.sourceId == 'wsu-sires-public292541-sheet1-row8',
    );
    expect(clock.title, 'Sol-Vision2');
    expect(clock.meetings.single.weekday, 3);
    expect(clock.meetings.single.startMinute, 780);
    expect(clock.meetings.single.endMinute, 840);
    final malformedWeek = dataset.courses.singleWhere(
      (c) => c.sourceId == 'wsu-sires-public292541-sheet1-row78',
    );
    expect(malformedWeek.meetings, isEmpty);
    expect(malformedWeek.sourceRemarks, contains('46038'));
  });
}
