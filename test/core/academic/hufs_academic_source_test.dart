import 'dart:io';
import 'package:daily/core/academic/hufs_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/hufs-$year.html').readAsStringSync();
void main() {
  test(
    'HUFS academic year retains next January and current year winter end',
    () async {
      final source = HufsAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/schdulmanage/hufs/40/yearSchdul.do');
          final year = int.parse(Uri.splitQueryString(request.body)['year']!);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(64));
      expect(
        events.any(
          (e) => e.start == DateTime(2026, 1, 13) && e.title == '계절학기 종강',
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.start == DateTime(2026, 12, 28) &&
              e.end == DateTime(2027, 1, 5),
        ),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('HUFS rejects missing month and wrong year', () {
    expect(
      () => HufsAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => HufsAcademicSource.parse(
        fixture(2026).replaceFirst('class="box-month"', 'class="missing"'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
