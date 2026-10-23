import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/university_support_policy.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Suwon keeps search off while published times remain unresolved', () {
    final raw =
        jsonDecode(
              File(
                'assets/timetable/suwon-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final courses = UniversityDataset.fromJson(raw).courses;
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(2334));
    final status = <String, int>{};
    for (final c in courses) {
      status[c.scheduleStatus!] = (status[c.scheduleStatus!] ?? 0) + 1;
      // A course without a published time is never hidden as a held one.
      if (c.scheduleStatus == 'unscheduled') {
        expect(c.sourceSchedule.trim(), isEmpty, reason: c.sourceId);
        expect(c.meetings, isEmpty, reason: c.sourceId);
      }
    }
    expect(status, {
      'scheduled': 1524,
      'unscheduled': 442,
      'unrecognized': 368,
    });
    expect(
      UniversitySupportPolicy.timetableAvailable('suwon'),
      isFalse,
      reason: '368 unrecognized and 6 partially scheduled courses remain',
    );
  });
}
