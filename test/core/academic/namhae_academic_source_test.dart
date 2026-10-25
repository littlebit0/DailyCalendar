import 'dart:io';
import 'package:html/parser.dart' as html;
import 'package:daily/core/academic/namhae_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/namhae-2026.html').readAsStringSync();
void main() {
  test(
    'published year preserves separate holidays and exact cross-year ranges',
    () async {
      final all = NamhaeAcademicSource.parseAnnual(fixture(), 2026, 'official');
      expect(all, hasLength(44));
      expect(
        all.singleWhere((e) => e.title == '삼일절').start,
        DateTime(2026, 3, 1),
      );
      expect(
        all.singleWhere((e) => e.title == '대체휴일').start,
        DateTime(2026, 3, 2),
      );
      final winter = all.singleWhere((e) => e.title == '동계 계절학기');
      expect(winter.start, DateTime(2026, 12, 23));
      expect(winter.end, DateTime(2027, 1, 15));
      expect(
        all.singleWhere((e) => e.title == '동계 방학').end,
        DateTime(2027, 3, 1),
      );
      final source = NamhaeAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters, {'proFn': 'namhae1_3'});
          return http.Response(
            fixture(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final current = await source.fetch(2026);
      expect(current.any((e) => e.start.month < 3), isFalse);
      expect(
        current
            .singleWhere((e) => e.title == '성적 이의신청' && e.start.month == 12)
            .end,
        DateTime(2027, 1, 1),
      );
      source.close();
    },
  );
  test(
    'calendar-year queries preserve the published next winter only',
    () async {
      final source = NamhaeAcademicSource(
        client: MockClient(
          (_) async => http.Response(
            fixture(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        ),
      );
      addTearDown(source.close);
      final next = await source.fetch(2027);
      expect(next, hasLength(8));
      expect(next.any((e) => e.title == '동계 계절학기'), isTrue);
      expect(
        next.every(
          (e) =>
              e.end.isAfter(DateTime(2027)) && e.start.isBefore(DateTime(2028)),
        ),
        isTrue,
      );
      expect(next.every((e) => e.start.isBefore(DateTime(2027, 3))), isTrue);
      await expectLater(source.fetch(2028), throwsFormatException);
      await expectLater(source.fetch(2025), throwsFormatException);
    },
  );
  test(
    'predecessor-college identity is not substituted for the university',
    () async {
      final source = NamhaeAcademicSource(
        client: MockClient(
          (_) async => http.Response(
            fixture().replaceAll('국립창원대학교 남해캠퍼스', '경남도립남해대학'),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        ),
      );
      addTearDown(source.close);
      await expectLater(source.fetch(2026), throwsFormatException);
    },
  );
  test(
    'university footer cannot authenticate a predecessor calendar heading',
    () async {
      final source = NamhaeAcademicSource(
        client: MockClient(
          (_) async => http.Response(
            "${fixture().replaceAll('국립창원대학교 남해캠퍼스', '경남도립남해대학')}<footer>국립창원대학교 남해캠퍼스</footer>",
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        ),
      );
      addTearDown(source.close);
      await expectLater(source.fetch(2026), throwsFormatException);
    },
  );
  test(
    'unpublished year, invalid dates, ranges and month rowspans fail closed',
    () {
      for (final body in [
        fixture().replaceFirst('2026년 3월', '2025년 3월'),
        fixture().replaceFirst('rowspan="5"', 'rowspan="4"'),
        fixture().replaceFirst('2026년 4월', '2026년 5월'),
        fixture().replaceFirst('3. 3.(화)', '3. 32.(화)'),
        fixture().replaceFirst('3. 9.(월)', '3. 1.(일)'),
        fixture().replaceFirst('삼일절 / 대체휴일', '삼일절'),
        fixture().replaceFirst('2027. 1. 14.(목)', '1. 14.(목)'),
        fixture().replaceFirst('2027년 2월', '2027년 3월'),
      ]) {
        expect(
          () => NamhaeAcademicSource.parseAnnual(body, 2026, ''),
          throwsFormatException,
        );
      }
      expect(
        () => NamhaeAcademicSource.parseAnnual(fixture(), 2027, ''),
        throwsFormatException,
      );
    },
  );
  test('every published Namhae row and date is imported', () {
    final rows = html
        .parse(fixture())
        .querySelectorAll('table.tb_3 tbody > tr')
        .map((row) => row.querySelectorAll('td'))
        .toList();
    expect(rows, hasLength(43));
    // A row may list several dates with matching "/"-separated titles.
    final dates = rows
        .map((cells) => cells[cells.length - 2].text.split('/').length)
        .reduce((a, b) => a + b);
    expect(dates, 44);
    expect(
      NamhaeAcademicSource.parseAnnual(fixture(), 2026, ''),
      hasLength(dates),
    );
  });
}
