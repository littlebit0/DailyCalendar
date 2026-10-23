import 'dart:convert';

import 'package:daily/core/academic/university_support_policy.dart';
import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/source_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Pai Chai 2026-2 keeps every official handbook section and only '
      'schedules times the handbook states directly', () {
    final raw = _json('assets/timetable/pcu-main-2026-2.json');
    final directory = CourseOrganizationDirectory.fromJson(
      _json('assets/timetable/organizations/pcu.json'),
    );
    final dataset = UniversityDataset.fromJson(
      raw,
      organizationDirectory: directory,
    );
    expect(raw['completionClaim'], isFalse);
    final courses = dataset.courses;
    // 1,774 code+section rows plus 사회봉사2~4, which the handbook prints
    // under the same code and sections as 사회봉사1.
    expect(courses, hasLength(1906));
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(1906));

    final byStatus = <String?, int>{};
    for (final c in courses) {
      byStatus[c.scheduleStatus] = (byStatus[c.scheduleStatus] ?? 0) + 1;
    }
    expect(byStatus, {
      'scheduled': 1629,
      'unscheduled': 236,
      'unrecognized': 41,
    });

    // Handbook page 2: 50-minute periods 0-13 and 75-minute periods Z, A-H.
    final letterStarts = {490, 570, 660, 810, 900, 990, 1080, 1170, 1260};
    for (final c in courses) {
      if (c.scheduleStatus != 'scheduled') {
        expect(c.meetings, isEmpty, reason: c.sourceId);
        if (c.scheduleStatus == 'unrecognized') {
          expect(c.sourceRemarks, contains('시각 보류'), reason: c.sourceId);
        }
        continue;
      }
      expect(c.meetings, isNotEmpty, reason: c.sourceId);
      for (final m in c.meetings) {
        final start = m.originalStartMinute;
        final end = m.originalEndMinute;
        final letter = letterStarts.contains(start) && end - start == 75;
        final periods =
            start % 60 == 0 && end % 60 == 50 && start >= 480 && end <= 1310;
        expect(letter || periods, isTrue, reason: c.sourceId);
      }
    }

    // Every major course under a mapped department heading keeps its owner.
    expect(
      courses.where((c) => c.offeringOrganizations.isNotEmpty),
      hasLength(1258),
    );

    // Times still waiting for a user decision keep search suspended.
    expect(
      UniversitySupportPolicy.suspendedTimetableUniversities,
      contains('pcu'),
    );
  });
}
