import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 아주대 공식 교시표: 숫자 교시 50분+쉬는 시간 10분(슬롯 60분),
// A~H교시 75분+쉬는 시간 15분(슬롯 90분, 시작 09:00부터 90분 간격).
// 원문이 HH:mm~HH:mm로 적은 구간은 그대로 둔다.
void main() {
  test('ajou meetings follow break-inclusive period slots', () {
    final data =
        jsonDecode(
              File('assets/timetable/ajou-main-2026-2.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final token = RegExp(
      r'([월화수목금토일])(\d{2}:\d{2}~\d{2}:\d{2}|[A-H]|\d{1,2}(?:\.5)?)\s*(?:\(([^()]*)\))?',
    );
    var checked = 0;
    var clockCourses = 0;
    for (final course
        in (data['courses'] as List).cast<Map<String, dynamic>>()) {
      if (course['scheduleStatus'] != 'scheduled') continue;
      final rows = <({int day, int start, int end, String room, bool clock})>[];
      for (final m in token.allMatches(course['sourceSchedule'] as String)) {
        final period = m[2]!;
        late int start;
        late int end;
        var clock = false;
        if (period.contains(':')) {
          final t = RegExp(
            r'\d+',
          ).allMatches(period).map((x) => int.parse(x[0]!)).toList();
          start = t[0] * 60 + t[1];
          end = t[2] * 60 + t[3];
          clock = true;
        } else if (RegExp('[A-H]').hasMatch(period)) {
          start = 540 + (period.codeUnitAt(0) - 65) * 90;
          end = start + 90;
        } else {
          start = 540 + ((double.parse(period) - 1) * 60).round();
          end = start + 60;
        }
        rows.add((
          day: '월화수목금토일'.indexOf(m[1]!) + 1,
          start: start,
          end: end,
          room: m[3] ?? '',
          clock: clock,
        ));
      }
      if (rows.any((r) => r.clock)) clockCourses++;
      rows.sort(
        (a, b) => [
          a.day.compareTo(b.day),
          a.start.compareTo(b.start),
          a.room.compareTo(b.room),
        ].firstWhere((c) => c != 0, orElse: () => 0),
      );
      final expected =
          <({int day, int start, int end, String room, bool clock})>[];
      for (final r in rows) {
        final p = expected.isEmpty ? null : expected.last;
        if (p != null &&
            !(p.clock && r.clock) &&
            p.day == r.day &&
            p.room == r.room &&
            r.start - p.end < 60) {
          expected[expected.length - 1] = (
            day: p.day,
            start: p.start,
            end: r.end > p.end ? r.end : p.end,
            room: p.room,
            clock: p.clock || r.clock,
          );
        } else if (!expected.contains(r)) {
          expected.add(r);
        }
      }
      final actual = (course['schedules'] as List).cast<Map<String, dynamic>>();
      expect(
        actual
            .map(
              (s) => [
                s['weekday'],
                s['startMinute'],
                s['endMinute'],
                s['classroom'],
              ],
            )
            .toList(),
        expected.map((e) => [e.day, e.start, e.end, e.room]).toList(),
        reason: course['sourceId'] as String,
      );
      checked++;
    }
    expect(checked, 1885);
    expect(clockCourses, 29);
  });
}
