import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/sunmoon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/sunmoon-$year.html').readAsStringSync();

void main() {
  test(
    'Sunmoon calendar year joins both March-February academic years',
    () async {
      final requested = <Map<String, String>>[];
      final source = SunmoonAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/communication/sv/schdulView/calendar.do');
          final form = Uri.splitQueryString(r.body);
          requested.add(form);
          return http.Response(
            fixture(int.parse(form['year']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested.map((f) => f['year']), ['2025', '2026']);
      expect(requested.map((f) => f['monthEnmt']), ['20260228', '20270228']);
      expect(events, hasLength(75));
      expect(
        events.every(
          (e) =>
              e.start.isBefore(DateTime(2027)) && e.end.isAfter(DateTime(2026)),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2026-1학기 수강신청' &&
              e.start == DateTime(2026, 2, 5) &&
              e.end == DateTime(2026, 2, 10),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '개강일, 학기개시일, 입학일' && e.start == DateTime(2026, 9, 1),
        ),
        isTrue,
      );
    },
  );

  test('every published Sunmoon row is imported for each academic year', () {
    // The page repeats each month as a responsive `#schedule_month` table with
    // "null" labels, then as the official `#schedule_year` table.
    for (final (year, published) in [(2025, 68), (2026, 79)]) {
      final tables = html
          .parse(fixture(year))
          .querySelectorAll('#schedule_year table')
          .where((t) => t.querySelector('caption')!.text.contains('내용'))
          .toList();
      expect(tables, hasLength(12));
      final rows = [
        for (final table in tables)
          for (final row in table.querySelectorAll('tbody tr'))
            (
              row.querySelector('td')!.text.trim().substring(0, 5),
              row.querySelector('li')!.text.trim(),
            ),
      ];
      expect(rows, hasLength(published));
      final events = SunmoonAcademicSource.parse(fixture(year), year);
      // Rows repeated under two months, or listed twice, are one event.
      expect(events, hasLength(rows.toSet().length));
      expect(events.every((e) => e.title != 'null'), isTrue);
    }
  });

  test('January and February belong to the following calendar year', () {
    final events = SunmoonAcademicSource.parse(fixture(2026), 2026);
    expect(
      events.any(
        (e) =>
            e.title == '2027-1학기 수강신청' &&
            e.start == DateTime(2027, 2, 11) &&
            e.end == DateTime(2027, 2, 16),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title == '중간고사' &&
            e.start == DateTime(2026, 10, 20) &&
            e.end == DateTime(2026, 10, 27),
      ),
      isTrue,
    );
  });

  test('Sunmoon profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000129',
      'academyinfo:0000129',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '선문대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'sunmoon',
      );
    }
  });

  test('Sunmoon rejects incorrect year and malformed published date', () {
    expect(
      () => SunmoonAcademicSource.parse(fixture(2026), 2027),
      throwsFormatException,
    );
    expect(
      () => SunmoonAcademicSource.parse(
        // The first occurrence is the ignored mirror; the official row too.
        fixture(2026).replaceAll('03-27', '02-30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SunmoonAcademicSource.parse(
        fixture(2026).replaceAll('2026년 3월 학사일정을', '2026년 학사일정을'),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('Sunmoon month missing from the official calendar is an error', () {
    // The `#schedule_month` mirror still lists April, but it must not stand in
    // for the official `#schedule_year` table.
    final page = fixture(2026);
    final split = page.indexOf('<div id="schedule_year">');
    expect(split, greaterThan(0));
    final withoutApril =
        page.substring(0, split) +
        page
            .substring(split)
            .replaceFirst('2026년 4월 학사일정을 일자와 내용으로', '2026년 4월 학사일정 목록');
    expect(withoutApril, isNot(page));
    expect(
      () => SunmoonAcademicSource.parse(withoutApril, 2026),
      throwsFormatException,
    );
    expect(
      () => SunmoonAcademicSource.parse(
        page.replaceFirst('id="schedule_year"', 'id="schedule_other"'),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('Sunmoon failed response is an error', () async {
    final source = SunmoonAcademicSource(
      client: MockClient((_) async => http.Response('', 500)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
