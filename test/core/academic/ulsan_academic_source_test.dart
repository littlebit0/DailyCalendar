import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/ulsan_academic_source.dart';
import 'package:html/parser.dart' as html;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(int year) =>
      File('test/fixtures/academic/ulsan-$year.html').readAsStringSync();
  test(
    'Ulsan retains previous December winter terms and excludes commented examples',
    () async {
      final years = <int>[];
      final source = UlsanAcademicSource(
        client: MockClient((request) async {
          final year = int.parse(request.url.queryParameters['calendar_year']!);
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
      expect(events.length, 59);
      final winter = events.singleWhere((e) => e.title == '2026학년도 겨울계절수업');
      expect(winter.start, DateTime(2026, 12, 22));
      expect(winter.end, DateTime(2027, 1, 14));
      expect(events.any((e) => e.start == DateTime(2025, 12, 22)), isTrue);
      expect(events.any((e) => e.title.contains('반환 기준 5/6선')), isFalse);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('every published Ulsan row is imported for each year', () {
    // The 2025 page publishes only September to December; 2026 covers all months.
    for (final (year, published) in [(2025, 16), (2026, 57)]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.sch-monlist-wr .daily-li')
          .where((row) => !row.classes.contains('no-data'))
          .length;
      expect(rows, published);
      expect(UlsanAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });
  test('Ulsan validates a winter leap day in its ending year', () async {
    String winterPage(int year) {
      final document = html.parse(fixture(2026).replaceAll('2026', '$year'));
      final winter = document
          .querySelectorAll('.daily-li')
          .singleWhere(
            (row) =>
                row.querySelector('.body-core')?.text.trim() ==
                '$year학년도 겨울계절수업',
          );
      winter.querySelector('.date-core')!.text = '12. 22(수)∼02. 29(화)';
      return document.outerHtml;
    }

    final page = winterPage(2027);
    final winter = UlsanAcademicSource.parse(
      page,
      2027,
    ).singleWhere((event) => event.title == '2027학년도 겨울계절수업');
    expect(winter.start, DateTime(2027, 12, 22));
    expect(winter.end, DateTime(2028, 3, 1));

    final source = UlsanAcademicSource(
      client: MockClient((request) async {
        final year = int.parse(request.url.queryParameters['calendar_year']!);
        return http.Response(
          year == 2027 ? page : fixture(2026).replaceAll('2026', '$year'),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    addTearDown(source.close);
    final events = await source.fetch(2028);
    expect(
      events.singleWhere((event) => event.sourceId == winter.sourceId).end,
      DateTime(2028, 3, 1),
    );
    expect(
      () => UlsanAcademicSource.parse(winterPage(2026), 2026),
      throwsFormatException,
    );
  });
  test('Ulsan profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000158',
      'academyinfo:0000158',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '울산대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'ulsan',
      );
    }
  });
  test('Ulsan refuses stale year, invalid day and missing month', () {
    final body = fixture(2026);
    expect(() => UlsanAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => UlsanAcademicSource.parse(
        body.replaceFirst('01. 05(월)', '01. 32(월)'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => UlsanAcademicSource.parse(
        body.replaceFirst('2026년 1월 학사일정', '2026년 2월 학사일정'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
