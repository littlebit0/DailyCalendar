import 'dart:io';
import 'package:daily/core/academic/mju_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/mju-$year.html').readAsStringSync();
void main() {
  test(
    'MJU preserves winter carry-over and shared undergraduate events',
    () async {
      final requests = <int>[];
      final source = MjuAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/schdulmanage/mjukr/4/yearSchdul.do');
          final year = int.parse(Uri.splitQueryString(request.body)['year']!);
          requests.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requests, [2025, 2026]);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
      expect(
        events
            .where((e) => e.title.contains('동계 계절수업기간') && e.start.year == 2026)
            .single
            .end,
        DateTime(2027, 1, 14),
      );
      expect(
        events.any((e) => e.start.year == 2025 && e.end.year == 2026),
        isTrue,
      );
      expect(events.any((e) => e.title.contains('과정변경')), isFalse);
      expect(events.any((e) => e.title.contains('전과 및 재입학')), isTrue);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('MJU rejects year, dates and incomplete annual list', () {
    expect(
      () => MjuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => MjuAcademicSource.parse(
        fixture(2026).replaceFirst('.01 .01', '.02 .30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => MjuAcademicSource.parse(
        fixture(2026).replaceFirst('01월', 'bad'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
