import 'dart:convert';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/source_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Myongji 2026-2 keeps every open 개설강좌현황표 row and schedules only '
      'printed weekly clock times', () {
    final directory = CourseOrganizationDirectory.fromJson(
      _json('assets/timetable/organizations/mju.json'),
    );
    final byStatus = <String?, int>{};
    final ids = <String>{};
    var total = 0;
    for (final campus in ['humanities', 'natural']) {
      final raw = _json('assets/timetable/mju-$campus-2026-2.json');
      expect(raw['completionClaim'], isFalse);
      final courses = UniversityDataset.fromJson(
        raw,
        organizationDirectory: directory,
      ).courses;
      total += courses.length;
      for (final c in courses) {
        ids.add(c.code);
        byStatus[c.scheduleStatus] = (byStatus[c.scheduleStatus] ?? 0) + 1;
        expect(c.period?.start, DateTime(2026, 9, 1));
        expect(c.period?.end, DateTime(2026, 12, 18));
        expect(c.meetings.isNotEmpty, c.scheduleStatus == 'scheduled');
        if (c.scheduleStatus == 'unrecognized') {
          expect(c.sourceRemarks, contains('시각 보류'), reason: c.sourceId);
        }
        // Every published 학과명 resolves to its printed 단과대 (or program).
        expect(c.offeringOrganizations, isNotEmpty, reason: c.sourceId);
      }
    }
    // 1523 printed rows minus 79 closed in the 2026-09-09 final closure list.
    expect(total, 1444);
    expect(ids, hasLength(1444));
    expect(byStatus, {
      'scheduled': 1368,
      'unrecognized': 65,
      'unscheduled': 11,
    });
  });

  test('courses in the official final closure list cannot be added', () {
    final natural = _json('assets/timetable/mju-natural-2026-2.json');
    final humanities = _json('assets/timetable/mju-humanities-2026-2.json');
    final codes = {
      'natural': {for (final c in natural['courses']) c['courseCode']},
      'humanities': {for (final c in humanities['courses']) c['courseCode']},
    };
    // 캡스톤디자인1 (자연 0529), 법논리학2 (인문 5938) are closed on 2026-09-09.
    expect(codes['natural'], isNot(contains('0529')));
    expect(codes['humanities'], isNot(contains('5938')));
    final closed = {
      for (final raw in [natural, humanities])
        for (final c in raw['excludedClosedCourses']['courses'])
          c['courseCode'],
    };
    expect(closed, containsAll(['0529', '5938']));
    expect(closed, hasLength(79));
  });
}
