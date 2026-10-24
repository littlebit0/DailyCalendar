import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/sookmyung_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/sookmyung-$year.json').readAsStringSync();

SookmyungAcademicSource source(List<String> requested) =>
    SookmyungAcademicSource(
      client: MockClient((r) async {
        expect(r.url.path, '/kr/university-life/academic-calendar.do');
        expect(r.url.queryParameters['mode'], 'getYearCalendar');
        expect(r.url.queryParameters['siteId'], 'kr');
        final year = r.url.queryParameters['selectedYear']!;
        requested.add(year);
        return http.Response.bytes(
          utf8.encode(fixture(int.parse(year))),
          200,
          headers: {'content-type': 'application/json;charset=UTF-8'},
        );
      }),
    );

void main() {
  test('Sookmyung flattens annual months and deduplicates repeated ranges', () {
    final body = fixture(2026);
    final events = SookmyungAcademicSource.parse(body, 2026);
    expect(events.length, greaterThan(100));
    expect(
      events.every(
        (e) => e.end.isAfter(e.start) && e.start.isBefore(DateTime(2027)),
      ),
      isTrue,
    );
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
    expect(
      () => SookmyungAcademicSource.parse(
        body.replaceFirst('"hasData":true', '"hasData":false'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SookmyungAcademicSource.parse('{"data":[]}', 2026),
      throwsFormatException,
    );
  });

  test('every published Sookmyung row of the year is imported', () {
    // Published rows = imported + combined-degree application rows.
    for (final (year, published, combined) in [
      (2025, 116, 5),
      (2026, 120, 4),
    ]) {
      final months = (jsonDecode(fixture(year)) as Map)['data'] as List;
      final rows = [
        for (final month in months.take(12).cast<List>()) ...month.cast<Map>(),
      ];
      final excluded = rows.where(
        (row) => SookmyungAcademicSource.isCombinedDegreeApplication(
          row['content'] as String,
        ),
      );
      final events = SookmyungAcademicSource.parse(fixture(year), year);
      expect(rows, hasLength(published));
      expect(excluded, hasLength(combined));
      expect(events, hasLength(published - combined));
      expect(events.map((e) => e.sourceId).toSet(), {
        for (final row in rows)
          if (!excluded.contains(row)) '${row['calendarSeq']}',
      });
    }
  });

  test('Sookmyung leaves out combined-degree track applications', () {
    final body = fixture(2026);
    expect(body, contains('"content":"학석사연계과정 지원자 모집"'));
    expect(body, contains('"content":"학석사연계과정 합격자 발표"'));
    final events = SookmyungAcademicSource.parse(body, 2026);
    expect(events.any((e) => e.title.contains('학석사연계과정')), isFalse);
    for (final id in ['5946', '5957', '6057', '6067']) {
      expect(events.map((e) => e.sourceId), isNot(contains(id)));
    }
  });

  test('Sookmyung keeps calendarSeq IDs and date-only ranges', () async {
    final requested = <String>[];
    final calendar = source(requested);
    final events = await calendar.fetch(2026);
    calendar.close();
    expect(requested, ['2025', '2026']);
    expect(events, hasLength(116));
    final winter = events.singleWhere((e) => e.sourceId == '6238');
    expect(winter.title, '겨울계절학기');
    expect(winter.start, DateTime(2026, 1, 1));
    expect(winter.end, DateTime(2026, 1, 14));
    expect(
      winter.url,
      'https://www.sookmyung.ac.kr/kr/university-life/academic-calendar.do?mode=list&selectedYear=2026',
    );
    final crossing = events.singleWhere((e) => e.sourceId == '6112');
    expect(crossing.start, DateTime(2026, 12, 22));
    expect(crossing.end, DateTime(2027, 1, 14));
  });

  test('December periods from the previous response reach January', () async {
    final requested = <String>[];
    final calendar = source(requested);
    final events = await calendar.fetch(2027);
    calendar.close();
    expect(requested, ['2026', '2027']);
    final januaryRows =
        (((jsonDecode(fixture(2027)) as Map)['data'] as List).first as List)
            .cast<Map>()
            .where(
              (row) => !SookmyungAcademicSource.isCombinedDegreeApplication(
                row['content'] as String,
              ),
            );
    // Two 2026 December periods end in January 2027.
    expect(events, hasLength(januaryRows.length + 2));
    expect(
      events.map((e) => e.sourceId),
      containsAll(['6112', '6265', '6114']),
    );
  });

  test('Sookmyung profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000141',
      'academyinfo:0000141',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '숙명여자대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'sookmyung',
      );
    }
  });

  test('Sookmyung rejects unpublished, wrong-year and malformed data', () {
    final body = fixture(2026);
    expect(
      () => SookmyungAcademicSource.parse(
        body.replaceFirst('"hasData":true', '"hasData":false'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SookmyungAcademicSource.parse(body, 2025),
      throwsFormatException,
    );
    expect(
      () => SookmyungAcademicSource.parse('{"data":[]}', 2026),
      throwsFormatException,
    );
    expect(
      () => SookmyungAcademicSource.parse(
        body.replaceFirst(
          '"beginDatetime":1767193200000',
          '"beginDatetime":"x"',
        ),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SookmyungAcademicSource.parse(
        body.replaceFirst('"content":"겨울계절학기"', '"content":" "'),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('Sookmyung fails on an unavailable response', () async {
    final calendar = SookmyungAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(calendar.close);
    await expectLater(calendar.fetch(2026), throwsFormatException);
  });
}
