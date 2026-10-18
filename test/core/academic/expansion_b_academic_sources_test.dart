import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:daily/core/academic/expansion_b_academic_sources.dart';

String fixture(String name) =>
    File('test/fixtures/academic/$name').readAsStringSync();

void main() {
  test('KENTECH native dates retain year and exclude graduate records', () {
    final events = KentechAcademicSource.parse(
      fixture('kentech-2026.json'),
      2026,
    );
    expect(events.length, greaterThan(30));
    expect(
      events.every(
        (e) =>
            e.start.isBefore(DateTime(2027)) && e.end.isAfter(DateTime(2026)),
      ),
      isTrue,
    );
    expect(events.any((e) => e.title.contains('대학원')), isFalse);
    expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
  });

  test(
    'Hansei annual list includes all months and date-only inclusive ranges',
    () {
      final events = HanseiAcademicSource.parse(
        fixture('hansei-2026.html'),
        2026,
      );
      expect(events.length, greaterThan(30));
      expect(events.map((e) => e.start.month).toSet().length, 12);
      expect(events.every((e) => e.start.hour == 0 && e.end.hour == 0), isTrue);
      expect(
        () => HanseiAcademicSource.parse(fixture('hansei-2026.html'), 2027),
        throwsFormatException,
      );
    },
  );

  test('Hansei rows follow their month section across year boundaries', () {
    final events = HanseiAcademicSource.parse(
      fixture('hansei-2026.html'),
      2026,
    );
    DateTime? endOf(String title, DateTime start) => events
        .where((e) => e.title == title && e.start == start)
        .map((e) => e.end)
        .firstOrNull;
    // Listed under January: starts the previous December.
    expect(endOf('2학기 성적 정정', DateTime(2025, 12, 29)), DateTime(2026, 1, 3));
    expect(endOf('동계 계절학기 수업', DateTime(2025, 12, 22)), DateTime(2026, 1, 14));
    // Listed under December: ends in the next January.
    expect(endOf('동계 계절학기 수업', DateTime(2026, 12, 22)), DateTime(2027, 1, 14));
    // Rows inside one year are unchanged.
    expect(endOf('1학기 복학 신청(2차)', DateTime(2026, 1, 26)), DateTime(2026, 2, 7));
  });

  test('K2Web academic schedules use verified institution-specific years', () {
    final hyupsung = HyupsungAcademicSource();
    final sungkyul = SungkyulAcademicSource();
    addTearDown(hyupsung.close);
    addTearDown(sungkyul.close);
    final uhs = hyupsung.parse(fixture('hyupsung-2026.html'), 2026);
    final sky = sungkyul.parse(fixture('sungkyul-2026.html'), 2026);
    expect(uhs.length, greaterThan(30));
    expect(sky.length, greaterThan(30));
    expect(
      uhs.any(
        (e) => e.title.contains('2학기개강') && e.start == DateTime(2026, 9, 1),
      ),
      isTrue,
    );
    expect(
      sky.any(
        (e) => e.title.contains('개강(정상수업)') && e.start == DateTime(2026, 8, 31),
      ),
      isTrue,
    );
    expect(
      () => hyupsung.parse(fixture('hyupsung-2026.html'), 2027),
      throwsFormatException,
    );
  });

  test('Sunmoon March-February response retains next-year Jan/Feb dates', () {
    final current = SunmoonAcademicSource.parse(
      fixture('sunmoon-2026.html'),
      2026,
    );
    final prior = SunmoonAcademicSource.parse(
      fixture('sunmoon-2025.html'),
      2025,
    );
    expect(
      current.any((e) => e.start.year == 2027 && e.start.month < 3),
      isTrue,
    );
    expect(prior.any((e) => e.start.year == 2026 && e.start.month < 3), isTrue);
    expect(current.every((event) => event.title != 'null'), isTrue);
    expect(
      current.any(
        (event) =>
            event.title == '개강일, 학기개시일, 입학일' &&
            event.start == DateTime(2026, 9, 1),
      ),
      isTrue,
    );
    expect(
      () => SunmoonAcademicSource.parse(fixture('sunmoon-2026.html'), 2027),
      throwsFormatException,
    );
  });

  test(
    'Sangji empty end dates are one-day events and year is calendar filtered',
    () {
      final events = SangjiAcademicSource.parse(
        fixture('sangji-2026.json'),
        2026,
      );
      final start = events.singleWhere((e) => e.title == '2학기 개강');
      expect(start.start, DateTime(2026, 8, 31));
      expect(start.end, DateTime(2026, 9, 1));
      final prior = SangjiAcademicSource.parse(
        fixture('sangji-2025.json'),
        2026,
      );
      expect(prior.any((e) => e.start.month < 3), isTrue);
    },
  );

  group('Sangji previous-year response without overlap', () {
    String month(int id, String start, String end) =>
        '[{"month":"12","year":"2025","list":[{"code":"A","siteCode":"kor",'
        '"subject":"지난 학년도 일정","cntNo":$id,"endde":"$end 00:00:00.0",'
        '"bgnde":"$start 00:00:00.0"}]}]';
    SangjiAcademicSource source(String previous, String current) =>
        SangjiAcademicSource(
          client: MockClient((r) async {
            if (r.method == 'GET') {
              return http.Response(
                'calendar',
                200,
                headers: {'set-cookie': 'JSESSIONID=fixture; Path=/'},
              );
            }
            final year = Uri.splitQueryString(r.body)['searchKeywordFrom'];
            return http.Response(
              year == '2025' ? previous : current,
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

    test(
      'does not stop the refresh before the requested year is read',
      () async {
        final previous = source(
          month(1, '2025-12-01', '2025-12-31'),
          fixture('sangji-2026.json'),
        );
        addTearDown(previous.close);
        final events = await previous.fetch(2026);
        expect(events, isNotEmpty);
        expect(events.every((e) => e.end.isAfter(DateTime(2026))), isTrue);
      },
    );

    test(
      'fails when only the previous response reaches the requested year',
      () async {
        // January 2026 sits in the 2025 academic-year response, but the 2026
        // response itself is stale and does not overlap 2026.
        final stale = source(
          month(1, '2026-01-05', '2026-01-10'),
          month(2, '2025-11-01', '2025-11-30'),
        );
        addTearDown(stale.close);
        await expectLater(stale.fetch(2026), throwsFormatException);
        final empty = source(month(1, '2026-01-05', '2026-01-10'), '[]');
        addTearDown(empty.close);
        await expectLater(empty.fetch(2026), throwsFormatException);
      },
    );

    test(
      'still fails when neither response reaches the requested year',
      () async {
        final empty = source(
          month(1, '2025-12-01', '2025-12-31'),
          month(2, '2025-11-01', '2025-11-30'),
        );
        addTearDown(empty.close);
        await expectLater(empty.fetch(2026), throwsFormatException);
      },
    );
  });

  test(
    'Sangji fetch reads both academic years with a sequential session',
    () async {
      final years = <String>[];
      final source = SangjiAcademicSource(
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(
              'calendar',
              200,
              headers: {'set-cookie': 'JSESSIONID=fixture; Path=/'},
            );
          }
          expect(r.headers['Cookie'], 'JSESSIONID=fixture');
          final year = Uri.splitQueryString(r.body)['searchKeywordFrom']!;
          years.add(year);
          return http.Response(
            fixture('sangji-$year.json'),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(years, ['2025', '2026']);
      expect(events.any((e) => e.start.month < 3), isTrue);
      expect(
        events.every(
          (e) =>
              e.start.isBefore(DateTime(2027)) && e.end.isAfter(DateTime(2026)),
        ),
        isTrue,
      );
    },
  );

  test('Invalid upstream dates are rejected, never normalized', () {
    final native = jsonDecode(fixture('kentech-2026.json')) as List;
    final row = Map<String, dynamic>.from(
      native.firstWhere(
        (r) => r['SCH_TYPE'] == 'R0205' && r['DEPT_CD'] == 'MAIN',
      ),
    );
    row['START_DAY'] = '2026-02-30';
    expect(
      () => KentechAcademicSource.parse(jsonEncode([row]), 2026),
      throwsFormatException,
    );
  });
}
