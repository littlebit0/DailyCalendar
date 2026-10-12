import 'dart:io';

import 'package:daily/core/academic/ulsan_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(int year) =>
      File('test/fixtures/academic/ulsan-$year.html').readAsStringSync();
  test(
    'Ulsan retains previous December winter terms and excludes commented examples',
    () async {
      final years = <int>[];
      final source = UlsanAcademicSource(
        client: MockClient((request) async {
          final year = int.parse(request.url.queryParameters['calendar_year']!);
          years.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(years, [2025, 2026]);
      expect(events.length, 59);
      final winter = events.singleWhere((e) => e.title == '2026학년도 겨울계절수업');
      expect(winter.start, DateTime(2026, 12, 22));
      expect(winter.end, DateTime(2027, 1, 14));
      expect(events.any((e) => e.start == DateTime(2025, 12, 22)), isTrue);
      expect(events.any((e) => e.title.contains('반환 기준 5/6선')), isFalse);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('Ulsan refuses stale year, invalid day and missing month', () {
    final body = fixture(2026);
    expect(() => UlsanAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => UlsanAcademicSource.parse(
        body.replaceFirst('01. 05(월)', '01. 32(월)'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => UlsanAcademicSource.parse(
        body.replaceFirst('2026년 1월 학사일정', '2026년 2월 학사일정'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
