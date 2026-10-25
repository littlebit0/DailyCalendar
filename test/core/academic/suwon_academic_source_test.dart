import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/suwon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/suwon-$year.json').readAsStringSync();
void main() {
  test('Suwon keeps preceding winter and full official year', () async {
    final source = SuwonAcademicSource(
      client: MockClient((request) async {
        expect(request.url.path, '/mainHp/FrontSchdulManageMonthAjax.html');
        expect(Uri.splitQueryString(request.body)['year'], '2026');
        return http.Response(
          fixture(2026),
          200,
          headers: {'content-type': 'application/json;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(events, hasLength(25));
    expect(events.first.title, '동계 계절학기(예정)');
    expect(events.first.start, DateTime(2025, 12, 22));
    expect(events.first.end, DateTime(2026, 1, 10));
    expect(events.last.start, DateTime(2026, 12, 28));
    expect(events.last.end, DateTime(2027, 1, 16));
    expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
  });
  test('every published Suwon row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = (jsonDecode(fixture(year))['resultList'] as List).length;
      expect(SuwonAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });
  test('Suwon keeps the previous start-and-title event IDs', () {
    final event = SuwonAcademicSource.parse(
      fixture(2026),
      2026,
    ).singleWhere((e) => e.start == DateTime(2026, 3, 3));
    expect(
      event.sourceId,
      '2026-03-03T00:00:00.000:2026학년도 입학식(Freshman Admission Ceremony)',
    );
  });
  test('Suwon profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000140',
      'academyinfo:0000140',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '수원대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'suwon',
      );
    }
  });
  test(
    'Suwon rejects stale year, invalid dates and empty or failed feeds',
    () async {
      expect(
        () => SuwonAcademicSource.parse(fixture(2026), 2025),
        throwsFormatException,
      );
      expect(
        () => SuwonAcademicSource.parse(
          fixture(2026).replaceFirst('202602020000', '202602300000'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SuwonAcademicSource.parse('{"resultList":[]}', 2026),
        throwsFormatException,
      );
      final source = SuwonAcademicSource(
        client: MockClient((_) async => http.Response('', 500)),
      );
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
    },
  );
}
