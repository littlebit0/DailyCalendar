import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kangwon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/kangwon-$year-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();

KangwonAcademicSource source(List<String> requests) => KangwonAcademicSource(
  client: MockClient((request) async {
    expect(request.url.path, '/neibis-api/v1/core/bbs/plan/calendar');
    expect(request.url.queryParameters['bbsId'], 'chuncheon_calender');
    final year = int.parse(request.url.queryParameters['searchYear']!);
    final month = int.parse(request.url.queryParameters['searchMonth']!);
    requests.add('$year-$month');
    return http.Response(
      fixture(year, month),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

void main() {
  test(
    'Kangwon imports the Chuncheon/Samcheok calendar with post IDs',
    () async {
      final requests = <String>[];
      final kangwon = source(requests);
      addTearDown(kangwon.close);
      expect(kangwon.website.host, 'www.kangwon.ac.kr');
      final events = await kangwon.fetch(2026);
      expect(requests, List.generate(12, (i) => '2026-${i + 1}'));
      expect(events.length, 81);
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
      expect(events.every((e) => e.url.contains('kangwon.ac.kr')), isTrue);
    },
  );

  test('every published Kangwon post is imported once for 2026', () {
    final posts = <int>{};
    final parsed = <String>{};
    for (var month = 1; month <= 12; month++) {
      final body = fixture(2026, month);
      posts.addAll([
        for (final row in jsonDecode(body)['data'] as List) row['pstSn'] as int,
      ]);
      parsed.addAll(
        KangwonAcademicSource.parse(body, 2026, month).map((e) => e.sourceId),
      );
    }
    expect(posts, hasLength(81));
    expect(parsed, posts.map((id) => '$id').toSet());
  });

  test('Kangwon reports an unpublished year instead of an empty calendar', () {
    final kangwon = source([]);
    addTearDown(kangwon.close);
    expect(kangwon.fetch(2025), throwsFormatException);
  });

  test('Kangwon profiles resolve to the Chuncheon/Samcheok calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000003', null),
      ('institution:academyinfo:0000003', 'academyinfo:0000003'),
      ('institution:academyinfo:0000003', 'academyinfo:0000004'),
      ('academyinfo:0000003', null),
      ('academyinfo:0000004', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '강원대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        'kangwon',
      );
    }
    // Gangneung/Wonju publish their own board (gwnucalender); not wired yet.
    for (final campusId in ['academyinfo:0003363', 'academyinfo:0003364']) {
      expect(
        AcademicProfile(
          universityId: 'institution:academyinfo:0000003',
          universityName: '강원대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        isNull,
      );
    }
  });

  test('Kangwon refuses a stale month response and invalid date', () {
    final body = fixture(2026, 3);
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
      () => KangwonAcademicSource.parse('{"icon":"error"}', 2026, 3),
      throwsFormatException,
    );
  });
}
