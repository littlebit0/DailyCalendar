import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/sunchon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/sunchon.json').readAsStringSync();
void main() {
  test(
    'Sunchon keeps cross-year rows and one copy of a listed holiday',
    () async {
      final requests = <String>[];
      final source = SunchonAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/haksa/sv/schdulView/selectSvList.do');
          requests.add(r.body);
          return http.Response(
            fixture(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requests, ['sysId=SCNU']);
      expect(events, hasLength(70));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(70));
      final newYear = events.where((e) => e.title == '신정').toList();
      expect(newYear.map((e) => e.sourceId), ['2425']);
      expect(
        events.any(
          (e) =>
              e.sourceId == '2424' &&
              e.title == '성적확인 및 정정' &&
              e.start == DateTime(2025, 12, 27) &&
              e.end == DateTime(2026, 1, 3),
        ),
        isTrue,
      );
      expect(events.any((e) => e.sourceId == '추석:2026/09/25'), isTrue);
    },
  );
  test('every published Sunchon row is imported for each year', () {
    final rows = (jsonDecode(fixture()) as List).cast<Map>();
    for (final year in [2025, 2026]) {
      final published = rows
          .where(
            (r) =>
                (r['bgnde'] as String).compareTo('$year/12/31') <= 0 &&
                (r['endde'] as String).compareTo('$year/01/01') >= 0,
          )
          .map(
            (r) =>
                '${(r['schdulTitle'] as String).trim()}:'
                '${r['bgnde']}:${r['endde']}',
          )
          .toSet();
      expect(published, hasLength(year == 2025 ? 55 : 70));
      expect(
        SunchonAcademicSource.parse(fixture(), year),
        hasLength(published.length),
      );
    }
  });
  test('Sunchon profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000020',
      'academyinfo:0000020',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립순천대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'sunchon',
      );
    }
  });
  test('Sunchon refuses malformed dates, foreign rows and invalid bodies', () {
    final rows = jsonDecode(fixture()) as List;
    final row = rows.firstWhere((r) => r['schdulSeq'] == 2424) as Map;
    row['bgnde'] = '2026/01/32';
    expect(
      () => SunchonAcademicSource.parse(jsonEncode(rows), 2026),
      throwsFormatException,
    );
    row['bgnde'] = '2025/12/27';
    row['sysId'] = 'another-school';
    expect(
      () => SunchonAcademicSource.parse(jsonEncode(rows), 2026),
      throwsFormatException,
    );
    expect(
      () => SunchonAcademicSource.parse('{"result":"error"}', 2026),
      throwsFormatException,
    );
  });
  test('a malformed row in another year does not take this year offline', () {
    final rows = jsonDecode(fixture()) as List;
    final old = rows.firstWhere((r) => r['bgnde'] == '2018/08/03') as Map;
    old['bgnde'] = '2018/02/30';
    old['endde'] = '2018/13/01';
    final body = jsonEncode(rows);
    expect(SunchonAcademicSource.parse(body, 2026), hasLength(70));
    expect(SunchonAcademicSource.parse(body, 2025), hasLength(55));
    expect(
      () => SunchonAcademicSource.parse(body, 2018),
      throwsFormatException,
    );
    final current = rows.firstWhere((r) => r['schdulSeq'] == 2424) as Map;
    current['endde'] = '2026/02/30';
    expect(() => SunchonAcademicSource.parse(body, 2026), returnsNormally);
    expect(
      () => SunchonAcademicSource.parse(jsonEncode(rows), 2026),
      throwsFormatException,
    );
  });
  test('Sunchon reports an unavailable or empty calendar', () async {
    for (final response in [
      http.Response('error', 500),
      http.Response('[]', 200),
    ]) {
      final source = SunchonAcademicSource(
        client: MockClient((_) async => response),
      );
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
    }
  });
}
