import 'dart:io';

import 'package:daily/core/academic/deu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(int year) =>
      File('test/fixtures/academic/deu-$year.html').readAsStringSync();
  test(
    'DEU reads two semesters, abbreviated end days and next January',
    () async {
      final source = DeuAcademicSource(
        client: MockClient((request) async {
          final year = int.parse(request.url.queryParameters['schYear']!);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(events.length, 66);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final winter = events.singleWhere(
        (e) => e.start == DateTime(2026, 12, 28),
      );
      expect(winter.end, DateTime(2027, 1, 19));
      final correction = events.singleWhere(
        (e) => e.start == DateTime(2026, 3, 5),
      );
      expect(correction.end, DateTime(2026, 3, 10));
      expect(events.any((e) => e.start.month == 1), isTrue);
    },
  );
  test('DEU rejects incorrect year and malformed day', () {
    final body = fixture(2026);
    expect(() => DeuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => DeuAcademicSource.parse(body.replaceFirst('3월 1일', '3월 32일'), 2026),
      throwsFormatException,
    );
  });
}
