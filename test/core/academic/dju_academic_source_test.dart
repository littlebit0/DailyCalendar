import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/dju_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/dju-$year.html').readAsStringSync();
void main() {
  test(
    'DJU calendar year joins two academic years with date-only ends',
    () async {
      final requested = <String>[];
      final source = DjuAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/dju/sv/schdulView/calendar.do');
          final form = Uri.splitQueryString(r.body);
          expect(form['section'], '3');
          requested.add(form['year']!);
          return http.Response(
            fixture(int.parse(form['year']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['2025', '2026']);
      // 14 January-February rows of 2025 and 60 March-December rows of 2026.
      expect(events, hasLength(74));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(74));
      expect(
        events.every(
          (e) => e.end.isAfter(e.start) && e.start.hour == 0 && e.end.hour == 0,
        ),
        isTrue,
      );
      bool has(String title, DateTime start, DateTime end) => events.any(
        (e) => e.title == title && e.start == start && e.end == end,
      );
      expect(
        has('기말시험 성적조회 및 정정 기간', DateTime(2025, 12, 31), DateTime(2026, 1, 8)),
        isTrue,
      );
      expect(
        has('2025학년도 전기 학위수여식', DateTime(2026, 2, 20), DateTime(2026, 2, 21)),
        isTrue,
      );
      expect(
        has('중간시험 성적입력 기간', DateTime(2026, 4, 28), DateTime(2026, 5, 7)),
        isTrue,
      );
      expect(
        has('기말시험 성적조회 및 정정기간', DateTime(2026, 12, 30), DateTime(2027, 1, 7)),
        isTrue,
      );
      expect(events.any((e) => e.start.isBefore(DateTime(2025, 12))), isFalse);
      expect(events.any((e) => !e.start.isBefore(DateTime(2027))), isFalse);
    },
  );
  test('every published DJU row is imported for each academic year', () {
    for (final year in [2025, 2026]) {
      // Mobile tables repeat each month and cross-month periods appear twice.
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.schedule_calendar > table tbody tr')
          .map((row) => row.text.replaceAll(RegExp(r'\s+'), ' ').trim())
          .toSet();
      expect(
        DjuAcademicSource.parse(fixture(year), year),
        hasLength(rows.length),
      );
    }
  });
  test('DJU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000095',
      'academyinfo:0000095',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '대전대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'dju',
      );
    }
  });
  test('DJU rejects incorrect year, malformed dates and missing months', () {
    expect(
      () => DjuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => DjuAcademicSource.parse(
        fixture(2026).replaceFirst('>04-06<', '>04-31<'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => DjuAcademicSource.parse(
        fixture(2026).replaceFirst('>04-06<', '>2026.04.06<'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => DjuAcademicSource.parse(
        fixture(2026).replaceAll('2026년 4월 학사일정을', '2026년 3월 학사일정을'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => DjuAcademicSource.parse('<html></html>', 2026),
      throwsFormatException,
    );
  });
  test('DJU failed response keeps the previous calendar', () async {
    final source = DjuAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
