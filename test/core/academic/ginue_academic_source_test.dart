import 'dart:io';
import 'package:daily/core/academic/ginue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/ginue-$year.html').readAsStringSync();
void main() {
  test(
    'GINUE reads official list rather than empty admission calendar',
    () async {
      final source = GinueAcademicSource(
        client: MockClient((request) async {
          expect(request.url.host, 'www.ginue.ac.kr');
          expect(request.url.path, '/kor/CMS/ScheduleMgr/YearList.do');
          return http.Response(
            fixture(int.parse(request.url.queryParameters['calendar_year']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(44));
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('GINUE rejects wrong year and invalid dates', () {
    expect(
      () => GinueAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => GinueAcademicSource.parse(
        fixture(2026).replaceFirst('02. 09', '02. 30'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
