import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/yu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/yu-$year.html').readAsStringSync();
void main() {
  test(
    'YU embeds official full periods and deduplicates repeated articles',
    () async {
      final source = YuAcademicSource(
        client: MockClient(
          (request) async => http.Response(
            fixture(int.parse(request.url.queryParameters['srYear']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          ),
        ),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(60));
      expect(
        events.any(
          (e) =>
              e.title == '방학' &&
              e.start == DateTime(2026, 12, 21) &&
              e.end == DateTime(2027, 3, 1),
        ),
        isTrue,
      );
      expect(
        events.where(
          (e) => e.title == '전부(과) 원서접수' && e.start == DateTime(2026, 1, 13),
        ),
        hasLength(1),
      );
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('every published YU row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows =
          jsonDecode(
                RegExp(
                  r'var calData = (\[.*?\]);',
                  dotAll: true,
                ).firstMatch(fixture(year))![1]!,
              )
              as List;
      // Identical rows published under two article numbers count once.
      final distinct = {
        for (final row in rows)
          '${row['startDt']}:${row['endDt']}:${(row['text'] as String).trim()}',
      };
      final events = YuAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(distinct.length));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(distinct.length));
    }
  });
  test('YU event IDs come from published dates and title', () {
    final event = YuAcademicSource.parse(
      fixture(2026),
      2026,
    ).firstWhere((e) => e.title == '전부(과) 원서접수');
    expect(
      event.sourceId,
      '${DateTime(2026, 1, 13).toIso8601String()}:'
      '${DateTime(2026, 1, 14).toIso8601String()}:전부(과) 원서접수',
    );
  });
  test('YU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000151',
      'academyinfo:0000151',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '영남대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'yu',
      );
    }
  });
  test('YU rejects missing data, wrong year, and reversed dates', () {
    expect(
      () => YuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => YuAcademicSource.parse(
        '<script>var srYear = \'2026\'; var calData = [];</script>',
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => YuAcademicSource.parse(
        fixture(
          2026,
        ).replaceFirst('"endDt":"2026-01-07"', '"endDt":"2026-01-04"'),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('YU accepts the last day of a leap February and rejects beyond it', () {
    String page(String start, String end, {int year = 2027}) =>
        '<script>var srYear = \'$year\'; var calData = [{"startDt":"$start",'
        '"endDt":"$end","etcChar2":null,"text":"겨울 일정",'
        '"categoryNm":null,"articleNo":1,"engTitle":"x"}];</script>';
    final leap = YuAcademicSource.parse(page('2028-02-29', '2028-02-29'), 2027);
    expect(leap.single.start, DateTime(2028, 2, 29));
    expect(leap.single.end, DateTime(2028, 3, 1));
    // 2027 is not a leap year, so its February ends on the 28th.
    expect(
      () => YuAcademicSource.parse(
        page('2029-03-01', '2029-03-01', year: 2028),
        2028,
      ),
      throwsFormatException,
    );
    expect(
      () => YuAcademicSource.parse(page('2028-03-01', '2028-03-01'), 2027),
      throwsFormatException,
    );
    expect(
      () => YuAcademicSource.parse(page('2028-02-30', '2028-02-30'), 2027),
      throwsFormatException,
    );
    expect(
      () => YuAcademicSource.parse(page('2027-02-29', '2027-02-29'), 2027),
      throwsFormatException,
    );
  });
}
