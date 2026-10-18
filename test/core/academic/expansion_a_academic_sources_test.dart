import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/expansion_a_academic_sources.dart';

void main() {
  const folder = 'test/fixtures/expansion_a';
  test('INJE complete public 2026 annual calendar', () {
    final rows = InjeAcademicSource.parse(
      File('$folder/inje-cal.html').readAsStringSync(),
      2026,
    );
    expect(rows.length, greaterThan(40));
    expect(
      rows.any(
        (e) => e.title == '동계방학 시작일' && e.start == DateTime(2026, 12, 22),
      ),
      true,
    );
  });
  test('Hongik public JSON excludes month-only imprecise notices', () {
    final rows = HongikAcademicSource.parse(
      File('$folder/hongik-cal.json').readAsStringSync(),
      2026,
    );
    expect(rows.length, greaterThan(40));
    expect(
      rows.any(
        (e) => e.title == '2026학년도 2학기 종강' && e.start == DateTime(2026, 12, 14),
      ),
      true,
    );
  });
  test('WSU undergraduate column, native dates and duplicate overlap', () {
    final rows = WoosongAcademicSource.parse(
      File('$folder/wsu-cal.html').readAsStringSync(),
      2026,
    );
    expect(rows.length, greaterThan(80));
    expect(
      rows.any(
        (e) => e.title == '2학기 종강일' && e.start == DateTime(2026, 12, 14),
      ),
      true,
    );
    expect(rows.any((e) => e.title.contains('학위청구논문')), false);
  });
  test('WSU January row keeps its previous-year December start', () {
    final rows = WoosongAcademicSource.parse(
      File('$folder/wsu-cal.html').readAsStringSync(),
      2026,
    );
    final grading = rows.where((e) => e.title.contains('성적정정 및 이의신청'));
    expect(
      grading.any(
        (e) =>
            e.start == DateTime(2025, 12, 29) && e.end == DateTime(2026, 1, 3),
      ),
      isTrue,
    );
    expect(grading.any((e) => e.start == DateTime(2026, 12, 29)), isFalse);
  });
  test('EWHA official annual native date ranges', () {
    final rows = EwhaAcademicSource.parse(
      File('$folder/ewha-cal.html').readAsStringSync(),
      2026,
    );
    expect(rows.length, greaterThan(40));
    expect(
      rows.any((e) => e.title == '2학기 종강' && e.start == DateTime(2026, 12, 21)),
      true,
    );
  });
  test('ICCU Songdo date ranges and source year', () {
    final rows = IccuAcademicSource.parse(
      File('$folder/iccu-cal.html').readAsStringSync(),
      2026,
    );
    expect(rows.length, greaterThan(50));
    expect(
      rows.any(
        (e) => e.title == '[송도국제] 종강' && e.start == DateTime(2026, 12, 22),
      ),
      true,
    );
  });
  test('ICCU Ganghwa distinct campus date ranges', () {
    final rows = IccuAcademicSource.parseGanghwa(
      File('$folder/iccu-shin-cal.html').readAsStringSync(),
      2026,
    );
    expect(rows.length, greaterThan(80));
    expect(
      rows.any(
        (e) => e.title == '[강화] 동계방학' && e.start == DateTime(2026, 12, 12),
      ),
      true,
    );
  });
  test('Eulji all twelve native public months and semester end', () {
    final rows = [
      for (var month = 1; month <= 12; month++)
        ...EuljiAcademicSource.parse(
          File(
            '$folder/eulji-cal-${month.toString().padLeft(2, '0')}.html',
          ).readAsStringSync(),
          2026,
          month,
        ),
    ];
    expect(rows.length, greaterThan(50));
    expect(
      rows.any(
        (e) =>
            e.start == DateTime(2026, 12, 15) &&
            e.end == DateTime(2026, 12, 22) &&
            e.title.contains('보강'),
      ),
      true,
    );
  });
  test(
    'Eulji full fetch deduplicates native events across adjacent months',
    () async {
      final months = <int>[];
      final source = EuljiAcademicSource(
        client: MockClient((request) async {
          final month = int.parse(request.url.queryParameters['month']!);
          months.add(month);
          expect(request.url.queryParameters['year'], '2026');
          expect(request.url.queryParameters['calendar_no'], '105');
          expect(request.headers['User-Agent'], 'Mozilla/5.0');
          return http.Response(
            File(
              '$folder/eulji-cal-${(month + 1).toString().padLeft(2, '0')}.html',
            ).readAsStringSync(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final rows = await source.fetch(2026);
      source.close();
      expect(months, List.generate(12, (index) => index));
      expect(rows.map((e) => e.sourceId).toSet().length, rows.length);
      expect(rows.where((e) => e.title == '을지축전').length, 1);
    },
  );
  test(
    'Eulji unrelated client failure propagates without alternate transport',
    () async {
      var calls = 0;
      final source = EuljiAcademicSource(
        client: MockClient((request) async {
          calls++;
          throw http.ClientException('unrelated network failure');
        }),
      );
      await expectLater(
        source.fetch(2026),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 1);
      source.close();
    },
  );
}
