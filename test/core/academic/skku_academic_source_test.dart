import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/skku_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/skku-$year.html').readAsStringSync();
void main() {
  test(
    'SKKU keeps January and February from the previous academic year',
    () async {
      final requested = <int>[];
      final source = SkkuAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/skku/edu/bachelor/ca_de_schedule.do');
          expect(r.url.queryParameters['mode'], 'view');
          final year = int.parse(r.url.queryParameters['srBachelorYear']!);
          requested.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, [2025, 2026]);
      expect(events, hasLength(80));
      expect(events.where((e) => e.title == '1학기 개강'), hasLength(1));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
      expect(
        events.any(
          (e) =>
              e.title == '2026학년도 1학기 일반휴학 신청' &&
              e.start == DateTime(2026, 1, 26) &&
              e.end == DateTime(2026, 3, 7),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2027학년도 1학기 일반휴학 신청' &&
              e.start == DateTime(2027, 1, 25) &&
              e.end == DateTime(2027, 3, 6),
        ),
        isFalse,
      );
    },
  );
  test('every published SKKU record is imported for each academic year', () {
    // Published rows = imported + graduate-only + combined-degree applications.
    final counts = <int, List<int>>{};
    for (final year in [2025, 2026]) {
      final text = html
          .parse(fixture(year))
          .querySelector('textarea[name=articleText]')!
          .text;
      final titles = [
        for (final group in (jsonDecode(text) as Map).values)
          for (final entry in ((group as List).single as Map).entries)
            if ('${entry.key}'.startsWith('con_')) '${entry.value}'.trim(),
      ];
      final graduate = titles.where(SkkuAcademicSource.isGraduateOnly).length;
      final combined = titles
          .where(SkkuAcademicSource.isCombinedDegreeApplication)
          .length;
      final events = SkkuAcademicSource.parse(fixture(year), year);
      expect(
        events.map((e) => e.title).toList()..sort(),
        titles
            .where(
              (t) =>
                  !SkkuAcademicSource.isGraduateOnly(t) &&
                  !SkkuAcademicSource.isCombinedDegreeApplication(t),
            )
            .toList()
          ..sort(),
      );
      counts[year] = [titles.length, graduate, combined, events.length];
    }
    expect(counts, {
      2025: [90, 8, 2, 80],
      2026: [91, 8, 2, 81],
    });
  });
  test(
    'SKKU leaves out graduate-only rows and combined-degree applications',
    () {
      final titles = SkkuAcademicSource.parse(
        fixture(2026),
        2026,
      ).map((e) => e.title).toSet();
      for (final excluded in [
        '대학원과정 논문제출자격시험 응시(면제) 신청',
        '대학원과정 학위논문 예비·심사 신청',
        '2026년 8월 학위취득예정 대학원과정 학위논문 On-line 탑재 완료 기한',
        '2026학년도 2학기 학부·대학원 연계과정 신청',
      ]) {
        expect(titles, isNot(contains(excluded)));
      }
      // Rows shared with undergraduates stay.
      expect(titles, contains('학사·대학원과정 마이크로디그리 1차 신청'));
      expect(titles, contains('학사과정 조기졸업/석사과정 수업연한 단축/석박사통합과정 조기수료·이수포기 신청'));
      expect(
        SkkuAcademicSource.parse(fixture(2025), 2025).map((e) => e.title),
        isNot(contains('2026학년도 1학기 학사과정 학석사연계과정 신청')),
      );
    },
  );
  test('SKKU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000133',
      'academyinfo:0000133',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '성균관대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'skku',
      );
    }
  });
  test('SKKU rejects wrong year, malformed date and record count drift', () {
    expect(
      () => SkkuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => SkkuAcademicSource.parse(
        fixture(2026).replaceFirst('2026-03-01', '2026-02-30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SkkuAcademicSource.parse(
        fixture(
          2026,
        ).replaceFirst('&#034;size&#034;:11', '&#034;size&#034;:12'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
