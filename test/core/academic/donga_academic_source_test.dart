import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/donga_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final page = File('test/fixtures/academic/donga-2026.html').readAsStringSync();

DongaAcademicSource source() => DongaAcademicSource(
  client: MockClient((r) async {
    expect(
      r.url.toString(),
      'https://www.donga.ac.kr/community/academic-calendar',
    );
    return http.Response(
      page,
      200,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }),
);

void main() {
  test('every published Donga row is imported', () {
    final doc = html.parse(page);
    final tables = doc.querySelectorAll('table.dau-cd-tbl');
    final schedule = tables[0].querySelectorAll('tbody > tr').length;
    final milestones = doc.querySelectorAll('.dau-cal-glist > li').length;
    final makeup = tables[1].querySelectorAll('tbody > tr').length;
    expect((schedule, milestones, makeup), (23, 12, 8));
    final events = DongaAcademicSource.parseAnnual(page);
    // Two opening days; each make-up row is a holiday and its make-up day.
    expect(events, hasLength(schedule + milestones + 2 + makeup * 2));
    for (final row in tables[0].querySelectorAll('tbody > tr')) {
      final title = row.querySelectorAll('td').first.text.trim();
      expect(events.any((e) => e.title == title), isTrue, reason: title);
    }
    final chuseok = events.where((e) => e.title == '추석').map((e) => e.start);
    expect(chuseok, [DateTime(2026, 9, 24), DateTime(2026, 9, 25)]);
    expect(
      events.where((e) => e.title == '제2학기 지정보강일(추석)').map((e) => e.start),
      [DateTime(2026, 12, 10), DateTime(2026, 12, 11)],
    );
    expect(events.where((e) => e.title.endsWith('학기 개시일')), hasLength(2));
  });

  test('calendar year keeps overlapping rows of the academic year', () async {
    final s = source();
    try {
      final events = await s.fetch(2026);
      // Rows ending in 2027 drop out; the Labour Day holiday row and the
      // schedule row of the same day share one ID.
      expect(events, hasLength(50));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(50));
      final winter = events.singleWhere((e) => e.title == '동계방학');
      expect(winter.start, DateTime(2026, 12, 19));
      expect(winter.end, DateTime(2027, 3));
      final next = await s.fetch(2027);
      expect(next.map((e) => e.title), ['동계방학', '성적공시 및 정정', '성적확정', '학위수여식']);
      expect(next.last.end, DateTime(2027, 2, 27));
      await expectLater(s.fetch(2025), throwsFormatException);
    } finally {
      s.close();
    }
  });

  test('Donga profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000105',
      'academyinfo:0000105',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '동아대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'donga',
      );
    }
  });

  test('Donga rejects wrong year, malformed dates and missing sections', () {
    for (final broken in [
      page.replaceFirst('2026학년도 학사일정', '2025학년도 학사일정'),
      page.replaceFirst('2026. 2. 4.(수)', '2026. 2. 30.(수)'),
      page.replaceFirst('2026학년도 지정보강일', '지정보강일'),
      page.replaceFirst('dau-cal-glist', 'missing'),
      page.replaceFirst('2학기 개시일', '개시일'),
    ]) {
      expect(
        () => DongaAcademicSource.parseAnnual(broken),
        throwsFormatException,
      );
    }
  });

  test('failed responses are errors', () async {
    final s = DongaAcademicSource(
      client: MockClient((_) async => http.Response('', 404)),
    );
    await expectLater(s.fetch(2026), throwsFormatException);
    s.close();
  });
}
