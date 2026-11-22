import 'dart:convert';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/source_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Myongji 2026-2 keeps every 개설강좌현황표 row and schedules only '
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
    expect(total, 1523);
    expect(ids, hasLength(1523));
    expect(byStatus, {'scheduled': 1440, 'unrecognized': 72, 'unscheduled': 11});
  });
}
