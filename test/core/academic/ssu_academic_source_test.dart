import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/ssu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/ssu-$year.html').readAsStringSync();

void main() {
  test(
    'SSU reads both annual pages and keeps events touching the year',
    () async {
      final requested = <String>[];
      final source = SsuAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, Uri.https('ssu.ac.kr', '/학사/학사일정/').path);
          final year = r.url.queryParameters['years']!;
          requested.add(year);
          return http.Response(
            fixture(int.parse(year)),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['2025', '2026']);
      expect(events, hasLength(60));
      expect(events.any((e) => e.title.contains('개강')), isTrue);
      expect(events.any((e) => e.start.month == 1), isTrue);
      expect(events.any((e) => e.start.month == 12), isTrue);
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
      expect(
        events.every(
          (e) =>
              e.end.isAfter(e.start) &&
              e.start.isBefore(DateTime(2027)) &&
              e.end.isAfter(DateTime(2026)),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2026학년도 1학기 휴학/복학 신청기간(1차)' &&
              e.start == DateTime(2026, 1, 5) &&
              e.end == DateTime(2026, 1, 29),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2026학년도 2학기 성적 이의 신청 처리 기간(교원)' &&
              e.start == DateTime(2026, 12, 28) &&
              e.end == DateTime(2027, 1, 4),
        ),
        isTrue,
      );
    },
  );

  test('every published SSU undergraduate row is imported for each year', () {
    // year: [published rows, graduate-only rows]
    const expected = {2025: (58, 3), 2026: (63, 3)};
    for (final year in [2025, 2026]) {
      final titles = html
          .parse(fixture(year))
          .querySelectorAll(
            '#calendar > div[id] ul.tb > li div.row > div:last-child',
          )
          .map((e) => e.text.trim())
          .toList();
      final graduate = titles.where((t) => t.contains('대학원')).length;
      expect((titles.length, graduate), expected[year]);
      final events = SsuAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(titles.length - graduate));
      expect(
        events.map((e) => e.title),
        titles.where((t) => !t.contains('대학원')),
      );
    }
  });

  test('SSU skips graduate-only rows with and without parentheses', () {
    final titles = SsuAcademicSource.parse(
      fixture(2026),
      2026,
    ).map((e) => e.title);
    expect(titles.where((t) => t.contains('대학원')), isEmpty);
    // The page writes a double space; common rows stay.
    expect(titles.any((t) => RegExp(r'전기\s+학위수여식').hasMatch(t)), isTrue);
  });

  test('SSU keeps the previous year-title-occurrence event IDs', () {
    final ids = SsuAcademicSource.parse(
      fixture(2026),
      2026,
    ).map((e) => e.sourceId).toList();
    expect(ids, contains('2026:2026학년도 1학기 개강:0'));
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('SSU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000143',
      'academyinfo:0000143',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '숭실대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'ssu',
      );
    }
  });

  test(
    'SSU rejects stale year, invalid date, missing month and failure',
    () async {
      expect(
        () => SsuAcademicSource.parse(fixture(2026), 2025),
        throwsFormatException,
      );
      expect(
        () => SsuAcademicSource.parse(
          fixture(2026).replaceFirst('01.05 (월)', '01.32 (월)'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SsuAcademicSource.parse(
          fixture(
            2026,
          ).replaceFirst('id="calendar202607"', 'id="calendar202606"'),
          2026,
        ),
        throwsFormatException,
      );
      final source = SsuAcademicSource(
        client: MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
    },
  );
}
