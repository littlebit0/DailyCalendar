import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/ut_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/ut-$year-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();

UtAcademicSource fixtureSource(List<String> requested) => UtAcademicSource(
  client: MockClient((request) async {
    expect(request.url.path, '/prog/schedule/kor/1/schedule.do');
    final date = Uri.splitQueryString(request.body)['rdate']!;
    requested.add(date);
    return http.Response(
      fixture(int.parse(date.substring(0, 4)), int.parse(date.substring(5))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

void main() {
  test('UT fetches every month sequentially and keeps published IDs', () async {
    final requested = <String>[];
    final source = fixtureSource(requested);
    addTearDown(source.close);
    final events = await source.fetch(2026);
    expect(requested, [
      for (var m = 1; m <= 12; m++) '2026-${m.toString().padLeft(2, '0')}',
    ]);
    expect(events, hasLength(44));
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
    final midterm = events.singleWhere((e) => e.sourceId == '3995');
    expect(midterm.title, '중간고사 권장기간');
    expect(midterm.start, DateTime(2026, 10, 20));
    expect(midterm.end, DateTime(2026, 10, 27));
  });
  test('every published UT row is imported for each year', () async {
    for (final year in [2025, 2026]) {
      final ids = <int>{};
      for (var month = 1; month <= 12; month++) {
        for (final row in jsonDecode(fixture(year, month)) as List) {
          ids.add((row as Map)['cntNo'] as int);
        }
      }
      final source = fixtureSource([]);
      final events = await source.fetch(year);
      source.close();
      expect(events, hasLength(ids.length));
      expect(events.map((e) => int.parse(e.sourceId)).toSet(), ids);
    }
  });
  test('UT profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000034',
      'academyinfo:0000034',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립한국교통대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'ut',
      );
    }
  });
  test('UT rejects wrong month, malformed date and failed response', () async {
    expect(
      () => UtAcademicSource.parse(fixture(2026, 3), 2025, 3),
      throwsFormatException,
    );
    expect(
      () => UtAcademicSource.parse(
        fixture(2026, 3).replaceFirst('2026-03-28', '2026-03-32'),
        2026,
        3,
      ),
      throwsFormatException,
    );
    expect(
      () => UtAcademicSource.parse('{"error":true}', 2026, 3),
      throwsFormatException,
    );
    final failing = UtAcademicSource(
      client: MockClient((_) async => http.Response('', 500)),
    );
    addTearDown(failing.close);
    await expectLater(failing.fetch(2026), throwsFormatException);
  });
}
