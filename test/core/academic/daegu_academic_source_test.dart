import 'dart:io';

import 'package:daily/core/academic/daegu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(int year) =>
      File('test/fixtures/academic/daegu-$year.html').readAsStringSync();
  test(
    'Daegu annual fetch includes previous academic year January and splits published events',
    () async {
      final years = <int>[];
      final source = DaeguAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters['schedule_info_seq'], '1');
          final year = int.parse(
            request.url.queryParameters['schedule_start_date']!,
          );
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
      expect(events.length, 71);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.any((e) => e.start.month == 1), isTrue);
      expect(events.every((e) => !e.title.contains('▪')), isTrue);
      final finals = events.singleWhere((e) => e.title == '제1학기 기말시험기간');
      expect(finals.start, DateTime(2026, 6, 9));
      expect(finals.end, DateTime(2026, 6, 16));
    },
  );
  test('Daegu refuses wrong year, malformed dates and graduate calendar', () {
    final body = fixture(2026);
    expect(() => DaeguAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => DaeguAcademicSource.parse(
        body.replaceFirst('03-01 (일)', '03-32 (일)'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => DaeguAcademicSource.parse(
        body.replaceFirst('2026년도 대학 일정', '2026년도 일반대학원 일정'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
