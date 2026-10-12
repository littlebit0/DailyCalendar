import 'dart:io';
import 'package:daily/core/academic/dgist_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/dgist-$year.html').readAsStringSync();
void main() {
  test(
    'DGIST uses verified GET annual feed and retains cross-year application',
    () async {
      final years = <int>[];
      final source = DgistAcademicSource(
        client: MockClient((r) async {
          expect(r.method, 'GET');
          expect(r.url.host, 'www.dgist.ac.kr');
          final year = int.parse(r.url.queryParameters['searchYear']!);
          years.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(years, [2025, 2026]);
      expect(events, hasLength(54));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(54));
      final crossing = events.singleWhere(
        (e) => e.start == DateTime(2025, 12, 29),
      );
      expect(crossing.end, DateTime(2026, 1, 3));
      expect(events.any((e) => e.title.contains('개강')), isTrue);
    },
  );
  test('DGIST rejects wrong year, duplicate month and malformed dates', () {
    expect(
      () => DgistAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => DgistAcademicSource.parse(
        fixture(
          2026,
        ).replaceFirst('<strong>01월</strong>', '<strong>02월</strong>'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => DgistAcademicSource.parse(
        fixture(2026).replaceFirst('01. 02', '01. 32'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
