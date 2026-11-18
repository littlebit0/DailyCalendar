import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 출하 자산의 수업 시각을 학교 원문 문자열(sourceSchedule)과 대조한다(#948).
// 원문은 "수 1( 8:00~ 9:15)"처럼 12시간제 시각을 적거나 "월 3~3"처럼 교시만 적는다.
void main() {
  test('every scheduled Ewha meeting matches the published source text', () {
    final data =
        jsonDecode(
              File(
                'assets/timetable/ewha-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    const weekdays = '월화수목금토일';
    // 원문 시각은 12시간제다. 수업은 8시에 시작하므로 8 미만은 오후다.
    int clock(String hour, String minute) {
      final h = int.parse(hour);
      return (h < 8 ? h + 12 : h) * 60 + int.parse(minute);
    }

    final clocked = RegExp(
      r'([월화수목금토일])\s*[\d,]+\(\s*(\d+):(\d+)~\s*(\d+):(\d+)\)',
    );
    final ranged = RegExp(r'([월화수목금토일])\s*(\d+)~(\d+)');
    // 교시만 적힌 원문에 쓰는 교시표가 시각이 적힌 원문과 같은지도 확인한다.
    final periods = {
      for (final entry in (data['nativePeriodClocks'] as Map).entries)
        int.parse(entry.key as String): (entry.value as List).cast<int>(),
    };
    final observed = <int, Set<List<int>>>{};
    var checked = 0;
    for (final course in data['courses'] as List) {
      if (course['scheduleStatus'] != 'scheduled') continue;
      final source = course['sourceSchedule'] as String;
      final expected = <String>{
        for (final m in clocked.allMatches(source))
          '${weekdays.indexOf(m[1]!) + 1}/${clock(m[2]!, m[3]!)}/${clock(m[4]!, m[5]!)}',
        for (final m in ranged.allMatches(source))
          '${weekdays.indexOf(m[1]!) + 1}/${periods[int.parse(m[2]!)]![0]}/${periods[int.parse(m[3]!)]![1]}',
      };
      for (final m in RegExp(
        r'[월화수목금토일]\s*(\d+)\(\s*(\d+):(\d+)~\s*(\d+):(\d+)\)',
      ).allMatches(source)) {
        observed.putIfAbsent(int.parse(m[1]!), () => {}).add([
          clock(m[2]!, m[3]!),
          clock(m[4]!, m[5]!),
        ]);
      }
      expect(
        {
          for (final s in course['schedules'] as List)
            '${s['weekday']}/${s['startMinute']}/${s['endMinute']}',
        },
        expected,
        reason: '${course['courseCode']} $source',
      );
      checked++;
    }
    expect(checked, 1984);
    for (final entry in observed.entries) {
      expect(entry.value.map((v) => v.join('-')).toSet(), {
        periods[entry.key]!.join('-'),
      }, reason: 'period ${entry.key}');
    }
  });
}
