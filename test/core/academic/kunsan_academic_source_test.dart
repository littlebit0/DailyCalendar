import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kunsan_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/kunsan-$year.html').readAsStringSync();

// The 2025 page publishes this row as 10/30 ~ 10/02, which ends before it starts.
const sourceErrorRow = '10/30(목) ~ 10/02(목)';

KunsanAcademicSource source(Map<int, String> pages, List<int> years) =>
    KunsanAcademicSource(
      client: MockClient((request) async {
        expect(request.url.host, 'www.kunsan.ac.kr');
        expect(request.url.queryParameters['menuCd'], 'DOM_000000103001001000');
        final year = int.parse(request.url.queryParameters['sYear']!);
        years.add(year);
        return http.Response(
          pages[year]!,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

void main() {
  test('Kunsan 2026 reads only the official 2026 academic year', () async {
    final years = <int>[];
    final kunsan = source({2026: fixture(2026)}, years);
    final events = await kunsan.fetch(2026);
    kunsan.close();
    expect(years, [2026]);
    expect(events, hasLength(63));
    expect(events.map((e) => e.sourceId).toSet(), hasLength(63));
    expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    expect(events.every((e) => !e.start.isBefore(DateTime(2026, 3))), isTrue);
    expect(
      events.any(
        (e) =>
            e.title == '2026학년도 1학기 개강' &&
            e.start == DateTime(2026, 3, 3) &&
            e.sourceId == '2026학년도 1학기 개강:2026-3-3',
      ),
      isTrue,
    );
  });
  test('Kunsan 2025 is rejected as unsupported without any request', () async {
    final years = <int>[];
    final kunsan = source({2025: fixture(2025)}, years);
    await expectLater(kunsan.fetch(2025), throwsFormatException);
    kunsan.close();
    expect(years, isEmpty);
  });
  test('Kunsan 2027 keeps winter rows of the 2026 academic year', () async {
    // The 2027 page here is the 2026 page shifted by one year.
    final next = fixture(
      2026,
    ).replaceAll('2027', '2028').replaceAll('2026', '2027');
    final years = <int>[];
    final kunsan = source({2026: fixture(2026), 2027: next}, years);
    final events = await kunsan.fetch(2027);
    kunsan.close();
    expect(years, [2026, 2027]);
    final carried = events.where((e) => e.url.contains('sYear=2026')).toList();
    expect(carried, hasLength(11));
    expect(carried.every((e) => e.start.isBefore(DateTime(2027, 3))), isTrue);
    expect(
      carried.any(
        (e) =>
            e.title == '2027학년도 1학기 휴·복학 신청' &&
            e.start == DateTime(2027, 1, 18) &&
            e.sourceId == '2027학년도 1학기 휴·복학 신청:2027-1-18',
      ),
      isTrue,
    );
    expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
  });
  test('every published Kunsan 2026 row is imported', () {
    final body = fixture(2026);
    final rows = html
        .parse(body)
        .querySelectorAll('table.ctable02 > tbody > tr')
        .length;
    expect(rows, 74);
    expect(KunsanAcademicSource.parse(body, 2026), hasLength(rows));
  });
  test('Kunsan profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000009',
      'academyinfo:0000009',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립군산대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'kunsan',
      );
    }
  });
  test(
    'Kunsan rejects source error when relevant, without inventing an end date',
    () {
      final previous = fixture(2025);
      expect(previous, contains(sourceErrorRow));
      expect(
        () => KunsanAcademicSource.parse(previous, 2025),
        throwsFormatException,
      );
      expect(
        () => KunsanAcademicSource.parse(previous, 2025, requestedYear: 2026),
        returnsNormally,
      );
      final current = fixture(
        2026,
      ).replaceFirst('10/30(금)', '10/30(금) ~ 10/02(금)');
      expect(
        () => KunsanAcademicSource.parse(current, 2026, requestedYear: 2026),
        throwsFormatException,
      );
    },
  );
  test('Kunsan requires the selected year and twelve months', () {
    final body = fixture(2026);
    expect(() => KunsanAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => KunsanAcademicSource.parse(
        body.replaceFirst('>03월</th>', '>04월</th>'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KunsanAcademicSource.parse(
        body.replaceFirst('03/03(화)', '03/32(화)'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test('Kunsan failed response is an error', () async {
    final source = KunsanAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
