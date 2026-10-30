import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/korea_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/korea-$year-${month.toString().padLeft(2, '0')}.html',
).readAsStringSync();

KoreaAcademicSource source(List<String> requested) => KoreaAcademicSource(
  client: MockClient((r) async {
    expect(r.url.path, '/schdulMng/ko/5/monthSchdul.do');
    final q = Uri.splitQueryString(r.body);
    final y = int.parse(q['year']!), m = int.parse(q['month']!);
    requested.add('$y-$m');
    return http.Response(
      fixture(y, m),
      200,
      headers: {'content-type': 'text/html;charset=utf-8'},
    );
  }),
);

void main() {
  test('KU uses monthly duration rows for the whole year', () async {
    final requested = <String>[];
    final ku = source(requested);
    final events = await ku.fetch(2026);
    ku.close();
    expect(requested, ['2025-12', for (var m = 1; m <= 12; m++) '2026-$m']);
    expect(events, hasLength(68));
    final leave = events.singleWhere(
      (e) => e.title == '휴·복학 신청' && e.start.month == 2,
    );
    expect(leave.start, DateTime(2026, 2, 2));
    expect(leave.end, DateTime(2026, 2, 26));
    final rivalry = events.singleWhere((e) => e.title == '정기 고·연전');
    expect(rivalry.start, DateTime(2026, 10, 2));
    expect(rivalry.end, DateTime(2026, 10, 4));
    expect(events.any((e) => e.title.contains(r'\,')), isFalse);
    expect(events.any((e) => e.title == '여름방학 시작, 여름계절수업 개강'), isTrue);
  });

  test('every published KU row is imported for each year', () async {
    final expected = {2025: 52, 2026: 68};
    for (final year in expected.keys) {
      var rows = 0;
      for (var month = 1; month <= 12; month++) {
        final published = html
            .parse(fixture(year, month))
            .querySelectorAll('.sche-comt tbody tr')
            .length;
        expect(
          KoreaAcademicSource.parse(fixture(year, month), year, month),
          hasLength(published),
        );
        rows += published;
      }
      expect(rows, expected[year]);
      final ku = source([]);
      expect(await ku.fetch(year), hasLength(rows));
      ku.close();
    }
  });

  test('KU profile resolves to its registered calendar on both campuses', () {
    for (final (campus, source) in [
      (null, 'korea'),
      ('academyinfo:0000069', 'korea'),
      ('academyinfo:0000070', 'korea-sejong'),
    ]) {
      expect(
        AcademicProfile(
          universityId: 'institution:academyinfo:0000069',
          universityName: '고려대학교',
          schoolKind: 'fourYear',
          campusId: campus,
        ).academicSourceId,
        source,
      );
    }
    for (final (legacy, source) in [
      ('academyinfo:0000069', 'korea'),
      ('academyinfo:0000070', 'korea-sejong'),
    ]) {
      expect(
        AcademicProfile(
          universityId: legacy,
          universityName: '고려대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        source,
      );
    }
  });

  test('KU Sejong reads its own calendar for the whole year', () async {
    final requested = <String>[];
    final source = KoreaAcademicSource.sejong(
      client: MockClient((r) async {
        expect(r.url.host, 'sejong.korea.ac.kr');
        expect(r.url.path, '/schdulMng/koreaSejong/2/monthSchdul.do');
        final q = Uri.splitQueryString(r.body);
        final y = q['year']!, m = q['month']!.padLeft(2, '0');
        requested.add('$y-$m');
        return http.Response.bytes(
          File(
            'test/fixtures/academic/korea-sejong-$y-$m.html',
          ).readAsBytesSync(),
          200,
        );
      }),
    );
    addTearDown(source.close);
    final events = await source.fetch(2026);
    expect(requested, [
      '2025-12',
      for (var m = 1; m <= 12; m++) '2026-${'$m'.padLeft(2, '0')}',
    ]);
    expect(source.id, 'korea-sejong');
    // Sejong publishes its own date for the rivalry games.
    final rivalry = events.singleWhere((e) => e.title == '정기 고·연전');
    expect(rivalry.start, DateTime(2026, 9, 18));
    expect(rivalry.end, DateTime(2026, 9, 20));
    expect(events.every((e) => e.url == source.website.toString()), isTrue);
    expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    expect(events.first.start.isBefore(DateTime(2026, 2)), isTrue);
  });

  test(
    'KU rejects wrong year, wrong month and impossible published period',
    () {
      expect(
        () => KoreaAcademicSource.parse(fixture(2026, 2), 2025, 2),
        throwsFormatException,
      );
      expect(
        () => KoreaAcademicSource.parse(fixture(2026, 2), 2026, 3),
        throwsFormatException,
      );
      expect(
        () => KoreaAcademicSource.parse(
          fixture(2026, 2).replaceFirst('02.25', '02.32'),
          2026,
          2,
        ),
        throwsFormatException,
      );
    },
  );

  test('KU reports an unavailable month instead of returning partial data', () {
    final ku = KoreaAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(ku.fetch(2026), throwsFormatException);
  });
}
