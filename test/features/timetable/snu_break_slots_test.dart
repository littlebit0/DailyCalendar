import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 서울대 원문은 시계 시각이라 시각은 바꾸지 않고, 같은 강의실의 연속 구간
// (간격 60분 미만, 쉬는 시간 포함)만 하나로 합친다.
void main() {
  final data =
      jsonDecode(File('assets/timetable/snu-main-2026-2.json').readAsStringSync())
          as Map<String, dynamic>;
  final courses = (data['courses'] as List).cast<Map<String, dynamic>>();

  test('merged segments keep the first start and last end', () {
    final byId = {for (final c in courses) c['sourceId'] as String: c};
    List<List<Object?>> rows(String id) => (byId[id]!['schedules'] as List)
        .map(
          (s) => [
            s['weekday'],
            s['startMinute'],
            s['endMinute'],
            s['classroom'],
          ],
        )
        .toList();
    // 금(14:00~14:50)+금(15:00~16:50), 같은 강의실
    expect(rows('snu/main/2026/2/E11.175/001'), [
      [5, 840, 1010, '152-1-208(무선랜제공)'],
    ]);
    // 수(13:00~14:50)+수(15:00~16:50), 같은 강의실
    expect(rows('snu/main/2026/2/E11.178/001'), [
      [3, 780, 1010, '83-502(무선랜제공)'],
    ]);
  });

  test('no same-room same-day segments closer than 60 minutes remain', () {
    var segments = 0;
    for (final c in courses) {
      final s = (c['schedules'] as List).cast<Map<String, dynamic>>();
      segments += s.length;
      for (var i = 0; i < s.length; i++) {
        for (var j = 0; j < s.length; j++) {
          if (i == j ||
              s[i]['weekday'] != s[j]['weekday'] ||
              s[i]['classroom'] != s[j]['classroom']) {
            continue;
          }
          final gap =
              (s[j]['startMinute'] as int) - (s[i]['endMinute'] as int);
          expect(
            gap < 60 && (s[j]['startMinute'] as int) >= (s[i]['startMinute'] as int),
            isFalse,
            reason: c['sourceId'] as String,
          );
        }
      }
    }
    expect(courses.length, 3744);
    expect(segments, 5030);
  });
}
