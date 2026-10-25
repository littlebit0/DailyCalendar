import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/changwon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, String month) => File(
  'test/fixtures/academic/changwon-$year-$month.json',
).readAsStringSync();

Future<List<dynamic>> fetchWithFixtures(int year, List<String> months) async {
  final source = ChangwonAcademicSource(
    client: MockClient((request) async {
      expect(request.url.path, '/haksa/sv/schdulView/selectSvList.do');
      final fields = Uri.splitQueryString(request.body);
      expect(fields['sysId'], 'haksa');
      final [y, m, _] = fields['dateFirst']!.split('/');
      expect(int.parse(y), year);
      months.add(m);
      return http.Response(
        fixture(year, m),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  addTearDown(source.close);
  return source.fetch(year);
}

void main() {
  test(
    'Changwon imports every published academic record of the year, keyed by record number',
    () async {
      for (final (year, count) in [(2025, 47), (2026, 52)]) {
        final months = <String>[];
        final events = await fetchWithFixtures(year, months);
        expect(months, [for (var m = 1; m <= 12; m++) '$m'.padLeft(2, '0')]);
        final published = <int>{
          for (final m in months)
            for (final row in jsonDecode(fixture(year, m)) as List)
              if (row['schdulSeq'] == 'portal') row['scheno'] as int,
        };
        expect(published, hasLength(count));
        expect(events.map((e) => e.sourceId).toSet(), {
          for (final n in published) '$n',
        });
      }
    },
  );

  test(
    'Changwon keeps cross-year periods and skips the holiday overlay',
    () async {
      final events = await fetchWithFixtures(2026, []);
      final winter = events.singleWhere((e) => e.sourceId == '17860');
      expect(winter.title, '동계 계절학기');
      expect(winter.start, DateTime(2026, 12, 23));
      expect(winter.end, DateTime(2027, 1, 15));
      final leave = events.singleWhere((e) => e.sourceId == '17808');
      expect(leave.start, DateTime(2025, 12, 22));
      expect(leave.end, DateTime(2026, 3, 1));
      // The overlay's 2026-05-05 "대체휴일" is not on the academic calendar.
      expect(
        events.any((e) => e.title == '대체휴일' && e.start == DateTime(2026, 5, 5)),
        isFalse,
      );
      expect(events.where((e) => e.title == '부처님오신날 대체공휴일'), hasLength(1));
    },
  );

  test('Changwon rejects malformed dates and foreign calendars', () {
    for (final (key, value) in [
      ('bgnde', '2026/03/32'),
      ('endde', '2026/02/28'),
      ('calname', '대학원 학사일정'),
      ('scheno', null),
      ('schdulSeq', 'other'),
    ]) {
      final rows = jsonDecode(fixture(2026, '03')) as List;
      rows.firstWhere((r) => r['schdulSeq'] == 'portal')[key] = value;
      expect(
        () => ChangwonAcademicSource.parse(jsonEncode(rows), 2026),
        throwsFormatException,
      );
    }
    expect(
      () => ChangwonAcademicSource.parse('{"rows": []}', 2026),
      throwsFormatException,
    );
  });

  test('Changwon fails on an unavailable or empty calendar', () async {
    for (final response in [
      http.Response('error', 500),
      http.Response('[]', 200),
    ]) {
      final source = ChangwonAcademicSource(
        client: MockClient((_) async => response),
      );
      addTearDown(source.close);
      await expectLater(source.fetch(2026), throwsFormatException);
    }
  });

  test('Changwon campuses resolve to their own registered calendars', () {
    for (final (universityId, campusId, expected) in [
      ('institution:academyinfo:0000028', null, 'changwon'),
      ('institution:academyinfo:0000028', 'academyinfo:0000028', 'changwon'),
      ('academyinfo:0000028', null, 'changwon'),
      (
        'institution:academyinfo:0000028',
        'academyinfo:0003297',
        'changwon-geochang',
      ),
      ('academyinfo:0003297', null, 'changwon-geochang'),
      (
        'institution:academyinfo:0000028',
        'academyinfo:0003298',
        'changwon-namhae',
      ),
      ('academyinfo:0003298', null, 'changwon-namhae'),
      ('institution:academyinfo:0000028', 'academyinfo:0000100', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '국립창원대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        expected,
      );
    }
  });
}
