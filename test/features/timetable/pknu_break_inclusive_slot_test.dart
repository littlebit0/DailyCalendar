import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 부경대 교시 슬롯 = 수업 + 쉬는 시간: 50분 교시는 60분, 75분 교시는 90분.
// 같은 과목·날짜·강의실의 연속 교시는 한 구간으로 합쳐 저장한다.
void main() {
  const expectedSegments = {'unknown': 625, 'daeyeon': 40335};
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
}
