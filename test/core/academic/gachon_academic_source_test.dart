import 'dart:io';
import 'package:daily/core/academic/gachon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/gachon-$year.html').readAsStringSync();
void main() {
  test(
    'Gachon main university calendar retains twelve months and cross-year leave',
    () async {
      final requested = <String>[];
      final source = GachonAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/schdulmanage/kor/25/yearSchdul.do');
          final year = Uri.splitQueryString(r.body)['year']!;
          requested.add(year);
          return http.Response(
            fixture(int.parse(year)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['2025', '2026']);
      expect(events, hasLength(55));
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절학기' &&
              e.start == DateTime(2026, 1, 5) &&
              e.end == DateTime(2026, 1, 17),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '미등록 휴학기간' &&
              e.start == DateTime(2025, 12, 22) &&
              e.end == DateTime(2026, 2, 28),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '미등록 휴학기간' &&
              e.start == DateTime(2026, 12, 22) &&
              e.end == DateTime(2027, 2, 27),
        ),
        isTrue,
      );
    },
  );
  test('Gachon rejects incorrect year and malformed published date', () {
    expect(
      () => GachonAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => GachonAcademicSource.parse(
        fixture(2026).replaceFirst('01.05', '01.32'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => GachonAcademicSource.parse(
        fixture(2026).replaceFirst('class="month-count"', 'class="missing"'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
