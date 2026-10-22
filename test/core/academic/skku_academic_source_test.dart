import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/skku_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/skku-$year.html').readAsStringSync();
void main() {
  test(
    'SKKU keeps January and February from the previous academic year',
    () async {
      final requested = <int>[];
      final source = SkkuAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/skku/edu/bachelor/ca_de_schedule.do');
          expect(r.url.queryParameters['mode'], 'view');
          final year = int.parse(r.url.queryParameters['srBachelorYear']!);
          requested.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, [2025, 2026]);
      expect(events, hasLength(90));
      expect(events.where((e) => e.title == '1학기 개강'), hasLength(1));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
      expect(
        events.any(
          (e) =>
              e.title == '2026학년도 1학기 일반휴학 신청' &&
              e.start == DateTime(2026, 1, 26) &&
              e.end == DateTime(2026, 3, 7),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2027학년도 1학기 일반휴학 신청' &&
              e.start == DateTime(2027, 1, 25) &&
              e.end == DateTime(2027, 3, 6),
        ),
        isFalse,
      );
    },
  );
  test('every published SKKU record is imported for each academic year', () {
    final rows = <int, int>{};
    for (final year in [2025, 2026]) {
      final text = html
          .parse(fixture(year))
          .querySelector('textarea[name=articleText]')!
          .text;
      final months = (jsonDecode(text) as Map).values;
      rows[year] = months.fold<int>(
        0,
        (n, group) => n + ((group as List).single as Map)['size'] as int,
      );
      expect(
        SkkuAcademicSource.parse(fixture(year), year),
        hasLength(rows[year]),
      );
    }
    expect(rows, {2025: 90, 2026: 91});
  });
  test('SKKU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000133',
      'academyinfo:0000133',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '성균관대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'skku',
      );
    }
  });
  test('SKKU rejects wrong year, malformed date and record count drift', () {
    expect(
      () => SkkuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => SkkuAcademicSource.parse(
        fixture(2026).replaceFirst('2026-03-01', '2026-02-30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SkkuAcademicSource.parse(
        fixture(
          2026,
        ).replaceFirst('&#034;size&#034;:11', '&#034;size&#034;:12'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
