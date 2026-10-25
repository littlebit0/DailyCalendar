import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/hanbat_academic_source.dart';
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

  test('every published Hanbat row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final months = jsonDecode(fixture('hanbat-$year.json')) as List;
      final rows = months.fold<int>(
        0,
        (count, month) => count + (month['list'] as List).length,
      );
      expect(
        HanbatAcademicSource.parse(fixture('hanbat-$year.json'), year),
        hasLength(rows),
      );
    }
  });

  test('Hanbat profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000039',
      'academyinfo:0000039',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립한밭대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'hanbat',
      );
    }
  });

  test(
    'Hanbat refuses incomplete year and foreign programme rather than partial import',
    () {
      final data = jsonDecode(fixture('hanbat-2026.json')) as List;
      expect(
        () => HanbatAcademicSource.parse(jsonEncode(data.sublist(1)), 2026),
        throwsFormatException,
      );
      expect(
        () => HanbatAcademicSource.parse(fixture('hanbat-2026.json'), 2025),
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
    final invalid = jsonDecode(fixture('hanbat-2026.json')) as List;
    invalid.first['list'].first['bgnde'] = '2026-03-32 00:00:00.0';
    expect(
      () => HanbatAcademicSource.parse(jsonEncode(invalid), 2026),
      throwsFormatException,
    );
    final duplicates = jsonDecode(fixture('hanbat-2026.json')) as List;
    duplicates.first['list'][1]['cntNo'] = duplicates.first['list'][0]['cntNo'];
    expect(
      () => HanbatAcademicSource.parse(jsonEncode(duplicates), 2026),
      throwsFormatException,
    );
  });

  test('Hanbat failed response keeps existing events by throwing', () async {
    final source = HanbatAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
