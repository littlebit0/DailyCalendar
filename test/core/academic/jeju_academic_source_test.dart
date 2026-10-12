import 'dart:io';

import 'package:daily/core/academic/jeju_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Jeju retains true summer and winter bounds and excludes graduate-only rows',
    () async {
      final source = JejuAcademicSource(
        client: MockClient((request) async {
          final year = request.url.queryParameters['year'];
          return http.Response(
            File('test/fixtures/academic/jeju-$year.html').readAsStringSync(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(events.length, 48);
      expect(events.any((e) => e.title.startsWith('(대학원)')), isFalse);
      final summer = events.singleWhere((e) => e.title == '하기계절수업 개강');
      expect(summer.start, DateTime(2026, 6, 29));
      expect(summer.end, DateTime(2026, 7, 21));
      final winter = events.singleWhere(
        (e) => e.title == '동기계절수업 개강' && e.start.year == 2026,
      );
      expect(winter.start, DateTime(2026, 12, 28));
      expect(winter.end, DateTime(2027, 1, 19));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );

  test('Jeju rejects stale year and invalid official date', () {
    final body = File(
      'test/fixtures/academic/jeju-2026.html',
    ).readAsStringSync();
    expect(() => JejuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => JejuAcademicSource.parse(
        body.replaceFirst('01.02(금)', '01.32(금)'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
