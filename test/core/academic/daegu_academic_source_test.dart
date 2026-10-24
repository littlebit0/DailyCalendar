import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/daegu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(int year) =>
      File('test/fixtures/academic/daegu-$year.html').readAsStringSync();
  test(
    'Daegu annual fetch includes previous academic year January and splits published events',
    () async {
      final years = <int>[];
      final source = DaeguAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters['schedule_info_seq'], '1');
          final year = int.parse(
            request.url.queryParameters['schedule_start_date']!,
          );
          years.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(years, [2025, 2026]);
      expect(events.length, 70);
      // The published page lists this period twice; it is one event.
      expect(events.where((e) => e.title == '2026학년도 제1학기 복학 신청기간').length, 1);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.any((e) => e.start.month == 1), isTrue);
      expect(events.every((e) => !e.title.contains('▪')), isTrue);
      final finals = events.singleWhere((e) => e.title == '제1학기 기말시험기간');
      expect(finals.start, DateTime(2026, 6, 9));
      expect(finals.end, DateTime(2026, 6, 16));
    },
  );
  test('every published Daegu row is imported for each year', () {
    // Published row counts as of 2026-10-23; a row may list several titles.
    for (final (year, rows, titles) in [(2025, 66, 65), (2026, 68, 71)]) {
      final published = <String>{};
      final document = html.parse(fixture(year));
      final cells = document
          .querySelectorAll('table.tbl_cal tr')
          .map((row) => row.querySelectorAll('td'))
          .where((cells) => cells.isNotEmpty)
          .toList();
      expect(cells, hasLength(rows));
      for (final row in cells) {
        row[1].querySelector('span')!.remove();
        for (final title in row[1].text.split('▪')) {
          if (title.trim().isNotEmpty) {
            published.add('${row[0].text.trim()}|${title.trim()}');
          }
        }
      }
      final events = DaeguAcademicSource.parse(fixture(year), year);
      expect(published, hasLength(titles));
      expect(events, hasLength(titles));
      expect(
        events.map((e) => e.title).toSet(),
        published.map((p) => p.split('|').last).toSet(),
      );
    }
  });
  test('Daegu profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000084',
      'academyinfo:0000084',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '대구대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'daegu',
      );
    }
  });
  test('Daegu refuses wrong year, malformed dates and graduate calendar', () {
    final body = fixture(2026);
    expect(() => DaeguAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => DaeguAcademicSource.parse(
        body.replaceFirst('03-01 (일)', '03-32 (일)'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => DaeguAcademicSource.parse(
        body.replaceFirst('2026년도 대학 일정', '2026년도 일반대학원 일정'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test('Daegu refuses rows that lost their month heading', () {
    final body = fixture(2026);
    const heading = '<th rowspan="1" class="monthArea03">3월</th>';
    final second = body.indexOf(heading, body.indexOf(heading) + 1);
    expect(second, greaterThan(0));
    for (final broken in [
      // Standard rowspan layout: later rows of the month have no <th>.
      body.replaceRange(second, second + heading.length, ''),
      body.replaceFirst(heading, '<th class="monthArea03"></th>'),
      body.replaceFirst('<tr>\n            $heading', '<tr>$heading</tr><tr>'),
    ]) {
      expect(broken, isNot(body));
      expect(
        () => DaeguAcademicSource.parse(broken, 2026),
        throwsFormatException,
      );
    }
  });
}
