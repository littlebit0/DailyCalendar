import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:html/parser.dart' as html;
import 'package:daily/core/academic/kongju_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/kongju-$year.html').readAsStringSync();

void main() {
  test(
    'Kongju uses fresh anonymous CSRF session for official annual UI',
    () async {
      final years = <int>[];
      final source = KongjuAcademicSource(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<script>var csrfToken = "anonymous-test";</script>',
              200,
              headers: {'set-cookie': 'JSESSIONID=anonymous; Path=/; HttpOnly'},
            );
          }
          expect(request.headers['X-CSRF-TOKEN'], 'anonymous-test');
          expect(request.headers['Cookie'], 'JSESSIONID=anonymous');
          expect(request.url.path, '/schdulmanage/KNU/80/yearSchdul.do');
          final year = int.parse(request.bodyFields['year']!);
          years.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(years, [2025, 2026]);
      expect(events, hasLength(36));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(36));
      expect(
        events.singleWhere((e) => e.title == '2학기 개강').start,
        DateTime(2026, 9, 1),
      );
      expect(
        events.singleWhere((e) => e.title == '2학기 성적열람(이의신청) 기간').end,
        DateTime(2026, 12, 31),
      );
    },
  );

  test('Kongju rejects wrong year and missing monthly coverage', () {
    final body = fixture(2026);
    expect(() => KongjuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => KongjuAcademicSource.parse(body.replaceFirst('12월', '11월'), 2026),
      throwsFormatException,
    );
  });

  test('Kongju rejects invalid dates and unknown source programme', () {
    final body = fixture(2026);
    expect(
      () =>
          KongjuAcademicSource.parse(body.replaceFirst('01-02', '01-32'), 2026),
      throwsFormatException,
    );
    expect(
      () => KongjuAcademicSource.parse(
        body.replaceFirst("'KNU', '80'", "'KNU', '81'"),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('every published Kongju row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('#timeTableList .desc > dl')
          .length;
      expect(rows, year == 2025 ? 35 : 36);
      expect(KongjuAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });

  test('Kongju profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000008',
      'academyinfo:0000008',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립공주대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'kongju',
      );
    }
  });
}
