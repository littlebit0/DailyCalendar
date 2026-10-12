import 'dart:io';
import 'package:daily/core/academic/inu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/inu-$year.html').readAsStringSync();

void main() {
  test(
    'INU preserves preceding winter and current summer cross-month periods',
    () async {
      final years = <int>[];
      final source = InuAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/schdulmanage/inu/10/yearSchdul.do');
          expect(request.bodyFields['kind'], '');
          final year = int.parse(request.bodyFields['year']!);
          years.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(years, [2025, 2026]);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(
        events.singleWhere((e) => e.title == '하계 계절학기').end,
        DateTime(2026, 7, 14),
      );
      expect(events.where((e) => e.title == '동계 계절학기'), hasLength(2));
      expect(
        events.singleWhere((e) => e.title == '제2학기 개강').start,
        DateTime(2026, 9, 1),
      );
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );

  test('INU rejects wrong year, incomplete coverage and invalid dates', () {
    final body = fixture(2026);
    expect(() => InuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => InuAcademicSource.parse(body.replaceFirst('12월', '11월'), 2026),
      throwsFormatException,
    );
    expect(
      () => InuAcademicSource.parse(body.replaceFirst('01.01', '01.32'), 2026),
      throwsFormatException,
    );
    expect(
      () => InuAcademicSource.parse(body.replaceFirst('01-12', '01-07'), 2026),
      throwsFormatException,
    );
  });
}
