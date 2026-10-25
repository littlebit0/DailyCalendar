import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/cbnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/cbnu-$year.html').readAsStringSync();
void main() {
  test(
    'CBNU whole year preserves winter and removes cross-month duplication',
    () async {
      final source = CbnuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters['month'], 'all');
          expect(request.url.queryParameters['currentY'], '2026');
          return http.Response(
            fixture(2026),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      final winter = events.where((e) => e.title == '동기계절수업').toList();
      expect(winter.map((e) => (e.start, e.end)), [
        (DateTime(2025, 12, 22), DateTime(2026, 1, 14)),
        (DateTime(2026, 12, 21), DateTime(2027, 1, 13)),
      ]);
      expect(events.where((e) => e.title == '하기계절수업'), hasLength(1));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('every published CBNU row is imported for each year', () {
    for (final (year, rows, distinct) in [(2025, 78, 68), (2026, 78, 68)]) {
      final published = html
          .parse(fixture(year))
          .querySelectorAll('.schedule_content tbody > tr:not(.datenum)')
          .map(
            (row) => row
                .querySelectorAll('td')
                .map((c) => c.text.replaceAll(RegExp(r'\s+'), ' ').trim())
                .join('|'),
          )
          .toList();
      expect(published, hasLength(rows));
      // A period spanning months is listed under each month it touches.
      expect(published.toSet(), hasLength(distinct));
      expect(
        CbnuAcademicSource.parse(fixture(year), year),
        hasLength(distinct),
      );
    }
  });
  test('CBNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000030',
      'academyinfo:0000030',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '충북대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'cbnu',
      );
    }
  });
  test('CBNU rejects wrong year and rolled invalid date', () {
    expect(
      () => CbnuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => CbnuAcademicSource.parse(
        fixture(2026).replaceFirst('01.05.', '02.30.'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
