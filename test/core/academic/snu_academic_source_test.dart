import 'dart:io';

import 'package:daily/core/academic/snu_academic_source.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final body = File('test/fixtures/academic/snu-2026.html').readAsStringSync();
  test('official SNU calendar preserves cross-month and next-year ranges', () {
    final events = SnuAcademicSource.parse(body, 2026);
    expect(events.length, 58);
    final march = events.singleWhere((e) => e.title == '제2학기 복수전공, 연합전공 신청');
    expect(march.start, DateTime(2026, 3, 30));
    expect(march.end, DateTime(2026, 4, 4));
    final winter = events.singleWhere(
      (e) => e.title == '2027학년도 제1학기 복학(귀) 신청',
    );
    expect(winter.end, DateTime(2027, 2, 27));
    expect(
      events.singleWhere((e) => e.title == '동계 계절수업 종강').start,
      DateTime(2027, 1, 25),
    );
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
  });
  test(
    'wrong year, invalid dates and missing page fail instead of importing',
    () {
      expect(() => SnuAcademicSource.parse(body, 2025), throwsFormatException);
      expect(
        () =>
            SnuAcademicSource.parse(body.replaceFirst('01(일)', '32(일)'), 2026),
        throwsFormatException,
      );
      expect(
        () => SnuAcademicSource.parse('<html>Unavailable</html>', 2026),
        throwsFormatException,
      );
    },
  );
  test(
    'fetch includes prior academic year and excludes following calendar year',
    () async {
      final requests = <int>[];
      final prior = File(
        'test/fixtures/academic/snu-2025.html',
      ).readAsStringSync();
      final source = SnuAcademicSource(
        client: MockClient((request) async {
          final year = int.parse(request.url.queryParameters['year']!);
          requests.add(year);
          return http.Response(
            year == 2025 ? prior : body,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(requests, [2025, 2026]);
      expect(events.any((e) => e.start.month == 1), isTrue);
      expect(events.every((e) => e.start.isBefore(DateTime(2027))), isTrue);
    },
  );
  test('every published SNU row is imported for each academic year', () {
    for (final year in [2025, 2026]) {
      final page = File(
        'test/fixtures/academic/snu-$year.html',
      ).readAsStringSync();
      final rows = html
          .parse(page)
          .querySelectorAll('section.calendar .work-wrap .work')
          .length;
      expect(rows, year == 2025 ? 60 : 58);
      final events = SnuAcademicSource.parse(page, year);
      expect(events, hasLength(rows));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(rows));
    }
  });
  test('SNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000019',
      'academyinfo:0000019',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '서울대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'snu',
      );
    }
  });
  test('repeated or out-of-window SNU month sections are rejected', () {
    for (final damaged in [
      body.replaceFirst(
        '<span class="month-text">4월</span>',
        '<span class="month-text">3월</span>',
      ),
      body.replaceFirst(
        '<span class="month-text">4월</span>',
        '<span class="month-text">1월</span>',
      ),
      body.replaceFirst('2027년 1월', '2028년 1월'),
    ]) {
      expect(
        () => SnuAcademicSource.parse(damaged, 2026),
        throwsFormatException,
      );
    }
  });
}
