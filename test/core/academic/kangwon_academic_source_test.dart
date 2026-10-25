import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kangwon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Official list pages fetched 2026-10-25 (KST) from
// https://www.kangwon.ac.kr/ko/bbs/714/list.do (`chuncheon_calender`,
// `kangwon-*`) and /ko/bbs/873/list.do (`gwnucalender`, `kangwon-gwnu-*`)
// with `?searchYear=&searchMonth=`. robots.txt disallows /neibis-api/ but
// allows /ko/. Monthly fixtures are verbatim excerpts of each page, from the
// `var toDetailParam` line to the `var bbsId` line; `*-2026-03-page.html`
// keep two whole pages.
String fixture(String bbsId, int year, int month) => File(
  'test/fixtures/academic/kangwon-${bbsId == 'gwnucalender' ? 'gwnu-' : ''}'
  '$year-${month.toString().padLeft(2, '0')}.html',
).readAsStringSync();

const paths = {
  '/ko/bbs/714/list.do': 'chuncheon_calender',
  '/ko/bbs/873/list.do': 'gwnucalender',
};

KangwonAcademicSource source(
  List<String> requests, {
  String Function(String bbsId, int year, int month) body = fixture,
}) => KangwonAcademicSource(
  client: MockClient((request) async {
    expect(request.url.host, 'www.kangwon.ac.kr');
    final bbsId = paths[request.url.path]!;
    final year = int.parse(request.url.queryParameters['searchYear']!);
    final month = int.parse(request.url.queryParameters['searchMonth']!);
    requests.add('$bbsId $year-$month');
    return http.Response(
      body(bbsId, year, month),
      200,
      headers: {'content-type': 'text/html;charset=UTF-8'},
    );
  }),
);

const boards = ['chuncheon_calender', 'gwnucalender'];
final thesis = RegExp('학위(청구)?논문');
// Independent of the parser: every post the page embeds, with its raw title.
final posted = RegExp(
  r'scheduleData\.push\(\{\s*pstSn: (\d+),\s*ttl: "([^"]*)"',
);

void main() {
  test('Kangwon imports both campus boards with post IDs', () async {
    final requests = <String>[];
    final kangwon = source(requests);
    addTearDown(kangwon.close);
    expect(kangwon.website.host, 'www.kangwon.ac.kr');
    final events = await kangwon.fetch(2026);
    expect(requests, [
      for (final bbsId in boards)
        for (var month = 1; month <= 12; month++) '$bbsId 2026-$month',
    ]);
    // 81 Chuncheon/Samcheok posts - 13 graduate thesis rows, plus
    // 43 Gangneung/Wonju posts - 3 rows identical to a Chuncheon/Samcheok post.
    expect(events.length, 68 + 40);
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
    expect(
      events.any(
        (e) =>
            e.sourceId == '73' &&
            e.title == '2학기 확정 전 성적 공개' &&
            e.start == DateTime(2026, 12, 28) &&
            e.end == DateTime(2027, 1, 5),
      ),
      isTrue,
    );
    // Campus badge is added once, not repeated after an existing suffix.
    expect(
      events.where((e) => e.sourceId == '20').single.title,
      '전기 학위수여식(춘천)',
    );
    expect(events.where((e) => e.sourceId == '30').single.title, '계절학기 수강신청');
    final gwnu = events.where((e) => e.sourceId == 'gwnucalender:8').single;
    expect(gwnu.title, '2026학년도 입학식(강릉, 삼척)');
    expect(gwnu.start, DateTime(2026, 2, 26));
    expect(gwnu.url, 'https://www.kangwon.ac.kr/ko/bbs/873/list.do');
    expect(
      events.where((e) => e.sourceId == '8').single.url,
      'https://www.kangwon.ac.kr/ko/bbs/714/list.do',
    );
    // Identical rows on both boards appear once, under the original post ID.
    for (final (id, title, start) in [
      ('32', '수업일수 2/3선', DateTime(2026, 5, 13)),
      ('34', '개교기념일', DateTime(2026, 6, 14)),
      ('64', '수업일수 2/3선', DateTime(2026, 11, 13)),
    ]) {
      expect(
        events
            .where((e) => e.title == title && e.start == start)
            .single
            .sourceId,
        id,
      );
    }
    expect(events.where((e) => thesis.hasMatch(e.title)), isEmpty);
  });

  test('every published Kangwon post is imported once for 2026', () {
    for (final (bbsId, published, graduate) in [
      ('chuncheon_calender', 81, 13),
      ('gwnucalender', 43, 0),
    ]) {
      final posts = <int>{};
      final excluded = <int>{};
      final parsed = <String>{};
      for (var month = 1; month <= 12; month++) {
        final body = fixture(bbsId, 2026, month);
        expect(
          posted.allMatches(body).length,
          'scheduleData.push('.allMatches(body).length,
        );
        for (final row in posted.allMatches(body)) {
          posts.add(int.parse(row[1]!));
          if (thesis.hasMatch(row[2]!)) {
            excluded.add(int.parse(row[1]!));
          }
        }
        parsed.addAll(
          KangwonAcademicSource.parse(
            body,
            2026,
            month,
            bbsId: bbsId,
          ).map((e) => e.sourceId),
        );
      }
      expect(posts, hasLength(published), reason: bbsId);
      expect(excluded, hasLength(graduate), reason: bbsId);
      expect(parsed, {
        for (final id in posts.difference(excluded))
          bbsId == 'gwnucalender' ? 'gwnucalender:$id' : '$id',
      }, reason: bbsId);
    }
  });

  test(
    'Kangwon keeps one identity for rows crossing a year boundary',
    () async {
      final kangwon = source([]);
      addTearDown(kangwon.close);
      // 2025: Chuncheon/Samcheok board is empty; Gangneung/Wonju has one post
      // that runs into January 2026 and appears in both years' feeds.
      final y2025 = await kangwon.fetch(2025);
      expect(y2025.map((e) => e.sourceId), ['gwnucalender:10']);
      final y2026 = await kangwon.fetch(2026);
      final crossing = y2026
          .where((e) => e.sourceId == 'gwnucalender:10')
          .single;
      expect(crossing.toJson(), y2025.single.toJson());
      expect(crossing.start, DateTime(2025, 12, 30));
      expect(crossing.end, DateTime(2026, 1, 6));
      // December 2026 rows also come back in the January 2027 response.
      final january2027 = KangwonAcademicSource.parse(
        fixture('chuncheon_calender', 2027, 1),
        2027,
        1,
      );
      for (final id in ['72', '73']) {
        expect(
          january2027.where((e) => e.sourceId == id).single.toJson(),
          y2026.where((e) => e.sourceId == id).single.toJson(),
        );
      }
    },
  );

  test('Kangwon parses whole list pages like their excerpts', () {
    for (final bbsId in boards) {
      final page = File(
        'test/fixtures/academic/'
        'kangwon-${bbsId == 'gwnucalender' ? 'gwnu-' : ''}2026-03-page.html',
      ).readAsStringSync();
      final parsed = KangwonAcademicSource.parse(page, 2026, 3, bbsId: bbsId);
      expect(parsed, isNotEmpty, reason: bbsId);
      expect(
        parsed.map((e) => e.toJson()),
        KangwonAcademicSource.parse(
          fixture(bbsId, 2026, 3),
          2026,
          3,
          bbsId: bbsId,
        ).map((e) => e.toJson()),
        reason: bbsId,
      );
    }
    // The page entity-escapes titles (thesis rows show `&lt;전공시험&gt;`).
    expect(
      KangwonAcademicSource.parse(
        fixture(
          'chuncheon_calender',
          2026,
          3,
        ).replaceFirst('ttl: "1학기 개강"', 'ttl: "1학기 개강 &lt;공통&gt; &amp; 수업"'),
        2026,
        3,
      ).where((e) => e.sourceId == '24').single.title,
      '1학기 개강 <공통> & 수업',
    );
  });

  test('Kangwon reports an unpublished year instead of an empty calendar', () {
    // The empty January 2025 page, shown for the requested board and month.
    final kangwon = source(
      [],
      body: (bbsId, year, month) => fixture('chuncheon_calender', 2025, 1)
          .replaceFirst(
            "var bbsId = 'chuncheon_calender';",
            "var bbsId = '$bbsId';",
          )
          .replaceFirst(
            'searchYear=2025&amp;amp;searchMonth=1&amp;amp;',
            'searchYear=$year&amp;amp;searchMonth=$month&amp;amp;',
          ),
    );
    addTearDown(kangwon.close);
    expect(kangwon.fetch(2027), throwsFormatException);
  });

  test('Kangwon fails the fetch when either board fails', () async {
    for (final failing in boards) {
      final kangwon = source(
        [],
        body: (bbsId, year, month) => bbsId == failing && month == 6
            ? '<html>점검 중</html>'
            : fixture(bbsId, year, month),
      );
      addTearDown(kangwon.close);
      await expectLater(kangwon.fetch(2026), throwsFormatException);
    }
  });

  test('every Kangwon campus profile resolves to the one kangwon calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000003', null),
      ('institution:academyinfo:0000003', 'academyinfo:0000003'),
      ('institution:academyinfo:0000003', 'academyinfo:0000004'),
      ('institution:academyinfo:0000003', 'academyinfo:0003363'),
      ('institution:academyinfo:0000003', 'academyinfo:0003364'),
      ('academyinfo:0000003', null),
      ('academyinfo:0000004', null),
      ('academyinfo:0003363', null),
      ('academyinfo:0003364', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '강원대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        'kangwon',
        reason: '$universityId $campusId',
      );
    }
  });

  test('Kangwon refuses a stale month response and invalid date', () {
    final body = fixture('chuncheon_calender', 2026, 3);
    expect(
      () => KangwonAcademicSource.parse(body, 2025, 3),
      throwsFormatException,
    );
    expect(
      () => KangwonAcademicSource.parse(body, 2026, 4),
      throwsFormatException,
    );
    expect(
      () => KangwonAcademicSource.parse(
        body.replaceFirst('2026.03.03', '2026.03.32'),
        2026,
        3,
      ),
      throwsFormatException,
    );
    expect(
      () => KangwonAcademicSource.parse('<html>점검 중</html>', 2026, 3),
      throwsFormatException,
    );
    // A post the parser cannot read fully fails instead of being skipped.
    expect(
      () => KangwonAcademicSource.parse(
        body.replaceFirst('ttl: "1학기 개강"', r'ttl: "1학기 \"개강"'),
        2026,
        3,
      ),
      throwsFormatException,
    );
    expect(
      () => KangwonAcademicSource.parse(
        body.replaceFirst('dataSttsCd: "A"', 'dataSttsCd: "D"'),
        2026,
        3,
      ),
      throwsFormatException,
    );
    // A response from the other board is rejected.
    expect(
      () => KangwonAcademicSource.parse(body, 2026, 3, bbsId: 'gwnucalender'),
      throwsFormatException,
    );
  });
}
