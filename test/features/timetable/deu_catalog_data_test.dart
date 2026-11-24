import 'dart:convert';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/source_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Dong-eui 2026-2 keeps the official 1st-year sections and shows '
      'periods on the 09:00 + 60-minute DAP period clock', () {
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
    // All 1,260 unique 강좌번호 in the three PDFs; 7 are also on the
    // 2026-08-27 pre-semester closure list (closure is not judged).
    expect(courses, hasLength(1260));
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(1260));

    final byStatus = <String?, int>{};
    for (final c in courses) {
      byStatus[c.scheduleStatus] = (byStatus[c.scheduleStatus] ?? 0) + 1;
    }
    // The one unrecognized row is 300278-002, whose PDF cell is clipped
    // mid-slot ("지천관620[토").
    expect(byStatus, {'scheduled': 1199, 'unrecognized': 1, 'unscheduled': 60});

    for (final c in courses) {
      expect(
        c.meetings.isNotEmpty,
        c.scheduleStatus == 'scheduled',
        reason: c.sourceId,
      );
      expect(
        c.sourceSchedule.isEmpty,
        c.scheduleStatus == 'unscheduled',
        reason: c.sourceId,
      );
    }
    expect(
      courses
          .singleWhere((c) => c.sourceId.endsWith('/300278-002'))
          .scheduleStatus,
      'unrecognized',
    );
    final korean = courses.firstWhere(
      (c) => c.sourceId == 'deu/main/2026/2/401763-001',
    );
    expect(korean.title, '이야기와소설의이해');
    expect(korean.sourceSchedule, '[화4],[수2-3]');
    expect(korean.sourceClassroom, '2인207');
    expect(korean.departments, ['국어국문학과']);
    // n교시 = 09:00 + (n-1) h, 60-minute slot: 화4 12:00-13:00, 수2-3 10:00-12:00.
    expect(
      korean.meetings
          .map(
            (m) => [
              m.weekday,
              m.originalStartMinute,
              m.originalEndMinute,
              m.classroom,
            ],
          )
          .toList(),
      [
        [2, 720, 780, '2인207'],
        [3, 600, 720, '2인207'],
      ],
    );
    expect(
      courses
          .singleWhere((c) => c.sourceId.endsWith('/300267-003'))
          .sourceRemarks,
      contains('폐강 여부는 판단하지 않음'),
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
    expect(majors, 334);
  });
}
