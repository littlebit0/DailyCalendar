import 'dart:io';

import 'package:daily/core/academic/kaist_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'KAIST year form reads all months and preserves winter crossover',
    () async {
      final years = <int>[];
      final source = KaistAcademicSource(
        client: MockClient((request) async {
          final form = Uri.splitQueryString(request.body);
          expect(form['month'], '');
          expect(form['groups'], 'university');
          final year = int.parse(form['year']!);
          years.add(year);
          return http.Response(
            File('test/fixtures/academic/kaist-$year.html').readAsStringSync(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(years, [2025, 2026]);
      expect(events.length, 145);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final winter = events.singleWhere(
        (e) => e.title == '겨울학기 수강신청 취소' && e.start.year == 2026,
      );
      expect(winter.start, DateTime(2026, 12, 24));
      expect(winter.end, DateTime(2027, 1, 5));
      expect(events.any((e) => e.start.year == 2025), isTrue);
    },
  );
  test('KAIST refuses stale year and malformed official date', () {
    final body = File(
      'test/fixtures/academic/kaist-2026.html',
    ).readAsStringSync();
    expect(() => KaistAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => KaistAcademicSource.parse(
        body.replaceFirst('01-01(목)', '01-32(목)'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
