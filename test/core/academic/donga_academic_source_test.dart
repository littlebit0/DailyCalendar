import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/donga_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final page = File('test/fixtures/academic/donga-2026.html').readAsStringSync();
String legacy(int year) =>
    File('test/fixtures/academic/donga-legacy-$year.html').readAsStringSync();

DongaAcademicSource source() => DongaAcademicSource(
  client: MockClient((r) async {
    final legacyYear = int.tryParse(
      r.url.queryParameters['calendar_year'] ?? '',
    );
    final String body;
    if (r.url.toString() ==
        'https://www.donga.ac.kr/community/academic-calendar') {
      body = page;
    } else if (legacyYear != null &&
        r.url == DongaAcademicSource.legacyYear(legacyYear)) {
      body = legacy(legacyYear);
    } else {
      fail('Unexpected request ${r.url}');
    }
    return http.Response(
      body,
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

  test('every listed legacy row is imported, across the year boundary', () {
    for (final (year, count) in [
      (2024, 33),
      (2025, 23),
      (2026, 2),
      (2027, 0),
    ]) {
      final body = legacy(year);
      final rows = html
          .parse(body)
          .querySelectorAll('.sch-monlist-wr.yearly .daily-li:not(.hasNoData)');
      expect(rows, hasLength(count), reason: '$year');
      final events = DongaAcademicSource.parseLegacy(body, year);
      expect(events, hasLength(count), reason: '$year');
      expect(events.map((e) => e.sourceId).toSet(), hasLength(count));
    }
    final winter = DongaAcademicSource.parseLegacy(
      legacy(2025),
      2025,
    ).singleWhere((e) => e.title == '동계방학');
    expect(winter.start, DateTime(2025, 12, 20));
    expect(winter.end, DateTime(2026, 3));
    for (final broken in [
      legacy(2025).replaceFirst(
        '<em class="year">2025</em>',
        '<em class="year">2024</em>',
      ),
      legacy(
        2025,
      ).replaceFirst('yearly" data-month="12"', 'yearly" data-month="13"'),
      legacy(2025).replaceFirst('12. 27(SAT)', '11. 31(SAT)'),
    ]) {
      expect(
        () => DongaAcademicSource.parseLegacy(broken, 2025),
        throwsFormatException,
      );
    }
  });

  test('calendar year keeps overlapping rows of every academic year', () async {
    final s = source();
    try {
      final events = await s.fetch(2026);
      // 2026 academic-year rows ending in 2027 drop out; the Labour Day
      // holiday row and the schedule row of the same day share one ID. The
      // previous academic year adds its December rows running into 2026 and
      // its January/February rows.
      expect(events, hasLength(54));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(54));
      final winters = events.where((e) => e.title == '동계방학').toList();
      expect(winters.map((e) => (e.start, e.end)), [
        (DateTime(2025, 12, 20), DateTime(2026, 3)),
        (DateTime(2026, 12, 19), DateTime(2027, 3)),
      ]);
      final graduation = events.singleWhere(
        (e) => e.title == '학위수여식' && e.start.year == 2026,
      );
      expect(graduation.end, DateTime(2026, 2, 28));
      final next = await s.fetch(2027);
      expect(next.map((e) => e.title), ['동계방학', '성적공시 및 정정', '성적확정', '학위수여식']);
      expect(next.last.end, DateTime(2027, 2, 27));
      // Past academic year: every 2025 row plus 2024 December rows into 2025.
      final past = await s.fetch(2025);
      expect(past, hasLength(25));
      expect(past.first.title, '동계방학');
      expect(past.first.start, DateTime(2024, 12, 24));
      expect(past.last.title, '성적공시 및 정정');
      expect(past.last.end, DateTime(2026, 1, 3));
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
