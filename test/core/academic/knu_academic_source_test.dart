import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/knu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/knu-$year.html').readAsStringSync();
void main() {
  test('KNU fetches the selected year and keeps title periods', () async {
    final source = KnuAcademicSource(
      client: MockClient((r) async {
        expect(r.url.path, '/wbbs/wbbs/user/yearSchedule/index.action');
        expect(r.url.queryParameters['menu_idx'], '43');
        return http.Response.bytes(
          File(
            'test/fixtures/academic/knu-${r.url.queryParameters['vo.search_year']}.html',
          ).readAsBytesSync(),
          200,
          headers: {'content-type': 'text/html;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(events, hasLength(62));
    expect(events.map((e) => e.sourceId).toSet(), hasLength(62));
    final spring = events.singleWhere((e) => e.title == '1학기 수강신청');
    expect(spring.start, DateTime(2026, 2, 10));
    expect(spring.end, DateTime(2026, 2, 13));
    expect(events.any((e) => e.title == '2026학년도 2학기 재학생 등록'), isTrue);
    expect(events.any((e) => e.title.startsWith('[대학원]')), isFalse);
  });
  test('every published KNU undergraduate row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('#calendar li')
          .where((row) => row.querySelector('.day') != null)
          .toList();
      final graduate = rows.where((row) => row.text.contains('[대학원]')).length;
      final events = KnuAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(rows.length - graduate));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    }
    // The October row omits the trailing dot: "(10.29)".
    final leave = KnuAcademicSource.parse(
      fixture(2025),
      2025,
    ).where((e) => e.title == '일반휴학원 접수종료').map((e) => e.start);
    expect(leave, [DateTime(2025, 4, 24), DateTime(2025, 10, 29)]);
  });
  test('KNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000005',
      'academyinfo:0000005',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경북대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'knu',
      );
    }
  });
  test('KNU rejects incorrect year, invalid date and missing month', () {
    final body = fixture(2026);
    expect(() => KnuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => KnuAcademicSource.parse(
        body.replaceFirst('02.10(화)', '02.30(화)'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KnuAcademicSource.parse(
        body.replaceFirst('<span>2026년</span>12월', '<span>2026년</span>11월'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
