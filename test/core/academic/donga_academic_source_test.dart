import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:daily/core/academic/donga_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    File('test/fixtures/academic/donga-$name.html').readAsStringSync();

void main() {
  test(
    'full fetch retains cross-year events and deduplicates overlapping feeds',
    () async {
      final source = DongaAcademicSource(
        client: MockClient((request) async {
          final uri = request.url;
          String body;
          if (uri.path.endsWith('Contents.do')) {
            body = fixture('2026');
          } else if (uri.path.endsWith('YearList.do')) {
            body = fixture('${uri.queryParameters['calendar_year']}-legacy');
          } else if (uri.path.endsWith('Detail.do')) {
            final key =
                '${uri.queryParameters['year']}-${uri.queryParameters['month']}-${uri.queryParameters['day']}';
            body = fixture(switch (key) {
              '2025-12-20' => '2025-winter-detail',
              '2025-12-27' => '2025-dec27-detail',
              '2026-1-5' => '2026-jan5-detail',
              '2026-2-23' => '2026-feb23-detail',
              _ => throw StateError('Unexpected detail $key'),
            });
          } else if (uri.queryParameters['mode'] == 'list') {
            final keyword = uri.queryParameters['searchKeyword']!;
            body = fixture(
              keyword.startsWith('2025')
                  ? '2025-winter-search'
                  : keyword.contains('하계')
                  ? '2026-summer-search'
                  : '2026-winter-search',
            );
          } else {
            body = fixture(
              uri.queryParameters['board_seq'] == '8411190'
                  ? '2025-winter-notice'
                  : '2026-summer-notice',
            );
          }
          return http.Response(
            body,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      try {
        final events = await source.fetch(2026);
        expect(events, hasLength(56));
        expect(events.map((e) => e.sourceId).toSet(), hasLength(56));
        expect(events.where((e) => e.title.contains('동계계절학기')), hasLength(1));
        expect(
          events.every(
            (e) =>
                e.start.isBefore(DateTime(2027)) &&
                e.end.isAfter(DateTime(2026)),
          ),
          isTrue,
        );
      } finally {
        source.close();
      }
    },
  );

  test(
    'annual semesters, milestones and rowspan makeup dates are preserved',
    () {
      final events = DongaAcademicSource.parseAnnual(fixture('2026'), 2026);
      expect(events, hasLength(53));
      expect(events.where((e) => e.title.contains('지정보강일')), hasLength(8));
      final chuseok = events.where((e) => e.title == '추석').toList();
      expect(
        chuseok.map((e) => e.start),
        containsAll([DateTime(2026, 9, 24), DateTime(2026, 9, 25)]),
      );
      expect(events.where((e) => e.title.contains('학기 개시일')), hasLength(2));
      expect(
        () => DongaAcademicSource.parseAnnual(fixture('2026'), 2025),
        throwsFormatException,
      );
    },
  );

  test(
    'cross-year legacy winter matches independently published full dates',
    () {
      final legacy = DongaAcademicSource.parseLegacy(
        fixture('2025-legacy'),
        2025,
      );
      expect(legacy, hasLength(23));
      expect(
        DongaAcademicSource.parseLegacy(fixture('2026-legacy'), 2026),
        hasLength(2),
      );
      final detail = DongaAcademicSource.parseDetail(
        fixture('2025-winter-detail'),
        'https://www.donga.ac.kr/',
      );
      final winter = detail.singleWhere((e) => e.title.contains('동계방학'));
      expect(winter.start, DateTime(2025, 12, 20));
      expect(winter.end, DateTime(2026, 3, 1));
      expect(legacy.where((e) => e.sourceId == winter.sourceId), hasLength(1));
      expect(
        () => DongaAcademicSource.parseDetail(
          fixture('2025-winter-detail').replaceFirst('2026.02', '2026.13'),
          'https://www.donga.ac.kr/',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'actual course periods selected; demand survey is not a course period',
    () {
      for (final (year, winter, season, start, end) in [
        (2025, true, 'winter', DateTime(2025, 12, 22), DateTime(2026, 1, 14)),
        (2026, false, 'summer', DateTime(2026, 6, 22), DateTime(2026, 7, 11)),
      ]) {
        final url = DongaAcademicSource.selectSeasonalNotice(
          fixture('$year-$season-search'),
          year,
          winter,
        )!;
        final event = DongaAcademicSource.parseSeasonal(
          fixture('$year-$season-notice'),
          year,
          winter,
          url.toString(),
        );
        expect(event.start, start);
        expect(event.end, end);
      }
      expect(
        DongaAcademicSource.selectSeasonalNotice(
          fixture('2026-winter-search'),
          2026,
          true,
        ),
        isNull,
      );
      expect(
        () => DongaAcademicSource.parseSeasonal(
          fixture('2026-summer-notice'),
          2025,
          false,
          'https://www.donga.ac.kr/',
        ),
        throwsFormatException,
      );
    },
  );
}
