import 'dart:io';
import 'package:html/parser.dart' as html;
import 'package:daily/core/academic/geochang_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/academic/$name').readAsStringSync();
void main() {
  test(
    'current annual year plus published January and actual previous winter',
    () async {
      final requests = <http.Request>[];
      final source = GeochangAcademicSource(
        client: MockClient((request) async {
          requests.add(request);
          final url = request.url;
          String body;
          if (url.path == '/CW0301/101014.asp') {
            body = fixture('geochang-2026.html');
          } else if (url.path == '/') {
            body = fixture('geochang-home-links.html');
          } else if (url.path == '/2026A.asp') {
            body = fixture('geochang-2026-${url.queryParameters['hday']}.html');
          } else if (request.method == 'POST') {
            expect(Uri.splitQueryString(request.body), {
              'select1': 'title',
              's_text': '계절',
            });
            body = fixture('geochang-winter-search.html');
          } else {
            expect(url.queryParameters['bno'], '2421');
            body = fixture('geochang-2025-winter.html');
          }
          return http.Response(
            body,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      expect(events, hasLength(53));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final winter = events.singleWhere((e) => e.title == '2025학년도 동계 계절학기');
      expect(winter.start, DateTime(2025, 12, 15));
      expect(winter.end, DateTime(2026, 1, 10));
      expect(
        events.any(
          (e) =>
              e.title.contains('제29회 학위수여식') && e.start == DateTime(2026, 2, 6),
        ),
        isTrue,
      );
      final currentWinter = events.singleWhere((e) => e.title == '동계 계절학기');
      expect(currentWinter.start, DateTime(2026, 12, 23));
      expect(currentWinter.end, DateTime(2027, 1, 15));
      expect(requests.length, 6);
    },
  );
  test(
    'published-year and exact link guards fail instead of copying prior dates',
    () {
      expect(
        () => GeochangAcademicSource.parseAnnual(
          fixture('geochang-2026.html'),
          2027,
          '',
        ),
        throwsFormatException,
      );
      expect(
        () => GeochangAcademicSource.selectHomeMonths(
          fixture('geochang-home-links.html'),
          2027,
        ),
        throwsFormatException,
      );
      expect(
        () => GeochangAcademicSource.parsePreviousWinter(
          fixture('geochang-2025-winter.html'),
          2024,
          '',
        ),
        throwsFormatException,
      );
      expect(
        () => GeochangAcademicSource.selectPreviousWinter(
          '<a href="https://example.com/?bno=2421">2025학년도 동계 계절학기 개설 안내</a>',
          2025,
        ),
        throwsFormatException,
      );
      expect(
        () => GeochangAcademicSource.parseHomeMonth(
          '<div class="result-content"><p>02.30</p><p>오류</p></div>',
          2026,
          2,
          '',
        ),
        throwsFormatException,
      );
      // A list that never passes its month may have cut off later events.
      expect(
        () => GeochangAcademicSource.parseHomeMonth(
          '<div class="result-content"><p>02.06</p><p>학위수여식</p></div>',
          2026,
          2,
          '',
        ),
        throwsFormatException,
      );
    },
  );
  test('every published Geochang annual and homepage row is imported', () {
    final annual = html
        .parse(fixture('geochang-2026.html'))
        .querySelectorAll('table.tbl_st tbody td > span')
        .where((e) => RegExp(r'^\d{2}-\d{2}').hasMatch(e.text.trim()))
        .length;
    expect(annual, 53);
    expect(
      GeochangAcademicSource.parseAnnual(
        fixture('geochang-2026.html'),
        2026,
        '',
      ),
      hasLength(annual),
    );
    for (final (month, rows) in [(1, 6), (2, 5)]) {
      final listed = html
          .parse(fixture('geochang-2026-0$month.html'))
          .querySelectorAll('div.result-content')
          .where(
            (e) =>
                int.parse(e.querySelector('p')!.text.trim().substring(0, 2)) <=
                2,
          )
          .length;
      expect(listed, rows);
      expect(
        GeochangAcademicSource.parseHomeMonth(
          fixture('geochang-2026-0$month.html'),
          2026,
          month,
          '',
        ),
        hasLength(listed),
      );
    }
  });
}
