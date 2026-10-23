import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/gnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/gnu-$year.json').readAsStringSync();

void main() {
  test(
    'GNU reads all undergraduate months with published stable IDs and winter rollover',
    () async {
      final source = GnuAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/main/ps/schdul/selectSchdulList.do');
          final year = Uri.splitQueryString(r.body)['srchYear']!;
          return http.Response.bytes(
            utf8.encode(fixture(int.parse(year))),
            200,
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      // 학부 50행 + 학ㆍ석사 연계과정 모집 대학원 2행(13999, 56715).
      expect(events.length, 52);
      expect(events.map((e) => e.sourceId).toSet().length, 52);
      expect(events.any((e) => e.title.contains('대학원')), isFalse);
      expect(
        events.singleWhere((e) => e.sourceId == '13999').title,
        '2026학년도 전기 학·석사학위 및 학·석·박사 통합학위 연계과정 모집',
      );
      expect(
        events.singleWhere((e) => e.sourceId == '56715').start,
        DateTime(2026, 7, 6),
      );
      expect(events.any((e) => e.sourceId == '14000'), isFalse);
      final winter = events.singleWhere((e) => e.sourceId == '13940');
      expect(winter.title, '동계계절학기');
      expect(winter.start, DateTime(2025, 12, 23));
      expect(winter.end, DateTime(2026, 1, 17));
      expect(
        events.singleWhere((e) => e.sourceId == '53779').start,
        DateTime(2026, 3, 3),
      );
    },
  );
  test('every published GNU undergraduate row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final links = html
          .parse(jsonDecode(fixture(year)) as String)
          .querySelectorAll('.tbl_tbody_year td > a');
      final undergraduate = links
          .where((a) => a.text.trim().startsWith('[학부]'))
          .length;
      final graduate = links
          .where((a) => a.text.trim().startsWith('[대학원]'))
          .length;
      // Every published row is either an undergraduate or graduate entry.
      expect(undergraduate + graduate, links.length);
      final linked = links
          .where(
            (a) =>
                a.text.trim().startsWith('[대학원]') && a.text.contains('연계과정 모집'),
          )
          .length;
      expect(linked, 2);
      expect(
        GnuAcademicSource.parse(fixture(year), year),
        hasLength(undergraduate + linked),
      );
    }
  });
  test('GNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000007',
      'academyinfo:0000007',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경상국립대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'gnu',
      );
    }
  });
  test('GNU refuses stale year and malformed calendar dates', () {
    final body = fixture(2026);
    expect(() => GnuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => GnuAcademicSource.parse(
        body.replaceFirst('2025/12/23', '2025/12/32'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => GnuAcademicSource.parse('"<div></div>"', 2026),
      throwsFormatException,
    );
  });
  test('GNU treats a failed response as an error', () async {
    final source = GnuAcademicSource(
      client: MockClient((_) async => http.Response('', 500)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
