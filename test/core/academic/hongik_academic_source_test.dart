import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/hongik_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/hongik-$year.json').readAsStringSync();
List<Map<String, dynamic>> rows(int year) =>
    ((jsonDecode(fixture(year)) as Map)['data'] as List)
        .cast<Map<String, dynamic>>();

void main() {
  test('Hongik month-only notices span their whole months', () {
    final events = HongikAcademicSource.parse(fixture(2026), 2026);
    expect(events.length, greaterThan(40));
    expect(
      events.any(
        (e) => e.title == '2026학년도 2학기 종강' && e.start == DateTime(2026, 12, 14),
      ),
      isTrue,
    );
    final monthly = events.singleWhere(
      (e) => e.title == '2027학년도 신입생 수시모집 입학전형',
    );
    expect(monthly.start, DateTime(2026, 9));
    expect(monthly.end, DateTime(2027));
  });

  test('every Hongik row is imported for each year', () {
    for (final (year, unique) in [(2025, 76), (2026, 76)]) {
      expect(rows(year), hasLength(76));
      expect(
        HongikAcademicSource.parse(fixture(year), year),
        hasLength(unique),
      );
    }
  });

  test('Hongik keeps date and title IDs and inclusive end dates', () {
    final event = HongikAcademicSource.parse(
      fixture(2026),
      2026,
    ).singleWhere((e) => e.title == '2026학년도 하계 계절학기');
    expect(event.sourceId, '2026-06-24/2026-07-14/2026학년도 하계 계절학기');
    expect(event.start, DateTime(2026, 6, 24));
    expect(event.end, DateTime(2026, 7, 15));
    expect(
      event.url,
      'https://www.hongik.ac.kr/kr/education/academic-schedule.do',
    );
  });

  test('Hongik year carries ranges that began in the previous feed', () async {
    final requested = <String>[];
    final source = HongikAcademicSource(
      client: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/sso/APICipher.jsp');
        final query = jsonDecode(Uri.splitQueryString(r.body)['data']!) as Map;
        expect(query['url'], '/schedule/get_schedule.php');
        expect(query['url3'], '0');
        requested.add(query['url5'] as String);
        return http.Response.bytes(
          utf8.encode(fixture(int.parse(query['url5'] as String))),
          200,
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(requested, ['2025', '2026']);
    expect(events, hasLength(69));
    final winter = events.singleWhere((e) => e.title == '2025학년도 동계 계절학기');
    expect(winter.start, DateTime(2025, 12, 23));
    expect(winter.end, DateTime(2026, 1, 16));
    // Same ID as when the 2025 calendar imported it.
    expect(
      HongikAcademicSource.parse(
        fixture(2025),
        2025,
      ).singleWhere((e) => e.title == winter.title).sourceId,
      winter.sourceId,
    );
    // Previous-feed rows that start in 2026 are left to the 2026 feed.
    expect(events.any((e) => e.title.endsWith('복학신청(예정)')), isFalse);
    expect(events.any((e) => e.start.year == 2027), isFalse);
    expect(events.any((e) => e.title == '2026학년도 동계 계절학기(예정)'), isTrue);
  });

  test('Hongik profile resolves to its registered calendar', () {
    for (final (university, campus) in [
      ('institution:academyinfo:0000212', null),
      ('institution:academyinfo:0000212', 'academyinfo:0000212'),
      ('institution:academyinfo:0000212', 'academyinfo:0002949'),
      ('academyinfo:0000212', null),
      ('academyinfo:0002949', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: university,
          universityName: '홍익대학교',
          schoolKind: 'fourYear',
          campusId: campus,
        ).academicSourceId,
        'hongik',
      );
    }
  });

  test('Hongik rejects other years, failures and malformed rows', () async {
    // The server answers an unpublished year with the latest feed.
    expect(
      () => HongikAcademicSource.parse(fixture(2026), 2027),
      throwsFormatException,
    );
    expect(
      () => HongikAcademicSource.parse(
        fixture(2026).replaceFirst('"2026-06-24"', '"2026-02-30"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => HongikAcademicSource.parse(
        fixture(2026).replaceFirst('"2026-06-24"', '"2026-08-24"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => HongikAcademicSource.parse('{"result":"N","data":[]}', 2026),
      throwsFormatException,
    );
    expect(
      () => HongikAcademicSource.parse('{"result":"Y","data":[]}', 2026),
      throwsFormatException,
    );
    final source = HongikAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
