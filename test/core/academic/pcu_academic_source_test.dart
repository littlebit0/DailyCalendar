import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/pcu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/pcu-$year.html').readAsStringSync();
void main() {
  test(
    'PCU calendar keeps the year and December rows that cross into it',
    () async {
      final requested = <String>[];
      final source = PcuAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/kor/30/schedules/CAT072');
          final year = r.url.queryParameters['year']!;
          requested.add(year);
          return http.Response(
            fixture(int.parse(year)),
            200,
            headers: {'content-type': 'text/html;charset=UTF-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['2025', '2026']);
      // 73 rows starting in 2026 plus one 2025 row that ends in January 2026.
      expect(events, hasLength(74));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(74));
      expect(
        events.any(
          (e) =>
              e.title == '2학기 성적공람 및 이의신청' &&
              e.start == DateTime(2025, 12, 29) &&
              e.end == DateTime(2026, 1, 3),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2학기 성적공람 및 이의신청' &&
              e.start == DateTime(2026, 12, 28) &&
              e.end == DateTime(2027, 1, 5),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '1학기 시작, 3·1절' &&
              e.start == DateTime(2026, 3, 1) &&
              e.end == DateTime(2026, 3, 2) &&
              e.sourceId == '2026-03-01T00:00:00.000:1학기 시작, 3·1절',
        ),
        isTrue,
      );
      expect(
        events.every((e) => e.start.year == 2026 || e.end.year == 2026),
        isTrue,
      );
    },
  );
  test('every published PCU row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('#school_cal .txts > ol > li > ul > li')
          .length;
      expect(rows, {2025: 83, 2026: 86}[year]);
      expect(PcuAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });
  test('PCU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000113',
      'academyinfo:0000113',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '배재대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'pcu',
      );
    }
  });
  test('PCU rejects wrong year, malformed dates and missing months', () async {
    expect(
      () => PcuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => PcuAcademicSource.parse(
        fixture(2026).replaceFirst('02-24일', '02-30일'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => PcuAcademicSource.parse(
        fixture(2026).replaceFirst('03-03일', '04-03일'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => PcuAcademicSource.parse(
        fixture(2026).replaceFirst('<li class="one">', '<p class="one">'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => PcuAcademicSource.parse('<html></html>', 2026),
      throwsFormatException,
    );
    final failing = PcuAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(failing.fetch(2026), throwsFormatException);
    failing.close();
  });
}
