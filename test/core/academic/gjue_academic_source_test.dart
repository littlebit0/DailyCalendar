import 'dart:io';
import 'package:daily/core/academic/gjue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/gjue-$year.html').readAsStringSync();
void main() {
  test(
    'GJUE reads all twelve official months and deduplicates overlapping terms',
    () async {
      final source = GjueAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/kor/13/schedules/list');
          return http.Response(
            fixture(int.parse(request.url.queryParameters['year']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, isNotEmpty);
      expect(
        events.where(
          (e) =>
              e.start == DateTime(2026, 10, 19) &&
              e.end == DateTime(2026, 11, 14),
        ),
        hasLength(1),
      );
      expect(
        events.any(
          (e) =>
              e.start == DateTime(2026, 12, 26) &&
              e.end == DateTime(2027, 1, 5),
        ),
        isTrue,
      );
    },
  );
  test('GJUE rejects missing months, wrong year and invalid dates', () {
    expect(
      () => GjueAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => GjueAcademicSource.parse(
        fixture(2026).replaceFirst('month_1', 'missing'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => GjueAcademicSource.parse(
        fixture(2026).replaceFirst('02.02.', '02.30.'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
