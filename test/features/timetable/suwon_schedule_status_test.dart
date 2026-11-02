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

  // 1교시 09:30, 교시 50분+쉬는 시간 10분을 합친 60분 슬롯. 9교시 이후는 시각
  // 근거가 없어 자산에 없다.
  test('Suwon meetings use 60-minute period slots including the break', () {
    final raw =
        jsonDecode(
              File(
                'assets/timetable/suwon-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    var meetings = 0;
    for (final c in raw['courses'] as List) {
      final byDayRoom = <String, List<Map>>{};
      for (final m in c['schedules'] as List) {
        meetings++;
        final start = m['startMinute'] as int;
        final end = m['endMinute'] as int;
        expect((start - 570) % 60, 0, reason: c['sourceId'] as String);
        expect(start, inInclusiveRange(570, 990));
        expect(end, lessThanOrEqualTo(1050));
        expect((end - start) % 60, 0);
        expect(end, greaterThan(start));
        byDayRoom
            .putIfAbsent('${m['date']}/${m['classroom']}', () => [])
            .add(m);
      }
      // 같은 날 같은 강의실에서 60분 미만으로 이어지는 구간은 하나로 합친다.
      for (final list in byDayRoom.values) {
        list.sort(
          (a, b) => (a['startMinute'] as int) - (b['startMinute'] as int),
        );
        for (var i = 1; i < list.length; i++) {
          expect(
            (list[i]['startMinute'] as int) - (list[i - 1]['endMinute'] as int),
            greaterThanOrEqualTo(60),
            reason: c['sourceId'] as String,
          );
        }
      }
      for (final b in c['metadata']['nativeClockRoomBlocks'] as List) {
        final periods = b['nativePeriods'] as List;
        expect(b['startMinute'], 570 + (periods.first - 1) * 60);
        expect(b['endMinute'], 570 + periods.last * 60);
      }
    }
    expect(meetings, 23034);
  });
}
