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
    // Every printed row stays a course; closure is not judged (2026-11-23).
    expect(total, 1523);
    expect(ids, hasLength(1523));
    expect(byStatus, {
      // 19 pre-06:00 원격강좌 placeholders are remote without a clock; 5 rows
      // take their time from the 미래융합대학 계약학과·BCC timetable.
      'scheduled': 1498,
      'unscheduled': 25,
    });
  });

  test('closure-listed rows stay courses and only a remark notes the list', () {
    final natural = _json('assets/timetable/mju-natural-2026-2.json');
    final humanities = _json('assets/timetable/mju-humanities-2026-2.json');
    final listed = <String>{};
    for (final raw in [natural, humanities]) {
      final codes = {
        for (final c in raw['courses'] as List) c['courseCode'] as String,
      };
      final noted = {
        for (final c in raw['courses'] as List)
          if ((c['remarks'] as String).contains('최종폐강 강좌 내역'))
            c['courseCode'] as String,
      };
      final codesListed = (raw['closureListing']['courseCodes'] as List)
          .cast<String>()
          .toSet();
      expect(codesListed, noted);
      expect(codes, containsAll(codesListed));
      listed.addAll(codesListed);
    }
    // 캡스톤디자인1 (자연 0529), 법논리학2 (인문 5938) are on the 2026-09-09 list.
    expect(listed, containsAll(['0529', '5938']));
    expect(listed, hasLength(79));
  });

  test('전공필수 only from the latest-admission 학사안내문 table', () {
    final directory = CourseOrganizationDirectory.fromJson(
      _json('assets/timetable/organizations/mju.json'),
    );
    var required = 0;
    for (final campus in ['humanities', 'natural']) {
      final raw = _json('assets/timetable/mju-$campus-2026-2.json');
      final courses = UniversityDataset.fromJson(
        raw,
        organizationDirectory: directory,
      ).courses;
      for (final c in courses) {
        final labels = c.departmentClassifications.values.toSet();
        expect(labels.difference({'전공필수'}), isEmpty, reason: c.sourceId);
        expect(c.sourceClassification, isEmpty, reason: c.sourceId);
        if (labels.isNotEmpty) {
          required++;
          expect(c.sourceRemarks, contains('전공필수 2025학번 이후'));
        }
      }
    }
    expect(required, 167);
  });
}
