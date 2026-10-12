import 'dart:io';
import 'package:daily/core/academic/khu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/academic/$name.html').readAsStringSync();
void main() {
  test(
    'KHU discovers published year links and preserves both winter terms and July revision',
    () async {
      final requested = <String>[];
      final source = KhuAcademicSource(
        client: MockClient((request) async {
          final menu = request.url.queryParameters['menuNo']!;
          requested.add(menu);
          final name = switch (menu) {
            '21200042' => 'khu-2026',
            '11600128' => 'khu-cls-index',
            '11600124' => 'khu-cls-2025-index',
            '11600125' => 'khu-2025-2',
            _ => throw StateError('Unexpected official year link'),
          };
          return http.Response(
            fixture(name),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['21200042', '11600128', '11600124', '11600125']);
      expect(events, hasLength(84));
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절학기 수업' &&
              e.start == DateTime(2025, 12, 22) &&
              e.end == DateTime(2026, 1, 14),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2학기 성적 공시 및 정정' &&
              e.start == DateTime(2025, 12, 30) &&
              e.end == DateTime(2026, 1, 3),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2학기 수강희망과목담기' &&
              e.start == DateTime(2026, 7, 13) &&
              e.end == DateTime(2026, 7, 17),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절학기 수업' &&
              e.start == DateTime(2026, 12, 22) &&
              e.end == DateTime(2027, 1, 14),
        ),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    },
  );
  test('KHU rejects source year typo, invalid dates and incomplete months', () {
    final url = Uri.parse('https://haksa.khu.ac.kr/');
    expect(
      () => KhuAcademicSource.parseSecondSemester(
        fixture('khu-2025-2').replaceFirst('2026. 1. 2.', '2025. 1. 2.'),
        2025,
        url,
      ),
      throwsFormatException,
    );
    expect(
      () => KhuAcademicSource.parseAnnual(
        fixture('khu-2026').replaceFirst('class="month"', 'class="missing"'),
        2026,
        url,
      ),
      throwsFormatException,
    );
    expect(
      () => KhuAcademicSource.parseAnnual(fixture('khu-2026'), 2025, url),
      throwsFormatException,
    );
  });
}
