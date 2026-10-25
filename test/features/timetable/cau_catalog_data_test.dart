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

  test('CAU period meetings include the following break', () {
    for (final (campus, base) in [('seoul', 540), ('davinci', 570)]) {
      final courses =
          (jsonDecode(
                    File(
                      'assets/timetable/cau-$campus-2026-2.json',
                    ).readAsStringSync(),
                  )['courses']
                  as List)
              .cast<Map<String, dynamic>>();
      var checked = 0;
      for (final c in courses) {
        final source = c['sourceSchedule'] as String;
        // Meetings with clock times in the source stay verbatim.
        if (RegExp(r'\d\d:\d\d').hasMatch(source)) continue;
        final expected = <(int, int, int)>[];
        for (final part
            in source
                .split(' / ')
                .where((p) => RegExp(r'^[월화수목금토일]').hasMatch(p))) {
          for (final m in RegExp(r'([월화수목금토일])([0-9A-H,]+)').allMatches(part)) {
            for (final p in m[2]!.split(',').where((p) => p.isNotEmpty)) {
              final letter = 'ABCDEFGH'.indexOf(p);
              final start = letter >= 0
                  ? base + letter * 90
                  : base + (int.parse(p) - 1) * 60;
              expected.add((
                '월화수목금토일'.indexOf(m[1]!) + 1,
                start,
                start + (letter >= 0 ? 90 : 60),
              ));
            }
          }
        }
        int byTime((int, int, int) a, (int, int, int) b) =>
            a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2;
        expected.sort(byTime);
        final merged = <(int, int, int)>[];
        for (final e in expected) {
          if (merged.isNotEmpty &&
              merged.last.$1 == e.$1 &&
              e.$2 >= merged.last.$3 &&
              e.$2 - merged.last.$3 < 60) {
            merged[merged.length - 1] = (e.$1, merged.last.$2, e.$3);
          } else if (!merged.contains(e)) {
            merged.add(e);
          }
        }
        final actual = [
          for (final m in c['schedules'] as List)
            (
              m['weekday'] as int,
              m['startMinute'] as int,
              m['endMinute'] as int,
            ),
        ]..sort(byTime);
        expect(actual, merged, reason: source);
        checked++;
      }
      expect(checked, greaterThan(1000));
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
