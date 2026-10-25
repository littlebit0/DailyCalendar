import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/eulji_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/eulji-$year-${month.toString().padLeft(2, '0')}.html',
).readAsStringSync();

EuljiAcademicSource fixtureSource(int year, [List<int>? months]) =>
    EuljiAcademicSource(
      client: MockClient((request) async {
        final month = int.parse(request.url.queryParameters['month']!);
        months?.add(month);
        expect(request.url.queryParameters['year'], '$year');
        expect(request.url.queryParameters['calendar_no'], '105');
        expect(request.headers['User-Agent'], 'Mozilla/5.0');
        return http.Response(
          fixture(year, month + 1),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

void main() {
  test('Eulji all twelve native public months and semester end', () {
    final rows = [
      for (var month = 1; month <= 12; month++)
        ...EuljiAcademicSource.parse(fixture(2026, month), 2026, month),
    ];
    expect(rows.length, greaterThan(50));
    expect(
      rows.any(
        (e) =>
            e.start == DateTime(2026, 12, 15) &&
            e.end == DateTime(2026, 12, 22) &&
            e.title.contains('보강'),
      ),
      true,
    );
  });
  test(
    'Eulji full fetch deduplicates native events across adjacent months',
    () async {
      final months = <int>[];
      final source = fixtureSource(2026, months);
      final rows = await source.fetch(2026);
      source.close();
      expect(months, List.generate(12, (index) => index));
      expect(rows.map((e) => e.sourceId).toSet().length, rows.length);
      expect(rows.where((e) => e.title == '을지축전').length, 1);
    },
  );
  test('every published Eulji row is imported for each year', () async {
    for (final (year, count) in [(2025, 60), (2026, 62)]) {
      // A row spanning two months is published in both month lists.
      final published = <String>{
        for (var month = 1; month <= 12; month++)
          for (final row
              in html
                  .parse(fixture(year, month))
                  .querySelectorAll('table.board-data tbody tr'))
            '${row.querySelector('td.first')!.text}|'
                '${row.querySelector('td.subject strong')!.text}',
      };
      expect(published, hasLength(count));
      final source = fixtureSource(year);
      final events = await source.fetch(year);
      source.close();
      expect(events, hasLength(count));
    }
  });
  test('Eulji keeps date-and-title IDs and cross-year sessions', () async {
    final source = fixtureSource(2026);
    final events = await source.fetch(2026);
    source.close();
    final winter = events.singleWhere(
      (e) => e.sourceId == '2025-12-30/2026-01-19/계절학기 수업',
    );
    expect(winter.start, DateTime(2025, 12, 30));
    expect(winter.end, DateTime(2026, 1, 20));
    expect(
      winter.url,
      'https://eulji.ac.kr/renewal/index.html?menuno=8069&calendar_no=105&year=2025&month=11',
    );
    expect(
      events.any(
        (e) =>
            e.sourceId == '2026-12-22/2027-01-11/계절학기 수업' &&
            e.end == DateTime(2027, 1, 12),
      ),
      isTrue,
    );
  });
  test('Eulji profiles on every campus resolve to its calendar', () {
    for (final (university, campus) in [
      ('institution:academyinfo:0000161', null),
      ('institution:academyinfo:0000161', 'academyinfo:0000161'),
      ('institution:academyinfo:0000161', 'academyinfo:0000162'),
      ('institution:academyinfo:0000161', 'academyinfo:0002911'),
      ('academyinfo:0000161', null),
      ('academyinfo:0000162', null),
      ('academyinfo:0002911', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: university,
          universityName: '을지대학교',
          schoolKind: 'fourYear',
          campusId: campus,
        ).academicSourceId,
        'eulji',
      );
    }
  });
  test('Eulji rejects another month and malformed published date', () {
    expect(
      () => EuljiAcademicSource.parse(fixture(2026, 3), 2026, 4),
      throwsFormatException,
    );
    expect(
      () => EuljiAcademicSource.parse(fixture(2026, 3), 2025, 3),
      throwsFormatException,
    );
    expect(
      () => EuljiAcademicSource.parse(
        fixture(2026, 3).replaceFirst('2026.03.03', '2026.02.30'),
        2026,
        3,
      ),
      throwsFormatException,
    );
  });
  test(
    'Eulji unrelated client failure propagates without alternate transport',
    () async {
      var calls = 0;
      final source = EuljiAcademicSource(
        client: MockClient((request) async {
          calls++;
          throw http.ClientException('unrelated network failure');
        }),
      );
      await expectLater(
        source.fetch(2026),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 1);
      source.close();
    },
  );
  test('Eulji failed response is an error, not an empty calendar', () async {
    final source = EuljiAcademicSource(
      client: MockClient((request) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
