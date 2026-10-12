import 'dart:io';
import 'package:daily/core/academic/kyonggi_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/kyonggi-2026.html').readAsStringSync();
void main() {
  test(
    'Kyonggi university-wide source retains both full winter ranges',
    () async {
      final source = KyonggiAcademicSource(
        client: MockClient((r) async {
          expect(r.url.queryParameters, {
            'key': '5819',
            'sc1': '10',
            'sc3': '2026',
          });
          return http.Response(
            fixture(),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(88));
      for (final dates in [
        (DateTime(2025, 12, 18), DateTime(2026, 1, 10)),
        (DateTime(2026, 12, 21), DateTime(2027, 1, 13)),
      ]) {
        expect(
          events.any(
            (e) =>
                e.title == '[학사]동계 계절수업' &&
                e.start == dates.$1 &&
                e.end == dates.$2,
          ),
          isTrue,
        );
      }
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    },
  );
  test('Kyonggi rejects truncated annual data and invalid dates', () {
    expect(
      () => KyonggiAcademicSource.parse(fixture(), 2025),
      throwsFormatException,
    );
    expect(
      () => KyonggiAcademicSource.parse(
        fixture().replaceFirst('id="sc_con_202601"', 'id="missing"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KyonggiAcademicSource.parse(
        fixture().replaceFirst('2026.01.01(목)', '2026.01.32(목)'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
