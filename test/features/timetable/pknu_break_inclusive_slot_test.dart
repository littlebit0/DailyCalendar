import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 부경대 교시 슬롯 = 수업 + 쉬는 시간: 50분 교시는 60분, 75분 교시는 90분.
// 같은 과목·날짜·강의실의 연속 교시는 한 구간으로 합쳐 저장한다.
void main() {
  const expectedSegments = {'unknown': 2130, 'daeyeon': 44282};
  for (final campus in expectedSegments.keys) {
    test('pknu $campus 교시 슬롯이 쉬는 시간을 포함하고 연속 교시가 합쳐짐', () {
      final data =
          jsonDecode(
                File(
                  'assets/timetable/pknu-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      var total = 0;
      for (final c in data['courses'] as List) {
        final byKey = <String, List<Map<String, dynamic>>>{};
        for (final m in (c['schedules'] as List).cast<Map<String, dynamic>>()) {
          total++;
          expect(m.containsKey('sourcePeriods'), false);
          final unit = m['sourceMinuteUnit'] as int?;
          final start = m['startMinute'] as int;
          final len = (m['endMinute'] as int) - start;
          if (unit != null) {
            final slot = unit == 50 ? 60 : 90;
            // 구간 길이는 슬롯 길이의 정수배(합친 교시 수)여야 한다.
            expect(len % slot, 0, reason: '${c['sourceId']}');
            expect(len, greaterThan(0));
            final first = m['sourcePeriod'] as int;
            expect(
              start,
              unit == 50 ? 480 + 60 * first : 540 + 90 * (first - 1),
              reason: '${c['sourceId']} ${m['date']}',
            );
          }
          byKey.putIfAbsent('${m['date']}|${m['classroom']}', () => []).add(m);
        }
        for (final list in byKey.values) {
          list.sort(
            (a, b) => (a['startMinute'] as int) - (b['startMinute'] as int),
          );
          for (var i = 1; i < list.length; i++) {
            expect(
              (list[i]['startMinute'] as int) -
                  (list[i - 1]['endMinute'] as int),
              greaterThanOrEqualTo(60),
              reason: '${c['sourceId']} ${list[i]['date']}',
            );
          }
        }
      }
      expect(total, expectedSegments[campus]);
    });
  }
  // 혼합 수업이라 보류했던 강좌도 공식 화·목 75분 교시로 확정한다(apply_pknu_held_periods.py).
  test('pknu 보류였던 화5 목5 75분 강좌가 15:00~16:30으로 확정됨', () {
    final data =
        jsonDecode(
              File(
                'assets/timetable/pknu-daeyeon-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final course = (data['courses'] as List).singleWhere(
      (c) => c['sourceId'] == 'pknu-2026-2-112671-101',
    );
    expect(course['scheduleStatus'], 'scheduled');
    expect(course['schedules'].first, {
      'weekday': 2,
      'startMinute': 900,
      'endMinute': 990,
      'classroom': 'C23-312',
      'sourcePeriod': 5,
      'sourceMinuteUnit': 75,
      'date': '2026-09-01',
    });
  });
  // 2차: 7/30 개설표 75분 단위를 월·수에도 적용(현재 계획서 '월3 수2', 3시간 시수와 일치).
  test('pknu 월3 수2 75분 강좌가 75분 교시 시각으로 확정됨', () {
    final data =
        jsonDecode(
              File(
                'assets/timetable/pknu-daeyeon-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final course = (data['courses'] as List).singleWhere(
      (c) => c['sourceId'] == 'pknu-2026-2-100763-101',
    );
    expect(course['scheduleStatus'], 'scheduled');
    expect(course['schedules'][1], {
      'weekday': 1,
      'startMinute': 720,
      'endMinute': 810,
      'classroom': 'C15-813',
      'sourcePeriod': 3,
      'sourceMinuteUnit': 75,
      'date': '2026-09-07',
    });
  });
  // 2차: OCU/KCU 원격 강좌는 편람상 실시간 시각이 없어 시간 미정.
  test('pknu OCU/KCU 강좌는 시간 미정', () {
    final data =
        jsonDecode(
              File(
                'assets/timetable/pknu-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final statuses = <String, int>{};
    for (final c in data['courses'] as List) {
      statuses.update(
        c['scheduleStatus'] as String,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }
    expect(statuses, {'scheduled': 151, 'unscheduled': 154});
  });
}
