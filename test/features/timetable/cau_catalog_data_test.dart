import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CAU complete public campus catalogs load without unresolved times', () {
    for (final (campus, count) in [('seoul', 2408), ('davinci', 1589)]) {
      final dataset = UniversityDataset.fromJson(
        jsonDecode(
          File('assets/timetable/cau-$campus-2026-2.json').readAsStringSync(),
        ),
      );
      expect(dataset.universityId, 'cau');
      expect(dataset.courses.length, count);
      expect(
        dataset.courses.every((c) => c.scheduleStatus != 'unrecognized'),
        isTrue,
      );
      expect(dataset.courses.any((c) => c.remarks.isNotEmpty), isTrue);
    }
  });

  test('CAU flexible teaching dates survive saves and intersect the term', () {
    final dataset = UniversityDataset.fromJson(
      jsonDecode(
        File('assets/timetable/cau-seoul-2026-2.json').readAsStringSync(),
      ),
    );
    final course = dataset.courses.firstWhere(
      (c) => c.period?.start == DateTime(2026, 10, 27),
    );
    final saved = TimetableClass.fromJson(
      course.toTimetable(id: 'flexible', mode: LectureMode.inPerson).toJson(),
    );
    expect(saved.period, course.period);
    final term = TimetablePeriod(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 12, 21),
    );
    final day = saved.meetings.first.weekday;
    final dates = [
      for (
        var date = DateTime(2026, 9, 1);
        !date.isAfter(DateTime(2026, 12, 31));
        date = date.add(const Duration(days: 1))
      )
        if (date.weekday == day) date,
    ];
    final occurrences = classOccurrences(
      [saved],
      dates,
      periodFor: (_) => term,
    );
    expect(occurrences, isNotEmpty);
    expect(
      occurrences.every(
        (o) => saved.period!.contains(o.date) && term.contains(o.date),
      ),
      isTrue,
    );
    expect(
      classOccurrences(
        [saved],
        dates.where((d) => d.isBefore(DateTime(2026, 10, 27))),
        periodFor: (_) => term,
      ),
      isEmpty,
    );
  });
}
