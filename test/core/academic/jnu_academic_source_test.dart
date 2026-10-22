import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/jnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/jnu-$year.html').readAsStringSync();

String _jnu(String rows) =>
    '<table id="ContentPlaceHolder1_SubContentPlaceHolder1_gvList">'
    '<tr><th>일정</th><th>일정명</th></tr>$rows</table>';

String _jnuRow({
  String title = '수업',
  String start = '2026.03.03',
  String end = '2026.03.03',
}) => '<tr><td>$start (화) ~ $end (화)</td><td>$title</td></tr>';

/// Published `(date range, title)` cells of the official table, in order.
List<(String, String)> _publishedRows(String body) {
  final table = RegExp(
    r'id="ContentPlaceHolder1_SubContentPlaceHolder1_gvList"[^>]*>(.*?)</table>',
    dotAll: true,
  ).firstMatch(body)!.group(1)!;
  return [
    for (final row in RegExp(
      r'<tr\b[^>]*>(.*?)</tr>',
      dotAll: true,
    ).allMatches(table))
      if (RegExp(
            r'<td\b[^>]*>(.*?)</td>',
            dotAll: true,
          ).allMatches(row.group(1)!).map((m) => m.group(1)!.trim()).toList()
          case [final dates, final title])
        (dates, title),
  ];
}

class _TrackedClient extends MockClient {
  _TrackedClient(super.fn);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  test(
    'Chonnam official fixture deduplicates ceremony and preserves inclusive end dates',
    () {
      final events = ChonnamAcademicSource.parse(fixture(2026), 2026);
      expect(events, hasLength(56));
      expect(events.map((event) => event.sourceId).toSet(), hasLength(56));
      expect(
        events.where((event) => event.title == '2026학년도 입학식'),
        hasLength(1),
      );
      expect(
        events
            .singleWhere((event) => event.title == "제74회 전기('26년 2월) 학위수여식")
            .start,
        DateTime(2026, 2, 26),
      );
      final winter = events.singleWhere((event) => event.title == '동계 계절학기');
      expect(winter.start, DateTime(2026, 12, 28));
      expect(winter.end, DateTime(2027, 1, 23));
      expect(
        events.every(
          (event) => Uri.parse(event.url).queryParameters['YY'] == '2026',
        ),
        isTrue,
      );
    },
  );

  test('every published Chonnam row is imported for each year', () {
    for (final (year, rows, distinct) in [(2025, 57, 57), (2026, 57, 56)]) {
      final published = _publishedRows(fixture(year));
      expect(published, hasLength(rows), reason: '$year');
      expect(published.toSet(), hasLength(distinct), reason: '$year');
      final events = ChonnamAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(distinct), reason: '$year');
      expect(
        events.map((e) => e.title).toSet(),
        published.map((row) => academicHtmlText(row.$2)).toSet(),
        reason: '$year',
      );
    }
    final previous = ChonnamAcademicSource.parse(fixture(2025), 2025);
    final winter = previous.singleWhere((e) => e.title == '동계 계절학기');
    expect(winter.start, DateTime(2025, 12, 26));
    expect(winter.end, DateTime(2026, 1, 23));
  });

  test('Chonnam semester evidence keeps the previously published dates', () {
    final events = ChonnamAcademicSource.parse(fixture(2026), 2026);
    (DateTime, DateTime) period(String title) {
      final event = events.singleWhere((e) => e.title == title);
      return (event.start, event.end);
    }

    expect(period('제1학기 개강').$1, DateTime(2026, 3, 3));
    expect(period('제1학기 종강').$2, DateTime(2026, 6, 24));
    expect(period('하계 계절학기'), (DateTime(2026, 6, 29), DateTime(2026, 7, 24)));
    expect(period('제2학기 개강').$1, DateTime(2026, 9, 1));
    expect(period('제2학기 종강').$2, DateTime(2026, 12, 22));
  });

  test(
    'Chonnam keeps deterministic identities and its university namespace',
    () {
      final sameTitles = ChonnamAcademicSource.parse(
        _jnu(_jnuRow() + _jnuRow(start: '2026.09.01', end: '2026.09.01')),
        2026,
      );
      expect(sameTitles.map((event) => event.sourceId).toSet(), hasLength(2));
      final reversed = ChonnamAcademicSource.parse(
        _jnu(_jnuRow(start: '2026.09.01', end: '2026.09.01') + _jnuRow()),
        2026,
      );
      expect(
        reversed.map((event) => event.toJson()),
        sameTitles.map((event) => event.toJson()),
      );
      final first = sameTitles.first;
      expect(first.dailyId('jnu'), isNot(first.dailyId('dku')));
      final corrected = ChonnamAcademicSource.parse(
        _jnu(_jnuRow(start: '2026.03.04', end: '2026.03.04')),
        2026,
      );
      expect(corrected.single.sourceId, first.sourceId);
    },
  );

  test(
    'Chonnam requests undergraduate mode and requested year without credentials',
    () async {
      final client = _TrackedClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url,
          Uri.parse('https://events.jnu.ac.kr/Schedule.aspx?mode=1&YY=2026'),
        );
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(request.body, isEmpty);
        return http.Response(
          fixture(2026),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final source = ChonnamAcademicSource(client: client);
      expect(source.id, 'jnu');
      expect(source.name, '전남대학교');
      expect(await source.fetch(2026), hasLength(56));
      source.close();
      expect(client.closed, isTrue);
    },
  );

  test('public source jnu rejects failed and oversized replies', () async {
    for (final response in [
      http.Response('unavailable', 503),
      http.Response('x' * 8000001, 200),
    ]) {
      final source = ChonnamAcademicSource(
        client: MockClient((_) async => response),
      );
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
    }
  });

  test(
    'Chonnam rejects missing table, malformed date or reversed period instead of partial calendar',
    () {
      for (final body in [
        '<html>Sign in</html>',
        '<table id="different"></table>',
        _jnu(''),
        _jnu('<tr><td>2026.03.03</td></tr>'),
        _jnu(_jnuRow(title: '')),
        _jnu(_jnuRow(start: '2026.02.30')),
        _jnu(_jnuRow(start: '2026.13.01')),
        _jnu(_jnuRow(start: '2026.02.29')),
        _jnu(_jnuRow(start: '2026.03.04')),
        _jnu(_jnuRow(start: '0000.01.01')),
        _jnu(_jnuRow(start: '2026.03.03') + _jnuRow(start: 'invalid')),
        _jnu(_jnuRow(title: '&#1114112;')),
        _jnu(_jnuRow(title: '&#xD800;')),
      ]) {
        expect(
          () => ChonnamAcademicSource.parse(body, 2026),
          throwsFormatException,
          reason: body,
        );
      }
      expect(
        () => ChonnamAcademicSource.parse(fixture(2026), 2028),
        throwsFormatException,
      );
    },
  );

  test(
    'Chonnam decodes official HTML text and preserves leap-day and year overlap',
    () {
      final event = ChonnamAcademicSource.parse(
        _jnu(
          _jnuRow(
            title: '<span>A &amp; B</span><br />&#39;x&#39; &#X1F600;',
            start: '2024.02.29',
            end: '2024.02.29',
          ),
        ),
        2024,
      ).single;
      expect(event.title, "A & B\n'x' 😀");
      expect(event.end, DateTime(2024, 3, 1));
      final overlap = _jnu(_jnuRow(start: '2025.12.31', end: '2026.01.01'));
      expect(
        ChonnamAcademicSource.parse(overlap, 2026).single.start,
        DateTime(2025, 12, 31),
      );
      expect(
        () => ChonnamAcademicSource.parse(overlap, 2027),
        throwsFormatException,
      );
    },
  );

  test(
    'Chonnam profiles on either campus resolve to its registered calendar',
    () {
      for (final (universityId, campusId) in [
        ('institution:academyinfo:0000023', null),
        ('institution:academyinfo:0000023', 'academyinfo:0000023'),
        ('institution:academyinfo:0000023', 'academyinfo:0000024'),
        ('academyinfo:0000023', null),
        ('academyinfo:0000024', null),
      ]) {
        expect(
          AcademicProfile(
            universityId: universityId,
            universityName: '전남대학교',
            schoolKind: 'fourYear',
            campusId: campusId,
          ).academicSourceId,
          'jnu',
          reason: '$universityId $campusId',
        );
      }
    },
  );
}
