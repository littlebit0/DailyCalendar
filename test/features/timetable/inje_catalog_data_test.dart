import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/core/academic/university_support_policy.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Inje whole public offering list keeps every code-section with held clock times',
    () {
      final raw =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/inje-unknown-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(raw['completionClaim'], false);
      expect(raw['wholeSourceAcquired'], true);
      expect(raw['sourceRowCount'], 1838);
      final dataset = UniversityDataset.fromJson(raw);
      expect(dataset.campus, 'unknown');
      expect(dataset.courses, hasLength(1756));
      final rows = <int>{};
      final reasons = <String, int>{};
      for (final c in raw['courses'] as List) {
        expect(
          c['sourceId'],
          'inje/all/2026-2/${c['courseCode']}-${c['section']}',
        );
        final education = c['sourceEducation'] as Map;
        for (final row in education['nativeRows'] as List) {
          expect(rows.add(row['sourceRow'] as int), true);
        }
        // 2026-11-23: the official 2026-2 department timetable's period
        // table (0교시 08:00, 1~9교시 60분, 10교시 18:00~18:45) applies to
        // every listed period; rows without a published time stay held.
        if (c['scheduleStatus'] == 'scheduled') {
          expect(c['schedules'], isNotEmpty);
          expect(education.containsKey('holdReason'), false);
          continue;
        }
        expect(c['scheduleStatus'], 'unrecognized');
        expect(c['schedules'], isEmpty);
        final reason = education['holdReason'] as String;
        reasons[reason] = (reasons[reason] ?? 0) + 1;
      }
      expect(rows, hasLength(1838));
      expect(reasons, {
        '수업계획서 수업시간·강의실 칸 비어 있음': 84,
        '수업계획서 미등록(인나비 목록에 출력 버튼 없음)': 80,
        "수업계획서 출력 서버 오류(XML 대신 'AA문자열이나 이진 데이터는 잘립니다.' 응답)": 3,
      });
      final timed = dataset.courses.where((c) => c.meetings.isNotEmpty);
      expect(timed, hasLength(1589));
      final writing = dataset.courses.singleWhere(
        (c) => c.sourceId == 'inje/all/2026-2/ABB122-2',
      );
      // 월3,4,5 D동325 = 11:00~14:00.
      expect(writing.meetings.single.originalStartMinute, 11 * 60);
      expect(writing.meetings.single.originalEndMinute, 14 * 60);
      expect(writing.meetings.single.classroom, 'D동325');
      // Search is open; courses without a published time stay unaddable.
      expect(UniversitySupportPolicy.timetableAvailable('inje'), true);
    },
  );
}
