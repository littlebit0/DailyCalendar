import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kookmin_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/kookmin-$year.html').readAsStringSync();

void main() {
  test(
    'Kookmin retains next January winter class period and preceding January',
    () async {
      final requested = <String>[];
      final source = KookminAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/user/scGuid/scSchedule/index.do');
          final year = request.url.queryParameters['yyyy']!;
          requested.add(year);
          return http.Response(
            fixture(int.parse(year)),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(requested, ['2025', '2026']);
      // 7 rows of academic year 2025 reach into 2026, plus 55 of 2026.
      expect(events, hasLength(62));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(62));
      final winter = events.singleWhere(
        (e) => e.title == '동계 계절학기 수업 기간' && e.start.year == 2026,
      );
      expect(winter.start, DateTime(2026, 12, 22));
      expect(winter.end, DateTime(2027, 1, 14));
      final previousWinter = events.singleWhere(
        (e) => e.title == '동계 계절학기 수업 기간' && e.start.year == 2025,
      );
      expect(previousWinter.end, DateTime(2026, 1, 14));
      expect(
        events.any(
          (e) =>
              e.title == '2025학년도 전기 학위수여식' &&
              e.start == DateTime(2026, 2, 11) &&
              e.end == DateTime(2026, 2, 12),
        ),
        isTrue,
      );
    },
  );

  test('every published Kookmin row is imported for each year', () {
    for (final (year, published) in [(2025, 48), (2026, 60)]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('#monthTable tr')
          .length;
      expect(rows, published);
      final events = KookminAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(rows));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(rows));
    }
  });

  test('Kookmin profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000078',
      'academyinfo:0000078',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국민대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'kookmin',
      );
    }
  });

  test('Kookmin fails instead of returning a partial calendar', () async {
    final source = KookminAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(source.close);
    await expectLater(source.fetch(2026), throwsFormatException);
  });

  test('Kookmin rejects incorrect year and malformed published dates', () {
    expect(
      () => KookminAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => KookminAcademicSource.parse(
        fixture(
          2026,
        ).replaceFirst('03.03 (화) ~ 03.03 (화)', '03.32 (화) ~ 03.32 (화)'),
        2026,
      ),
      throwsFormatException,
    );
    // A weekday that disagrees with the inferred year is rejected.
    expect(
      () => KookminAcademicSource.parse(
        fixture(
          2026,
        ).replaceFirst('03.03 (화) ~ 03.03 (화)', '03.03 (수) ~ 03.03 (수)'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KookminAcademicSource.parse(
        fixture(2026).replaceFirst('id="monthTable"', 'id="missing"'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
