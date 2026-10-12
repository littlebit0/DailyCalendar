import 'dart:io';
import 'package:daily/core/academic/mmu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/mmu-$year.json').readAsStringSync();
void main() {
  test(
    'MMU annual undergraduate calendar retains both winter periods',
    () async {
      final source = MmuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/main/scheduleList');
          expect(request.url.queryParameters['libType'], 'D');
          expect(request.url.queryParameters['hakgi'], '0');
          return http.Response(
            fixture(int.parse(request.url.queryParameters['year']!)),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
    expect(events, hasLength(59));
      expect(
        events.any(
          (e) =>
              e.title == '2025학년도 겨울 계절학기' &&
              e.start == DateTime(2025, 12, 24) &&
              e.end == DateTime(2026, 1, 16),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2026학년도 겨울 계절학기' &&
              e.start == DateTime(2026, 12, 21) &&
              e.end == DateTime(2027, 1, 13),
        ),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('MMU rejects wrong academic year and impossible dates', () {
    expect(
      () => MmuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => MmuAcademicSource.parse(
        fixture(2026).replaceFirst('2026-03-01', '2026-02-30'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
