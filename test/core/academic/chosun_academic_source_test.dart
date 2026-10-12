import 'dart:io';
import 'package:daily/core/academic/chosun_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/chosun-$year.html').readAsStringSync();
void main() {
  test(
    'Chosun annual rows preserve full periods with only two public requests',
    () async {
      final years = <int>[];
      final source = ChosunAcademicSource(
        client: MockClient((r) async {
          expect(r.url.host, 'csu.chosun.ac.kr');
          expect(r.url.path, '/schdulmanage/chosun/1/yearSchdul.do');
          final year = int.parse(Uri.splitQueryString(r.body)['year']!);
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
      expect(events, hasLength(59));
      final winter = events.singleWhere((e) => e.title == '동계 계절학기');
      expect(winter.start, DateTime(2026, 1, 2));
      expect(winter.end, DateTime(2026, 1, 23));
      final marks = events.singleWhere(
        (e) => e.title == '성적 열람' && e.start.year == 2025,
      );
      expect(marks.start, DateTime(2025, 12, 30));
      expect(marks.end, DateTime(2026, 1, 6));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(59));
    },
  );
  test('Chosun rejects stale response, missing month and invalid date', () {
    expect(
      () => ChosunAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => ChosunAcademicSource.parse(
        fixture(2026).replaceFirst('<h3> 1월</h3>', '<h3> 2월</h3>'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => ChosunAcademicSource.parse(
        fixture(2026).replaceFirst('01-01', '01-32'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
