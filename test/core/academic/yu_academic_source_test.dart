import 'dart:io';
import 'package:daily/core/academic/yu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/yu-$year.html').readAsStringSync();
void main() {
  test(
    'YU embeds official full periods and deduplicates repeated articles',
    () async {
      final source = YuAcademicSource(
        client: MockClient(
          (request) async => http.Response(
            fixture(int.parse(request.url.queryParameters['srYear']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          ),
        ),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(60));
      expect(
        events.any(
          (e) =>
              e.title == '방학' &&
              e.start == DateTime(2026, 12, 21) &&
              e.end == DateTime(2027, 3, 1),
        ),
        isTrue,
      );
      expect(
        events.where(
          (e) => e.title == '전부(과) 원서접수' && e.start == DateTime(2026, 1, 13),
        ),
        hasLength(1),
      );
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('YU rejects missing data, wrong year, and reversed dates', () {
    expect(
      () => YuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => YuAcademicSource.parse(
        '<script>var srYear = \'2026\'; var calData = [];</script>',
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => YuAcademicSource.parse(
        fixture(
          2026,
        ).replaceFirst('"endDt":"2026-01-07"', '"endDt":"2026-01-04"'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
