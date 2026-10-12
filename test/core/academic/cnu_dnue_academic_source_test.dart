import 'dart:io';
import 'package:daily/core/academic/cnu_academic_source.dart';
import 'package:daily/core/academic/dnue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String school, int year) =>
    File('test/fixtures/academic/$school-$year.html').readAsStringSync();
void main() {
  test(
    'CNU preceding December and year crossing winter remain complete',
    () async {
      final source = CnuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.host, 'plus.cnu.ac.kr');
          return http.Response(
            fixture('cnu', int.parse(request.url.queryParameters['year']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(69));
      expect(
        events.any(
          (e) =>
              e.title == '동기 계절학기' &&
              e.start == DateTime(2025, 12, 22) &&
              e.end == DateTime(2026, 1, 14),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '동기 계절학기' &&
              e.start == DateTime(2026, 12, 21) &&
              e.end == DateTime(2027, 1, 13),
        ),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('CNU rejects missing month and impossible date', () {
    expect(
      () => CnuAcademicSource.parse(
        fixture(
          'cnu',
          2026,
        ).replaceFirst('class="calen_box"', 'class="missing"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => CnuAcademicSource.parse(
        fixture('cnu', 2026).replaceFirst('01.01(목)', '02.30(목)'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test(
    'DNUE reads all official months and preserves inclusive ranges',
    () async {
      final source = DnueAcademicSource(
        client: MockClient((request) async {
          expect(request.url.host, 'www.dnue.ac.kr');
          expect(request.url.queryParameters['mCode'], 'MN119');
          return http.Response(
            fixture(
              'dnue',
              int.parse(request.url.queryParameters['calendar_year']!),
            ),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(51));
      expect(
        events.any(
          (e) =>
              e.title == '성적열람 및 정정기간' &&
              e.start == DateTime(2026, 1, 5) &&
              e.end == DateTime(2026, 1, 10),
        ),
        isTrue,
      );
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('DNUE rejects wrong year and impossible dates', () {
    expect(
      () => DnueAcademicSource.parse(fixture('dnue', 2026), 2025),
      throwsFormatException,
    );
    expect(
      () => DnueAcademicSource.parse(
        fixture('dnue', 2026).replaceFirst('01. 01(목)', '02. 30(목)'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
