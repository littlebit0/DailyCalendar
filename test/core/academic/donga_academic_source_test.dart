import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/donga_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final page = File('test/fixtures/academic/donga-2026.html').readAsStringSync();
final feed =
    jsonDecode(File('test/fixtures/academic/donga-api.json').readAsStringSync())
        as Map<String, dynamic>;

DongaAcademicSource source() => DongaAcademicSource(
  client: MockClient((r) async {
    final month = RegExp(
      r'^/api/v2/cms/donga_kor/schedule/public/(\d{4}/\d{1,2})$',
    ).firstMatch(r.url.path)?[1];
    final String body;
    if (r.url.toString() ==
        'https://www.donga.ac.kr/community/academic-calendar') {
      body = page;
    } else if (r.url.host == 'www.donga.ac.kr' && feed.containsKey(month)) {
      body = jsonEncode(feed[month]);
    } else {
      fail('Unexpected request ${r.url}');
    }
    return http.Response.bytes(
      utf8.encode(body),
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

  test('the month feed keeps add/drop, enrolment and event rows', () {
    final events = DongaAcademicSource.parseMonth(jsonEncode(feed['2026/9']));
    expect(
      events.map((e) => e.title),
      containsAll(['3차 수강신청(정정)', '수강취소', '분할납부 2차', '2026학년도 취업・진로박람회']),
    );
    final payment = DongaAcademicSource.parseMonth(
      jsonEncode(feed['2026/11']),
    ).singleWhere((e) => e.title == '분할납부 4차');
    // Timed rows stay date-only so all-day handling never shifts them.
    expect(payment.start, DateTime(2026, 11, 12));
    expect(payment.end, DateTime(2026, 11, 14));
    expect(DongaAcademicSource.parseMonth(jsonEncode(feed['2027/3'])), isEmpty);
    for (final broken in [
      '{"success":false,"data":null}',
      '{"success":true,"data":{}}',
      '{"success":true,"data":{"schedules":[{"status":"ACTIVE","title":"x","startDate":null,"endDate":null}]}}',
      '{"success":true,"data":{"schedules":[{"status":"ACTIVE","title":"","startDate":"2026-01-01T00:00:00","endDate":"2026-01-01T00:00:00"}]}}',
    ]) {
      expect(
        () => DongaAcademicSource.parseMonth(broken),
        throwsFormatException,
      );
    }
    expect(
      DongaAcademicSource.parseMonth(
        '{"success":true,"data":{"schedules":[{"status":"DELETED","title":"x","startDate":"2026-01-01T00:00:00","endDate":"2026-01-01T00:00:00"}]}}',
      ),
      isEmpty,
    );
  });

  test('calendar year keeps overlapping rows of every academic year', () async {
    final s = source();
    try {
      final events = await s.fetch(2026);
      // 2026 academic-year rows ending in 2027 drop out; the Labour Day
      // holiday row and the schedule row of the same day share one ID. The
      // feed adds the previous academic year's rows running into 2026, its
      // January/February rows and 11 add/drop, enrolment and event rows.
      expect(events, hasLength(65));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(65));
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
