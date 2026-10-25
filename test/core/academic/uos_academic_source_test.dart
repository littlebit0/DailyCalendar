import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/uos_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/uos-$year.html').readAsStringSync();
void main() {
  test(
    'UOS uses official anonymous URL and resolves cross-year rows',
    () async {
      final source = UosAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters['identified'], 'anonymous');
          expect(request.url.queryParameters['year_code'], '2026');
          return http.Response(
            fixture(2026),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(57));
      final winters = events
          .where((e) => e.title.startsWith('겨울 계절수업'))
          .toList();
      expect(winters.map((e) => (e.start, e.end)), [
        (DateTime(2025, 12, 22), DateTime(2026, 1, 20)),
        (DateTime(2026, 12, 22), DateTime(2027, 1, 20)),
      ]);
      // Earlier versions used the same start:last:title source ID.
      expect(
        winters.first.sourceId,
        '2025-12-22:2026-01-19:겨울 계절수업 [Winter session]',
      );
      expect(
        events.where((e) => e.title == '여름 계절수업 [Summer session]').single.end,
        DateTime(2026, 7, 18),
      );
    },
  );
  test('every published UOS row is imported for each year', () {
    for (final (year, expected) in [(2025, 58), (2026, 57)]) {
      // A row spanning two months is listed again under the second month.
      var rows = 0;
      final byMonth = <int, Set<String>>{};
      for (final row in html.parse(fixture(year)).querySelectorAll('tr[id]')) {
        final m = RegExp('^m$year(\\d{2})c\\d+\$').firstMatch(row.id);
        if (m == null) continue;
        final key = [
          '.date02',
          '.title01',
        ].map((c) => row.querySelector(c)!.text.trim()).join('|');
        final month = int.parse(m[1]!);
        byMonth.putIfAbsent(month, () => {}).add(key);
        if (!(byMonth[month - 1]?.contains(key) ?? false)) rows++;
      }
      expect(rows, expected);
      expect(UosAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });
  test('UOS profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000040',
      'academyinfo:0000040',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '서울시립대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'uos',
      );
    }
  });
  test('UOS rejects wrong year, missing dates and invalid dates', () {
    expect(
      () => UosAcademicSource.parse(fixture(2026), 2027),
      throwsFormatException,
    );
    expect(
      () => UosAcademicSource.parse(
        fixture(2026).replaceFirst('[01-12', '[01-32'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => UosAcademicSource.parse(
        fixture(2026).replaceFirst('class="th date02"', 'class="th"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => UosAcademicSource.parse(
        fixture(2026).replaceAll('id="m202604c', 'id="x202604c'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
