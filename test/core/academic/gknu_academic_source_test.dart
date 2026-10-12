import 'dart:io';
import 'package:daily/core/academic/gknu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/gknu-$year-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();
void main() {
  test(
    'GKNU retrieves every month and preserves latest August calendar revision',
    () async {
      final requested = <String>[];
      final source = GknuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters['category1'], '101');
          final selected = request.url.queryParameters['notice_start_date']!;
          requested.add(selected);
          final p = selected.split('-').map(int.parse).toList();
          return http.Response(
            fixture(p[0], p[1]),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, hasLength(13));
      expect(requested.first, '2025-12');
      expect(requested.last, '2026-12');
      expect(events, hasLength(44));
      expect(
        events.any(
          (e) =>
              e.title == '2학기 기말시험' &&
              e.start == DateTime(2026, 12, 14) &&
              e.end == DateTime(2026, 12, 19),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '겨울방학' &&
              e.start == DateTime(2026, 12, 21) &&
              e.end == DateTime(2026, 12, 22),
        ),
        isTrue,
      );
      expect(GknuAcademicSource.parse(fixture(2026, 1), 2026, 1), isEmpty);
    },
  );
  test(
    'GKNU rejects invalid dates, wrong month and malformed JSON envelope',
    () {
      expect(
        () => GknuAcademicSource.parse(
          fixture(2026, 12).replaceFirst('2026-12-08', '2026-02-30'),
          2026,
          12,
        ),
        throwsFormatException,
      );
      expect(
        () => GknuAcademicSource.parse(fixture(2026, 12), 2026, 11),
        throwsFormatException,
      );
      expect(
        () => GknuAcademicSource.parse('{}', 2026, 12),
        throwsFormatException,
      );
    },
  );
}
