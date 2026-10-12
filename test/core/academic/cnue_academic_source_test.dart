import 'dart:io';
import 'package:daily/core/academic/cnue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/cnue-$year.html').readAsStringSync();
void main() {
  test(
    'CNUE fetches whole official year and handles cross-month ranges',
    () async {
      final source = CnueAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters['allYn'], 'Y');
          return http.Response(
            fixture(int.parse(request.url.queryParameters['cYear']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(49));
      expect(
        events.any(
          (e) =>
              e.start == DateTime(2026, 5, 11) && e.end == DateTime(2026, 6, 6),
        ),
        isTrue,
      );
    },
  );
  test('CNUE rejects wrong year and impossible calendar dates', () {
    expect(
      () => CnueAcademicSource.parse(fixture(2026), 2027),
      throwsFormatException,
    );
    expect(
      () => CnueAcademicSource.parse(
        fixture(2026).replaceFirst('16(월)', '30(월)'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
