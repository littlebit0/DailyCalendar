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

void main() {
  test(
    'Kunsan fetches official previous/current years and keeps winter overlaps',
    () async {
      final years = <int>[];
      final source = KunsanAcademicSource(
        client: MockClient((request) async {
          expect(request.url.host, 'www.kunsan.ac.kr');
          expect(
            request.url.queryParameters['menuCd'],
            'DOM_000000103001001000',
          );
          final year = int.parse(request.url.queryParameters['sYear']!);
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
      expect(events, hasLength(75));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(75));
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
      expect(
        events.any(
          (e) =>
              e.title == '2학기 기말 교수강의평가' &&
              e.start == DateTime(2025, 12, 11) &&
              e.end == DateTime(2026, 1, 3),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2026학년도 1학기 개강' &&
              e.start == DateTime(2026, 3, 3) &&
              e.sourceId == '2026학년도 1학기 개강:2026-3-3',
        ),
        isTrue,
      );
    },
  );
  test('every published Kunsan row is imported for each year', () {
    for (final year in [2025, 2026]) {
      var body = fixture(year);
      if (year == 2025) {
        // Drop only the published source error; every other row must parse.
        body = body.replaceFirst(
          RegExp(
            r'<tr>\s*<td>' + RegExp.escape(sourceErrorRow) + r'.*?</tr>',
            dotAll: true,
          ),
          '',
        );
      }
      final rows = html
          .parse(body)
          .querySelectorAll('table.ctable02 > tbody > tr')
          .length;
      expect(rows, year == 2025 ? 70 : 74);
      expect(KunsanAcademicSource.parse(body, year), hasLength(rows));
    }
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
