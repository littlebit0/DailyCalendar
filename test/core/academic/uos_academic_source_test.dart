import 'dart:io';
import 'package:daily/core/academic/uos_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/uos-2026.html').readAsStringSync();
void main() {
  test('UOS uses official anonymous URL and absolute winter dates', () async {
    final source = UosAcademicSource(
      client: MockClient((request) async {
        expect(request.url.queryParameters['identified'], 'anonymous');
        expect(request.url.queryParameters['year_code'], '2026');
        return http.Response(
          fixture(),
          200,
          headers: {'content-type': 'text/html;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(events, hasLength(57));
    final winter = events.firstWhere((e) => e.title.startsWith('겨울 계절수업'));
    expect(winter.start, DateTime(2025, 12, 22));
    expect(winter.end, DateTime(2026, 1, 20));
  });
  test(
    'UOS rejects wrong year, missing details and invalid absolute dates',
    () {
      expect(
        () => UosAcademicSource.parse(fixture(), 2027),
        throwsFormatException,
      );
      expect(
        () => UosAcademicSource.parse(
          fixture().replaceFirst('2025-12-22', '2025-12-32'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => UosAcademicSource.parse(
          fixture().replaceFirst('m202601cc0', 'missing'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
}
