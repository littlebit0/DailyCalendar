import 'dart:convert';

import 'package:daily/core/academic/university_support_policy.dart';
import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/source_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Daejeon 2026-2 keeps every official timetable row and invents no '
      'clock for periods the school publishes without times', () {
    final raw = _json('assets/timetable/dju-main-2026-2.json');
    final directory = CourseOrganizationDirectory.fromJson(
      _json('assets/timetable/organizations/dju.json'),
    );
    final dataset = UniversityDataset.fromJson(
      raw,
      organizationDirectory: directory,
    );
    expect(raw['completionClaim'], isFalse);
    final courses = dataset.courses;
    // 교양 609 + 전공 1,564 + 일반선택·교직 80 rows of the 2026-08-18 sheets.
    expect(courses, hasLength(2253));
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(2253));
    expect(
      courses.where((c) => c.sourceClassification == '교양'),
      hasLength(609),
    );

    final byStatus = <String?, int>{};
    for (final c in courses) {
      byStatus[c.scheduleStatus] = (byStatus[c.scheduleStatus] ?? 0) + 1;
      expect(c.meetings, isEmpty, reason: c.sourceId);
      expect(c.period!.start, DateTime(2026, 9, 1));
      expect(c.period!.end, DateTime(2026, 12, 21));
      if (c.scheduleStatus == 'unrecognized') {
        expect(c.sourceSchedule, isNotEmpty, reason: c.sourceId);
        expect(c.sourceRemarks, contains('시각 보류'), reason: c.sourceId);
      } else {
        expect(c.sourceSchedule, isEmpty, reason: c.sourceId);
      }
    }
    expect(byStatus, {'unrecognized': 2080, 'unscheduled': 173});

    // Every 전공·일반선택·교직 row keeps its printed 단과대학 > 학부·학과(전공).
    final owned = courses.where((c) => c.departments.isNotEmpty).toList();
    expect(owned, hasLength(1644));
    for (final c in owned) {
      expect(c.offeringOrganizations, isNotEmpty, reason: c.sourceId);
      expect(
        c.offeringOrganizations.every((o) => o.college != null),
        isTrue,
        reason: c.sourceId,
      );
    }
    final seminar = courses.singleWhere((c) => c.codeAndSection == '013423-01');
    expect(seminar.title, '리버럴아츠세미나2');
    expect(seminar.sourceSchedule, '목(5,6)');
    expect(seminar.sourceClassroom, '1402');
    expect(seminar.offeringOrganizations.single.college, '혜화리버럴아츠칼리지');
    expect(seminar.offeringOrganizations.single.department, '혜화리버럴아츠칼리지대학');

    // No published clock table, so search stays suspended.
    expect(
      UniversitySupportPolicy.suspendedTimetableUniversities,
      contains('dju'),
    );
  });
}
