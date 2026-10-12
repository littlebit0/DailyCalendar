import 'dart:io';
import 'package:daily/core/academic/cbnu_academic_source.dart';
import 'package:daily/core/academic/koreatech_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String school, int year) =>
    File('test/fixtures/academic/$school-$year.html').readAsStringSync();
void main() {
  test(
    'CBNU whole year preserves winter and removes cross-month duplication',
    () async {
      final source = CbnuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters['month'], 'all');
          expect(request.url.queryParameters['currentY'], '2026');
          return http.Response(
            fixture('cbnu', 2026),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      final winter = events.where((e) => e.title == '동기계절수업').toList();
      expect(winter.map((e) => (e.start, e.end)), [
        (DateTime(2025, 12, 22), DateTime(2026, 1, 14)),
        (DateTime(2026, 12, 21), DateTime(2027, 1, 13)),
      ]);
      expect(events.where((e) => e.title == '하기계절수업'), hasLength(1));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('CBNU rejects wrong year and rolled invalid date', () {
    expect(
      () => CbnuAcademicSource.parse(fixture('cbnu', 2026), 2025),
      throwsFormatException,
    );
    expect(
      () => CbnuAcademicSource.parse(
        fixture('cbnu', 2026).replaceFirst('01.05.', '02.30.'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test(
    'Koreatech academic year combines preceding winter and full periods',
    () async {
      final source = KoreatechAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/board.es');
          expect(request.url.queryParameters['bid'], '0006');
          final year = int.parse(
            request.url.queryParameters['sel_date']!.substring(0, 4),
          );
          return http.Response(
            fixture('koreatech', year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      final winter = events
          .where((e) => e.title.startsWith('동계 계절수업('))
          .toList();
      expect(winter.map((e) => (e.start, e.end)), [
        (DateTime(2025, 12, 22), DateTime(2026, 1, 14)),
        (DateTime(2026, 12, 21), DateTime(2027, 1, 13)),
      ]);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('Koreatech rejects missing months and wrong year', () {
    expect(
      () => KoreatechAcademicSource.parse(fixture('koreatech', 2026), 2025),
      throwsFormatException,
    );
    expect(
      () => KoreatechAcademicSource.parse(
        fixture('koreatech', 2026).replaceFirst('CalendarList', 'missing'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
