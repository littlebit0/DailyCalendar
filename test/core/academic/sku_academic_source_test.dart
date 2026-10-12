import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/sku_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/sku-2026.json').readAsStringSync();
void main() {
  test(
    'SKU official proxy retains exclusive ends and both winter intervals',
    () async {
      final source = SkuAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/academy-calendar');
          expect(r.url.queryParameters['timeMin'], '2025-12-31T15:00:00.000Z');
          expect(r.url.queryParameters['timeMax'], '2026-12-31T14:59:59.999Z');
          expect(
            r.headers['Referer'],
            'https://www.skuniv.ac.kr/academic-calendar',
          );
          return http.Response(
            fixture(),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(59));
      for (final d in [
        (DateTime(2025, 12, 26), DateTime(2026, 1, 17)),
        (DateTime(2026, 12, 17), DateTime(2027, 1, 9)),
      ]) {
        expect(
          events.any(
            (e) =>
                e.title.contains('동계계절학기') && e.start == d.$1 && e.end == d.$2,
          ),
          isTrue,
        );
      }
      final finalGrade = events.singleWhere(
        (e) => e.title == '1학기 성적열람 및 정정(기말강의평가)',
      );
      expect(finalGrade.start, DateTime(2026, 6, 26));
      expect(finalGrade.end, DateTime(2026, 7, 3));
    },
  );
  test(
    'SKU rejects partial responses, invalid dates and wrong academic scope',
    () {
      final data = jsonDecode(fixture()) as Map<String, dynamic>;
      expect(
        () => SkuAcademicSource.parse(
          jsonEncode({...data, 'nextPageToken': 'more'}),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SkuAcademicSource.parse(
          jsonEncode({...data, 'summary': '대학원'}),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SkuAcademicSource.parse(
          fixture().replaceFirst('2026-01-12', '2026-01-32'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SkuAcademicSource.parse(fixture(), 2025),
        throwsFormatException,
      );
    },
  );
}
