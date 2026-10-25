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
        // No official undergraduate period-to-clock text: nothing is timed.
        expect(c['scheduleStatus'], 'unrecognized');
        expect(c['schedules'], isEmpty);
        final education = c['sourceEducation'] as Map;
        for (final row in education['nativeRows'] as List) {
          expect(rows.add(row['sourceRow'] as int), true);
        }
        final reason = education['holdReason'] as String;
        reasons[reason] = (reasons[reason] ?? 0) + 1;
      }
      expect(rows, hasLength(1838));
      expect(reasons, {
        '학부 교시→시각(HH:mm) 공식 원문 미확인': 1589,
        '수업계획서 수업시간·강의실 칸 비어 있음': 84,
        '수업계획서 미등록(인나비 목록에 출력 버튼 없음)': 80,
        "수업계획서 출력 서버 오류(XML 대신 'AA문자열이나 이진 데이터는 잘립니다.' 응답)": 3,
      });
      expect(dataset.courses.every((c) => c.meetings.isEmpty), true);
      // Timetable search stays suspended while clock times are unresolved.
      expect(UniversitySupportPolicy.timetableAvailable('inje'), false);
    },
  );
}
