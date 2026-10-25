import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kmu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/kmu-$year.html').readAsStringSync();
void main() {
  test('KMU reads both academic years covering a calendar year', () async {
    final requested = <String>[];
    final source = KmuAcademicSource(
      client: MockClient((r) async {
        expect(r.url.path, '/uni/main/page.jsp');
        expect(r.url.queryParameters['mnu_uid'], '3373');
        final year = r.url.queryParameters['parm_doc_year']!;
        requested.add(year);
        return http.Response(
          fixture(int.parse(year)),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(requested, ['2025', '2026']);
    expect(events, hasLength(58));
    expect(events.map((e) => e.sourceId).toSet(), hasLength(58));
    expect(
      events.every(
        (e) =>
            e.end.isAfter(e.start) &&
            e.start.isBefore(DateTime(2027)) &&
            e.end.isAfter(DateTime(2026)),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title == '1학기 개강' &&
            e.start == DateTime(2026, 3, 3) &&
            e.end == DateTime(2026, 3, 4),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title == '2026학년도 입학식' &&
            e.start == DateTime(2026, 2, 27) &&
            e.sourceId.startsWith('2025:'),
      ),
      isTrue,
    );
    expect(events.any((e) => e.title.contains('대학원')), isFalse);
    expect(events.any((e) => e.start.month == 1), isTrue);
    expect(events.any((e) => e.start.month == 12), isTrue);
  });
  test('every published KMU row is imported for each academic year', () {
    for (final year in [2025, 2026]) {
      final titles = html
          .parse(fixture(year))
          .querySelectorAll('#schedule_month tbody[class^=ul_] > tr li')
          .map((e) => e.text.trim())
          .toList();
      final graduate = titles.where((t) => t.contains('대학원')).length;
      expect(graduate, 2);
      final events = KmuAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(titles.length - graduate));
      expect(events.map((e) => e.title).toSet(), {
        for (final t in titles)
          if (!t.contains('대학원')) t,
      });
    }
  });
  test('KMU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000068',
      'academyinfo:0000068',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '계명대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'kmu',
      );
    }
  });
  test('KMU rejects incorrect year, malformed date and missing month', () {
    expect(
      () => KmuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => KmuAcademicSource.parse(
        fixture(2026).replaceFirst(
          '<td class="taC">03-03</td>',
          '<td class="taC">03-32</td>',
        ),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KmuAcademicSource.parse(
        fixture(2026).replaceFirst(
          '<div class="calendar"><b>3월</b>',
          '<div class="calendar"><b>4월</b>',
        ),
        2026,
      ),
      throwsFormatException,
    );
  });
  test('KMU fails on an unavailable page instead of returning nothing', () {
    final source = KmuAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(source.close);
    expect(source.fetch(2026), throwsFormatException);
  });
}
