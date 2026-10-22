import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/sku_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/sku-$year.json').readAsStringSync();
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
            fixture(2026),
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
  test('every published SKU event is imported for each year', () {
    for (final year in [2025, 2026]) {
      final items = (jsonDecode(fixture(year))['items'] as List)
          .where((e) => e['status'] != 'cancelled')
          .toList();
      final events = SkuAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(items.length));
      expect(
        events.map((e) => e.sourceId).toSet(),
        items.map((e) => e['id']).toSet(),
      );
    }
  });
  test('SKU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000121',
      'academyinfo:0000121',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '서경대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'sku',
      );
    }
  });
  test(
    'SKU rejects partial responses, invalid dates and wrong academic scope',
    () {
      final data = jsonDecode(fixture(2026)) as Map<String, dynamic>;
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
        () => SkuAcademicSource.parse(jsonEncode({...data, 'items': []}), 2026),
        throwsFormatException,
      );
      expect(
        () => SkuAcademicSource.parse(
          fixture(2026).replaceFirst('2026-01-12', '2026-01-32'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SkuAcademicSource.parse(fixture(2026), 2025),
        throwsFormatException,
      );
    },
  );
  test('SKU reports an unavailable calendar as an error', () async {
    final source = SkuAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
