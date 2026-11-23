// 2026-11-23 사용자 결정: 공식 요일·시각이 있으면 운영 방식이 불명확해도 대면 수업으로 확정한다.
import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> load(String campus) =>
      jsonDecode(
            File(
              'assets/timetable/donga-$campus-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('printed clocks are scheduled and clockless LMS rows are untimed', () {
    final status = <String, Map<String?, int>>{};
    for (final campus in ['seunghak', 'unknown']) {
      final data = UniversityDataset.fromJson(load(campus));
      final counts = status[campus] = {};
      for (final c in data.courses) {
        counts[c.scheduleStatus] = (counts[c.scheduleStatus] ?? 0) + 1;
        if (c.scheduleStatus == 'unscheduled') {
          expect(c.sourceSchedule, contains('LMS'), reason: c.sourceId);
          expect(c.sourceSchedule, isNot(contains(':')), reason: c.sourceId);
        }
      }
    }
    expect(status, {
      'seunghak': {'scheduled': 38},
      'unknown': {'scheduled': 25, 'unscheduled': 17},
    });
  });

  test('week-limited offline rows keep only their printed weeks', () {
    final course = UniversityDataset.fromJson(
      load('unknown'),
    ).courses.singleWhere((c) => c.code == '01322814');
    final dates = course.meetings.map((m) => m.date).toList();
    // Weeks 1-7 and 9-14 on Friday; week 8 (10/23) is the midterm week and
    // 9/25 and 10/9 are holidays.
    expect(dates, hasLength(11));
    expect(dates, isNot(contains('2026-10-23')));
    expect(dates, isNot(contains('2026-09-25')));
    expect(dates.first, '2026-09-04');
    expect(dates.last, '2026-12-04');
    expect(
      course.meetings.every(
        (m) => m.originalStartMinute == 600 && m.originalEndMinute == 780,
      ),
      isTrue,
    );
  });
}
