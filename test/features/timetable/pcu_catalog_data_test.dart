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

    // Handbook page 2 (https://www.pcu.ac.kr/kor/contents/25): 50-minute
    // periods 0-13 with a 10 minute break, 75-minute periods Z, A-G, I with a
    // 15 minute break. A slot runs from the period start to the next start
    // (class plus break); Z is capped at A's start (08:10-09:30).
    final letterSlots = {
      490: 570,
      570: 660,
      660: 750,
      810: 900,
      900: 990,
      990: 1080,
      1080: 1170,
      1170: 1260,
      1260: 1350,
    };
    var segments = 0;
    for (final c in courses) {
      if (c.scheduleStatus != 'scheduled') {
        expect(c.meetings, isEmpty, reason: c.sourceId);
        if (c.scheduleStatus == 'unrecognized') {
          expect(c.sourceRemarks, contains('시각 보류'), reason: c.sourceId);
        }
        continue;
      }
      expect(c.meetings, isNotEmpty, reason: c.sourceId);
      segments += c.meetings.length;
      for (final m in c.meetings) {
        final start = m.originalStartMinute;
        final end = m.originalEndMinute;
        // Numeric blocks are whole 60 minute slots; a lettered block starts
        // on a letter slot and ends on a later letter slot boundary.
        final numeric = start % 60 == 0 && end % 60 == 0 && start >= 480;
        final letter =
            letterSlots.containsKey(start) &&
            (end == letterSlots[start] ||
                (letterSlots.containsValue(end) && end > start));
        expect(numeric || letter, isTrue, reason: c.sourceId);
        expect(end <= 1350, isTrue, reason: c.sourceId);
      }
      // Same day and room with a gap under 60 minutes is one block.
      final sorted = [...c.meetings]
        ..sort((x, y) {
          final k = x.weekday.compareTo(y.weekday);
          return k != 0
              ? k
              : x.originalStartMinute.compareTo(y.originalStartMinute);
        });
      for (var i = 1; i < sorted.length; i++) {
        final p = sorted[i - 1];
        final n = sorted[i];
        if (p.weekday == n.weekday && p.classroom == n.classroom) {
          expect(
            n.originalStartMinute - p.originalEndMinute >= 60,
            isTrue,
            reason: c.sourceId,
          );
        }
      }
    }
    expect(segments, 2386);

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
