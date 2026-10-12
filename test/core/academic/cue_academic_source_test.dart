import 'dart:io';
import 'package:daily/core/academic/cue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/cue-$year.html').readAsStringSync();
void main() {
  test(
    'CUE validates twelve official months and preserves full practicum periods',
    () async {
      final requested = <String>[];
      final source = CueAcademicSource(
        client: MockClient((r) async {
          expect(r.url.queryParameters['mCode'], 'MN052');
          final year = r.url.queryParameters['calendar_year']!;
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
              e.title == '4학년 실무실습' &&
              e.start == DateTime(2026, 4, 20) &&
              e.end == DateTime(2026, 5, 2),
        ),
        isTrue,
      );
      expect(
        events.every((e) => e.url.startsWith('https://www.cue.ac.kr/')),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    },
  );
  test('CUE rejects wrong year and missing official month', () {
    expect(
      () => CueAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => CueAcademicSource.parse(
        fixture(2026).replaceFirst('class="sch-monlist-wr"', 'class="missing"'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
