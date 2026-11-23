import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 근거: 학사운영에 관한 규칙 제53조(50분+휴식 10분), 메카트로닉스공학부·산업경영학부
  // 공식 시간표의 1A~13B=09:00~22:00(30분 단위), 메카 학사공지 56180의
  // "SHA590 02분반 금요일 13:00 ~ 16:00".
  test('Koreatech 교시 표기는 1교시 09:00부터 A·B 30분 단위로 계산된다', () async {
    final catalog = await UniversityCatalog.load(university: 'koreatech');
    final courses = [
      for (final d in catalog.where((d) => d.universityId == 'koreatech'))
        ...d.courses,
    ];
    final scheduled = courses.where((c) => c.hasSchedulableMeetings).toList();
    expect(courses, hasLength(791));
    expect(scheduled, hasLength(765));
    for (final c in scheduled) {
      for (final m in c.meetings) {
        // 표에 없는 14교시는 같은 30분 칸으로 이어 계산한다(2026-11-23 사용자 결정).
        expect(m.originalStartMinute, inInclusiveRange(540, 1350));
        expect(m.originalEndMinute, inInclusiveRange(570, 1380));
        expect(m.originalStartMinute % 30, 0);
      }
    }
    final sha = courses.singleWhere(
      (c) => c.code == 'SHA590' && c.section == '02',
    );
    expect(
      sha.meetings
          .map((m) => (m.weekday, m.originalStartMinute, m.originalEndMinute))
          .toSet(),
      {(5, 780, 960)},
    );
    final night = courses.singleWhere(
      (c) => c.code == 'ARD711' && c.section == '01',
    );
    expect(
      night.meetings
          .map((m) => (m.weekday, m.originalStartMinute, m.originalEndMinute))
          .toSet(),
      {(3, 840, 900), (3, 1080, 1380)},
    );
    expect(
      courses.where((c) => c.scheduleStatus == 'unrecognized').map((c) => c.code),
      unorderedEquals(['MEC367', 'MCA333', 'BSM632']),
    );
  });
}
