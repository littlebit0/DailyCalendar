import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/catholic_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/catholic-$year.json').readAsStringSync();
void main() {
  test('CUK requests one calendar year and keeps cross-year rows', () async {
    final requested = <Map<String, String>>[];
    final source = CatholicAcademicSource(
      client: MockClient((r) async {
        expect(r.url.host, 'www.catholic.ac.kr');
        expect(r.url.path, '/ko/support/calendar2024_list.do');
        requested.add(r.url.queryParameters);
        return http.Response.bytes(
          utf8.encode(fixture(2026)),
          200,
          headers: {'content-type': 'application/json;charset=UTF-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(requested, [
      {
        'mode': 'getCalendarData',
        'siteId': 'ko',
        'start': '2026-01-01',
        'end': '2027-01-01',
      },
    ]);
    // 원문 64행 중 대학원 전용 가을 학위수여식 1행 제외.
    expect(events, hasLength(63));
    final winter = events.singleWhere((e) => e.sourceId == '1784');
    expect(winter.title, '계절학기 수업 (성심교정)');
    expect(winter.start, DateTime(2025, 12, 22));
    expect(winter.end, DateTime(2026, 1, 14));
    expect(winter.url, endsWith('selectedYear=2025'));
    expect(
      events.any(
        (e) =>
            e.title == '1학기 개시일 / 신입생 입학미사 (성심교정·성의교정·성신교정)' &&
            e.start == DateTime(2026, 3, 3) &&
            e.end == DateTime(2026, 3, 4) &&
            e.url.endsWith('selectedYear=2026'),
      ),
      isTrue,
    );
  });
  test('every published CUK row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final data = jsonDecode(fixture(year))['data'] as List;
      final rows = data.length;
      final graduateOnly = data
          .where(
            (r) => CatholicAcademicSource.graduateOnly.hasMatch(r['content']),
          )
          .length;
      final events = CatholicAcademicSource.parse(fixture(year), year);
      expect(rows, year == 2025 ? 60 : 64);
      expect(graduateOnly, 1);
      expect(events, hasLength(rows - graduateOnly));
      expect(
        events.map((e) => e.sourceId).toSet(),
        hasLength(rows - graduateOnly),
      );
    }
  });
  test('CUK leaves out graduate-school-only rows but keeps shared ones', () {
    final events = CatholicAcademicSource.parse(fixture(2026), 2026);
    expect(events.any((e) => e.title.contains('대학원')), isFalse);
    expect(events.where((e) => e.title.startsWith('가을 학위수여식')), hasLength(1));
    final rows = jsonEncode({
      'data': [
        for (final (i, content) in [
          '가을 학위수여식 (대학원)',
          '[대학원] 입학식',
          '학위수여식',
        ].indexed)
          {
            'cSeq': i + 1,
            'siteId': 'ko',
            'content': content,
            'campus': '성심',
            'beginDt': 1788130800000,
            'endDt': 1788130800000,
          },
      ],
    });
    expect(CatholicAcademicSource.parse(rows, 2026).map((e) => e.sourceId), [
      '3',
    ]);
  });
  test('CUK profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000046',
      'academyinfo:0000046',
      'academyinfo:0000048',
      'academyinfo:0000049',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '가톨릭대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'catholic',
      );
    }
    for (final campus in [
      'academyinfo:0000046',
      'academyinfo:0000048',
      'academyinfo:0000049',
    ]) {
      expect(
        AcademicProfile(
          universityId: 'institution:academyinfo:0000046',
          universityName: '가톨릭대학교',
          schoolKind: 'fourYear',
          campusId: campus,
        ).academicSourceId,
        'catholic',
      );
    }
  });
  test('CUK rejects unknown campus, malformed rows and empty calendars', () {
    final body = fixture(2026);
    expect(
      () =>
          CatholicAcademicSource.parse(body.replaceFirst('"성심"', '"서울"'), 2026),
      throwsFormatException,
    );
    expect(
      () => CatholicAcademicSource.parse(
        body.replaceFirst('"beginDt":1766329200000', '"beginDt":"x"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => CatholicAcademicSource.parse(
        body.replaceFirst('"beginDt":1766329200000', '"beginDt":1799999999000'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => CatholicAcademicSource.parse('{"data":[]}', 2026),
      throwsFormatException,
    );
    expect(
      () => CatholicAcademicSource.parse('<html></html>', 2026),
      throwsFormatException,
    );
  });
  test('CUK treats a failed response as an error', () async {
    final source = CatholicAcademicSource(
      client: MockClient((_) async => http.Response('', 500)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
