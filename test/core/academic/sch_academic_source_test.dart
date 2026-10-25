import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/sch_academic_source.dart';
import 'package:html/parser.dart' as html;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/sch-$year.html').readAsStringSync();

void main() {
  test('SCH whole annual response matches all 64 browser events', () {
    final events = SchAcademicSource.parse(fixture(2026), 2026);
    final rows = File(
      'test/fixtures/academic/sch-2026-browser.tsv',
    ).readAsLinesSync();
    expect(events, hasLength(64));
    expect(events.map((e) => e.title), rows.map((r) => r.split('\t').last));
    expect(events.first.start, DateTime(2026, 1, 1));
    final correction = events.singleWhere(
      (e) => e.title == '2026학년도 2학기 성적열람 및 정정기간',
    );
    expect(correction.start, DateTime(2026, 12, 29));
    expect(correction.end, DateTime(2027, 1, 8));
  });

  test(
    'SCH sends language header and retains previous winter crossing January',
    () async {
      final requested = <int>[];
      final source = SchAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.headers['Accept-Language'], contains('ko-KR'));
          expect(
            request.url.queryParameters['board_no'],
            '20110224223754285127',
          );
          final year = int.parse(
            request.url.queryParameters['defparam-year_month']!.substring(0, 4),
          );
          requested.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, [2025, 2026]);
      final winter = events.singleWhere(
        (e) => e.title == '2025학년도 동계학기 강좌 수강기간(공휴일, 주말 제외 15일)',
      );
      expect(winter.start, DateTime(2025, 12, 24));
      expect(winter.end, DateTime(2026, 1, 16));
      expect(events.any((e) => e.title == '2025학년도 하계학기 강좌 수강'), isFalse);
    },
  );

  test('every published SCH row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.schedule-board .info > .section .list dl > dt')
          .length;
      expect(rows, year == 2025 ? 65 : 64);
      expect(SchAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });

  test('SCH profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000142',
      'academyinfo:0000142',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '순천향대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'sch',
      );
    }
  });

  test('SCH fails on year, invalid dates and incomplete month/entry', () {
    expect(
      () => SchAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    for (final body in [
      fixture(2026).replaceFirst('01.01(목)', '01.32(목)'),
      fixture(
        2026,
      ).replaceFirst('section month_1 active', 'section month_2 active'),
      fixture(2026).replaceFirst('<dd>', '<span>'),
    ]) {
      expect(() => SchAcademicSource.parse(body, 2026), throwsFormatException);
    }
  });

  test('SCH rejects unavailable HTTP response', () async {
    final source = SchAcademicSource(
      client: MockClient((_) async => http.Response('error', 500)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
