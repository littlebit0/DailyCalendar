import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _dku(List<Object?> records, {bool status = true}) =>
    jsonEncode({'status': status, 'data': records});

Map<String, Object?> _dkuRow({
  String title = '수업',
  String start = '2026-03-03T00:00:00+09:00',
  String end = '2026-03-03T23:59:00+09:00',
}) => {
  'title': title,
  'startTime': DateTime.parse(start).millisecondsSinceEpoch.toString(),
  'endTime': DateTime.parse(end).millisecondsSinceEpoch.toString(),
};

String _jnu(String rows) =>
    '<table id="ContentPlaceHolder1_SubContentPlaceHolder1_gvList">'
    '<tr><th>일정</th><th>일정명</th></tr>$rows</table>';

String _jnuRow({
  String title = '수업',
  String start = '2026.03.03',
  String end = '2026.03.03',
}) => '<tr><td>$start (화) ~ $end (화)</td><td>$title</td></tr>';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
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
  late String dkuFixture;
  late String jnuFixture;
  setUpAll(() {
    dkuFixture = File(
      'test/fixtures/academic/dku-2026.json',
    ).readAsStringSync();
    jnuFixture = File(
      'test/fixtures/academic/jnu-2026.html',
    ).readAsStringSync();
  });

  test(
    'Dankook official fixture retains Korean dates, overlapping year and all records',
    () {
      final events = DankookAcademicSource.parse(dkuFixture, 2026);
      expect(events, hasLength(125));
      expect(events.map((event) => event.sourceId).toSet(), hasLength(125));
      final start = events.singleWhere(
        (event) => event.title == '2026학년도 1학기 개강',
      );
      expect(start.start, DateTime(2026, 3, 3));
      expect(start.end, DateTime(2026, 3, 4));
      final winter = events.singleWhere(
        (event) => event.title == '2026학년도 계절(동계)학기 수업기간',
      );
      expect(winter.start, DateTime(2026, 12, 23));
      expect(winter.end, DateTime(2027, 1, 15));
      expect(events.first.start.year, 2025);
      expect(
        events.every(
          (event) =>
              event.start.hour == 0 &&
              !event.start.isUtc &&
              event.end.isAfter(event.start),
        ),
        isTrue,
      );
      expect(
        events.every(
          (event) => event.url == 'https://www.dankook.ac.kr/web/kor/-2014-',
        ),
        isTrue,
      );
    },
  );

  test(
    'Chonnam official fixture deduplicates ceremony and preserves inclusive end dates',
    () {
      final events = ChonnamAcademicSource.parse(jnuFixture, 2026);
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

  test(
    'both sources use deterministic identities and distinct university namespaces',
    () {
      final rows = [_dkuRow(title: 'B'), _dkuRow(title: 'A')];
      final normal = DankookAcademicSource.parse(_dku(rows), 2026);
      final reversed = DankookAcademicSource.parse(
        _dku(rows.reversed.toList()),
        2026,
      );
      expect(
        reversed.map((event) => event.toJson()),
        normal.map((event) => event.toJson()),
      );
      expect(
        DankookAcademicSource.parse(_dku([rows.first, rows.first]), 2026),
        hasLength(1),
      );
      final corrected = DankookAcademicSource.parse(
        _dku([
          _dkuRow(
            title: 'A',
            start: '2026-03-04T00:00:00+09:00',
            end: '2026-03-04T23:59:00+09:00',
          ),
        ]),
        2026,
      );
      expect(corrected.single.sourceId, normal.first.sourceId);
      expect(normal.first.dailyId('dku'), isNot(normal.first.dailyId('jnu')));
      final sameTitles = ChonnamAcademicSource.parse(
        _jnu(_jnuRow() + _jnuRow(start: '2026.09.01', end: '2026.09.01')),
        2026,
      );
      expect(sameTitles.map((event) => event.sourceId).toSet(), hasLength(2));
    },
  );

  test(
    'Dankook public request uses an entire Korean year without credentials',
    () async {
      final client = _TrackedClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'www.dankook.ac.kr');
        expect(
          request.url.path,
          '/o/dku_calendar-rest/calendar/events/0/1767193200000/1798729199999',
        );
        expect(request.url.query, isEmpty);
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(request.body, isEmpty);
        return http.Response(
          dkuFixture,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final source = DankookAcademicSource(client: client);
      expect(source.id, 'dku');
      expect(source.name, '단국대학교');
      expect(await source.fetch(2026), hasLength(125));
      source.close();
      expect(client.closed, isTrue);
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
          jnuFixture,
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

  for (final factory in <AcademicSource Function(http.Client)>[
    (client) => DankookAcademicSource(client: client),
    (client) => ChonnamAcademicSource(client: client),
  ]) {
    test(
      'public source ${factory(MockClient((_) async => http.Response('', 200))).id} rejects failed and oversized replies',
      () async {
        for (final response in [
          http.Response('unavailable', 503),
          http.Response('x' * 8000001, 200),
        ]) {
          final source = factory(MockClient((_) async => response));
          await expectLater(source.fetch(2026), throwsFormatException);
          source.close();
        }
      },
    );
  }

  test(
    'Dankook rejects malformed rows, impossible timestamps and reversed periods',
    () {
      for (final body in [
        'null',
        '[]',
        '{}',
        _dku([], status: false),
        _dku([]),
        _dku([null]),
        _dku([
          {'title': 7},
        ]),
        _dku([_dkuRow(title: ' ')]),
        _dku([
          {..._dkuRow(), 'startTime': null},
        ]),
        _dku([
          {..._dkuRow(), 'startTime': 'not-a-timestamp'},
        ]),
        _dku([
          {..._dkuRow(), 'startTime': '9223372036854775807'},
        ]),
        _dku([_dkuRow(start: '1899-12-31T00:00:00+09:00')]),
        _dku([_dkuRow(start: '2026-03-04T00:00:00+09:00')]),
      ]) {
        expect(
          () => DankookAcademicSource.parse(body, 2026),
          throwsFormatException,
          reason: body,
        );
      }
    },
  );

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
    'eight additional term defaults are bounded by their named official calendar fixtures',
    () async {
      final defaults = await TimetablePeriodDefaults.load(
        bundle: _FileBundle(),
      );
      final raw =
          jsonDecode(
                File('assets/timetable/term-periods.json').readAsStringSync(),
              )
              as Map;
      final events = {
        'dku': DankookAcademicSource.parse(dkuFixture, 2026),
        'jnu': ChonnamAcademicSource.parse(jnuFixture, 2026),
      };
      final expected = {
        'dku': {
          '1': ('2026-03-03', '2026-06-19'),
          '여름': ('2026-06-23', '2026-07-13'),
          '2': ('2026-09-01', '2026-12-21'),
          '겨울': ('2026-12-23', '2027-01-14'),
        },
        'jnu': {
          '1': ('2026-03-03', '2026-06-23'),
          '여름': ('2026-06-29', '2026-07-23'),
          '2': ('2026-09-01', '2026-12-21'),
          '겨울': ('2026-12-28', '2027-01-22'),
        },
      };
      for (final university
          in (raw['additionalUniversities'] as List).cast<Map>()) {
        final id = university['university'] as String;
        expect(defaults.periodsFor(id), hasLength(4));
        for (final term in (university['terms'] as List).cast<Map>()) {
          final semester = term['semester'] as String;
          final period = defaults.periodFor(2026, semester, university: id)!;
          expect(period.start, DateTime.parse(expected[id]![semester]!.$1));
          expect(period.end, DateTime.parse(expected[id]![semester]!.$2));
          final evidence = [
            for (final title in (term['sourceTitles'] as List).cast<String>())
              events[id]!.singleWhere((event) => event.title == title),
          ];
          final start = evidence
              .map((event) => event.start)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          final end = evidence
              .map((event) => event.end)
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .subtract(const Duration(days: 1));
          expect(period.start, start);
          expect(period.end, end);
          expect(period.contains(period.start), isTrue);
          expect(period.contains(period.end), isTrue);
          expect(
            period.contains(period.start.subtract(const Duration(days: 1))),
            isFalse,
          );
          expect(
            period.contains(period.end.add(const Duration(days: 1))),
            isFalse,
          );
        }
        expect(defaults.periodFor(2025, '2', university: id), isNull);
        expect(defaults.periodFor(2027, '1', university: id), isNull);
      }
      expect(defaults.periodsFor('unknown'), isEmpty);
    },
  );
}
