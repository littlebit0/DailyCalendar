import 'dart:convert';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/source_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Dong-eui 2026-2 keeps the official 1st-year sections and shows '
      'periods only as published text', () {
    final raw = _json('assets/timetable/deu-main-2026-2.json');
    final directory = CourseOrganizationDirectory.fromJson(
      _json('assets/timetable/organizations/deu.json'),
    );
    final dataset = UniversityDataset.fromJson(
      raw,
      organizationDirectory: directory,
    );
    expect(raw['completionClaim'], isFalse);
    expect(raw['scopeNote'], contains('1학년'));
    final courses = dataset.courses;
    // 1,260 unique 강좌번호 in the three PDFs minus 7 on the 2026-08-27
    // pre-semester closure list.
    expect(courses, hasLength(1253));
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(1253));

    final byStatus = <String?, int>{};
    for (final c in courses) {
      byStatus[c.scheduleStatus] = (byStatus[c.scheduleStatus] ?? 0) + 1;
    }
    expect(byStatus, {'unrecognized': 1193, 'unscheduled': 60});

    // No official undergraduate period-to-clock table: nothing is placed.
    for (final c in courses) {
      expect(c.meetings, isEmpty, reason: c.sourceId);
      expect(
        c.sourceSchedule.isEmpty,
        c.scheduleStatus == 'unscheduled',
        reason: c.sourceId,
      );
    }
    final korean = courses.firstWhere(
      (c) => c.sourceId == 'deu/main/2026/2/401763-001',
    );
    expect(korean.title, '이야기와소설의이해');
    expect(korean.sourceSchedule, '[화4],[수2-3]');
    expect(korean.sourceClassroom, '2인207');
    expect(korean.departments, ['국어국문학과']);
    expect(
      courses.where((c) => c.sourceId.endsWith('/300267-003')),
      isEmpty,
      reason: 'closed before the semester',
    );

    // Every major department heading belongs to an official college.
    var majors = 0;
    for (final c in courses) {
      for (final label in c.departments) {
        if (!c.isMajorForSourceDepartment(label)) continue;
        majors++;
        final units = c.offeringOrganizations.where(
          (o) => o.sourceLabel == label,
        );
        expect(units, isNotEmpty, reason: '${c.sourceId} $label');
        expect(
          units.every((o) => o.college != null),
          isTrue,
          reason: '${c.sourceId} $label',
        );
      }
    }
    expect(majors, 333);
  });
}
