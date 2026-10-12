import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/hanbat_academic_source.dart';
import 'package:daily/core/academic/hknu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/academic/$name').readAsStringSync();

void main() {
  test(
    'Hanbat collects previous winter and current academic year sequentially',
    () async {
      final requestedYears = <int>[];
      final source = HanbatAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, endsWith('/A/getScheduleList.do'));
          expect(request.bodyFields['searchCondition2'], 'A');
          final year = int.parse(request.bodyFields['searchKeywordFrom']!);
          requestedYears.add(year);
          return http.Response(
            fixture('hanbat-$year.json'),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requestedYears, [2025, 2026]);
      expect(events, hasLength(75));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(75));
      final winters = events
          .where((e) => e.title == '겨울계절학기, 현장실습, 사회봉사 기간')
          .toList();
      expect(winters, hasLength(2));
      expect(winters.first.start, DateTime(2025, 12, 23));
      expect(winters.first.end, DateTime(2026, 1, 22));
      expect(winters.last.end, DateTime(2027, 1, 22));
    },
  );

  test(
    'Hanbat refuses incomplete year and foreign programme rather than partial import',
    () {
      final data = jsonDecode(fixture('hanbat-2026.json')) as List;
      expect(
        () => HanbatAcademicSource.parse(jsonEncode(data.sublist(1)), 2026),
        throwsFormatException,
      );
      data.first['list'].first['code'] = 'B';
      expect(
        () => HanbatAcademicSource.parse(jsonEncode(data), 2026),
        throwsFormatException,
      );
    },
  );

  test('Hanbat refuses malformed ranges and conflicting event identity', () {
    final data = jsonDecode(fixture('hanbat-2026.json')) as List;
    data.first['list'].first['endde'] = '2026-02-28 00:00:00.0';
    expect(
      () => HanbatAcademicSource.parse(jsonEncode(data), 2026),
      throwsFormatException,
    );
    final duplicates = jsonDecode(fixture('hanbat-2026.json')) as List;
    duplicates.first['list'][1]['cntNo'] = duplicates.first['list'][0]['cntNo'];
    expect(
      () => HanbatAcademicSource.parse(jsonEncode(duplicates), 2026),
      throwsFormatException,
    );
  });

  test(
    'HKNU validates selected year and carries winter dates across years',
    () async {
      final requestedYears = <int>[];
      final source = HknuAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.bodyFields['kind'], 'preYear');
          final year = int.parse(request.bodyFields['year']!) - 1;
          requestedYears.add(year);
          return http.Response(
            fixture('hknu-$year.html'),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requestedYears, [2025, 2026]);
      expect(events, hasLength(65));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(65));
      final winter = events.singleWhere(
        (e) => e.title == '동계 계절수업' && e.start.year == 2026,
      );
      expect(winter.start, DateTime(2026, 12, 22));
      expect(winter.end, DateTime(2027, 1, 14));
      expect(
        events.any((e) => e.start.year == 2025 && e.end.year == 2026),
        isTrue,
      );
    },
  );

  test('HKNU refuses stale selection, missing month and invalid date', () {
    final body = fixture('hknu-2026.html');
    expect(() => HknuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => HknuAcademicSource.parse(body.replaceFirst('12월', '11월'), 2026),
      throwsFormatException,
    );
    expect(
      () => HknuAcademicSource.parse(body.replaceFirst('01.05', '01.32'), 2026),
      throwsFormatException,
    );
  });
}
