import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/dku_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/dku-$year.json').readAsStringSync();

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

// Site group 20118 reply for 2025 and 2026, fetched 2026-10-24.
const _siteReply = '{"data":[],"status":true}';

http.Response _json(String body) => http.Response.bytes(utf8.encode(body), 200);

DankookAcademicSource _groups(Map<String, http.Response> replies) =>
    DankookAcademicSource(
      client: MockClient(
        (request) async => replies[request.url.pathSegments[4]]!,
      ),
    );

void main() {
  test(
    'Dankook public request uses an entire Korean year and keeps Korean dates',
    () async {
      final paths = <String>[];
      final source = DankookAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.host, 'www.dankook.ac.kr');
          expect(request.url.query, isEmpty);
          expect(request.headers.containsKey('authorization'), isFalse);
          paths.add(request.url.path);
          return http.Response(
            request.url.pathSegments[4] == '0' ? fixture(2026) : _siteReply,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(source.id, 'dku');
      expect(source.name, '단국대학교');
      final events = await source.fetch(2026);
      source.close();
      expect(paths, [
        '/o/dku_calendar-rest/calendar/events/20118/1767193200000/1798729199999',
        '/o/dku_calendar-rest/calendar/events/0/1767193200000/1798729199999',
      ]);
      expect(events, hasLength(126));
      final start = events.singleWhere((e) => e.title == '2026학년도 1학기 개강');
      expect(start.start, DateTime(2026, 3, 3));
      expect(start.end, DateTime(2026, 3, 4));
      final winter = events.singleWhere(
        (e) => e.title == '2026학년도 계절(동계)학기 수업기간',
      );
      expect(winter.start, DateTime(2026, 12, 24));
      expect(winter.end, DateTime(2027, 1, 16));
      expect(events.first.start, DateTime(2025, 12, 15));
      expect(
        events.every(
          (e) =>
              !e.start.isUtc &&
              e.end.isAfter(e.start) &&
              e.url == 'https://www.dankook.ac.kr/web/kor/-2014-',
        ),
        isTrue,
      );
    },
  );

  test('every published Dankook row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = (jsonDecode(fixture(year))['data'] as List).length;
      final events = DankookAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(rows), reason: '$year');
      expect(events.map((e) => e.sourceId).toSet(), hasLength(rows));
    }
  });

  test(
    'Dankook merges site group rows and drops copies of portal rows',
    () async {
      final portal = jsonDecode(fixture(2026))['data'] as List;
      final source = _groups({
        '20118': _json(_dku([portal.first, _dkuRow(title: '사이트 일정')])),
        '0': _json(fixture(2026)),
      });
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(127));
      expect(
        events.where((e) => e.title == portal.first['title']),
        hasLength(1),
      );
      expect(events.where((e) => e.title == '사이트 일정'), hasLength(1));
    },
  );

  test('Dankook fails when either calendar group fails', () async {
    for (final site in [
      http.Response('unavailable', 503),
      _json(_dku([], status: false)),
    ]) {
      final source = _groups({'20118': site, '0': _json(fixture(2026))});
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
    }
  });

  test('Dankook identities ignore row order and survive date corrections', () {
    final rows = [_dkuRow(title: 'B'), _dkuRow(title: 'A')];
    final normal = DankookAcademicSource.parse(_dku(rows), 2026);
    final reversed = DankookAcademicSource.parse(
      _dku(rows.reversed.toList()),
      2026,
    );
    expect(reversed.map((e) => e.toJson()), normal.map((e) => e.toJson()));
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
  });

  test('Dankook campuses resolve to the shared registered calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000082', null),
      ('institution:academyinfo:0000082', 'academyinfo:0000082'),
      ('institution:academyinfo:0000082', 'academyinfo:0002726'),
      ('academyinfo:0000082', null),
      ('academyinfo:0002726', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '단국대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        'dku',
        reason: '$universityId $campusId',
      );
    }
  });

  test('Dankook rejects failed and oversized replies', () async {
    for (final response in [
      http.Response('unavailable', 503),
      http.Response('x' * 8000001, 200),
    ]) {
      final source = DankookAcademicSource(
        client: MockClient((_) async => response),
      );
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
    }
  });

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
}
