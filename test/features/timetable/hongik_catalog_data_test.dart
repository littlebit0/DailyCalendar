import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

// 교학과 안내: 1교시 09:00 시작, 수업 50분 + 쉬는 시간 10분(점심 없음), 1~13교시.
// 교시 슬롯은 그 교시 시작부터 다음 교시 시작 직전까지(60분)이고 마지막 13교시도 같다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Hongik meetings are whole 60-minute period slots, merged when adjacent',
    () async {
      final campuses = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'hongik',
      );
      expect(campuses.map((d) => d.campus).toSet(), {'seoul', 'sejong'});
      expect(
        {for (final d in campuses) d.campus: d.courses.length},
        {'seoul': 2481, 'sejong': 1090},
      );
      for (final d in campuses) {
        for (final c in d.courses) {
          final ms = c.meetings;
          for (final m in ms) {
            expect(m.originalStartMinute % 60, 0, reason: c.sourceId);
            expect(m.originalEndMinute % 60, 0, reason: c.sourceId);
            expect(
              m.originalStartMinute,
              inInclusiveRange(540, 1260),
              reason: c.sourceId,
            );
            expect(
              m.originalEndMinute,
              inInclusiveRange(600, 1320),
              reason: c.sourceId,
            );
            for (final o in ms) {
              if (identical(m, o) ||
                  m.weekday != o.weekday ||
                  m.date != o.date ||
                  m.classroom != o.classroom) {
                continue;
              }
              // 같은 요일(날짜)·강의실에서 60분 미만으로 붙은 구간이 남아 있으면 안 된다.
              expect(
                o.originalStartMinute - m.originalEndMinute >= 60 ||
                    m.originalStartMinute - o.originalEndMinute >= 60,
                isTrue,
                reason: '${c.sourceId} ${m.weekday}',
              );
            }
          }
        }
      }
      final seoul = campuses.firstWhere((d) => d.campus == 'seoul');
      final sejong = campuses.firstWhere((d) => d.campus == 'sejong');
      final seoulMeetings = seoul.courses.fold<int>(
        0,
        (n, c) => n + c.meetings.length,
      );
      final sejongMeetings = sejong.courses.fold<int>(
        0,
        (n, c) => n + c.meetings.length,
      );
      expect(seoulMeetings, 3001);
      expect(sejongMeetings, 1443);
      // 금7,금8,금9 → 15:00~18:00 한 구간.
      final merged = seoul.courses.firstWhere(
        (c) => c.sourceId == 'hongik/seoul/2026/2/125718/2',
      );
      expect(merged.meetings.single.originalStartMinute, 900);
      expect(merged.meetings.single.originalEndMinute, 1080);
      // 월12 → 09:00~11:00 (10:50이 아니라 쉬는 시간 포함).
      final first = sejong.courses.firstWhere(
        (c) => c.sourceId == 'hongik/sejong/2026/2/001013/501',
      );
      expect(first.meetings.first.originalEndMinute, 660);
    },
  );
}
