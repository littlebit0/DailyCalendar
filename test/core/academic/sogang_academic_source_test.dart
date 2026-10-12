import 'dart:io';
import 'package:daily/core/academic/sogang_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/sogang-$year.json').readAsStringSync();
void main() {
  test(
    'Sogang coalesces daily records and preserves year boundaries',
    () async {
      final source = SogangAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/api/api/v1/mainKo/scheduleList');
          final year = int.parse(
            request.url.queryParameters['startDate']!.substring(0, 4),
          );
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      final exams = events.where((e) => e.title == '중간시험').toList();
      expect(exams.map((e) => (e.start, e.end)), [
        (DateTime(2026, 4, 21), DateTime(2026, 4, 28)),
        (DateTime(2026, 10, 20), DateTime(2026, 10, 27)),
      ]);
      final grades = events.where((e) => e.title == '학기말성적 확인').toList();
      expect(
        grades.any((e) => e.start.year == 2025 && e.end.year == 2026),
        isTrue,
      );
      expect(
        grades.any((e) => e.start.year == 2026 && e.end.year == 2027),
        isTrue,
      );
      expect(
        events
            .where((e) => e.title == '계절수업 종강' && e.start.month == 1)
            .single
            .start,
        DateTime(2026, 1, 14),
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('Sogang rejects wrong year, rollover date and failed response', () {
    expect(
      () => SogangAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => SogangAcademicSource.parse(
        fixture(2026).replaceFirst('2026.04.03', '2026.02.30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SogangAcademicSource.parse('{"statusCode":500,"data":[]}', 2026),
      throwsFormatException,
    );
  });
}
