import 'dart:io';
import 'package:daily/core/academic/pknu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/pknu-$year-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();
String annual() =>
    File('test/fixtures/academic/pknu-stat-2026.html').readAsStringSync();
void main() {
  test(
    'PKNU uses zero-padded months, preceding winter and independently verified end',
    () async {
      var annualRequests = 0;
      final queries = <String>[];
      final source = PknuAcademicSource(
        client: MockClient((r) async {
          if (r.url.host == 'stat.pknu.ac.kr') {
            annualRequests++;
            return http.Response(
              annual(),
              200,
              headers: {'content-type': 'text/html;charset=utf-8'},
            );
          }
          final q = Uri.splitQueryString(r.body);
          expect(q['month'], matches(r'^\d{2}$'));
          queries.add('${q['year']}-${q['month']}');
          return http.Response(
            fixture(int.parse(q['year']!), int.parse(q['month']!)),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(queries, [
        '2025-12',
        for (var m = 1; m <= 12; m++) '2026-${m.toString().padLeft(2, '0')}',
      ]);
      expect(annualRequests, 1);
      expect(events, hasLength(66));
      final winters = events.where((e) => e.title == '동계 계절수업').toList();
      expect(winters, hasLength(2));
      expect(winters.first.start, DateTime(2025, 12, 22));
      expect(winters.first.end, DateTime(2026, 1, 14));
      expect(winters.last.start, DateTime(2026, 12, 21));
      expect(winters.last.end, DateTime(2027, 1, 13));
      expect(winters.last.url, 'https://stat.pknu.ac.kr/stat/281');
    },
  );
  test(
    'PKNU never guesses invalid years from stale or mismatched independent source',
    () {
      final body = fixture(2026, 12);
      expect(
        () => PknuAcademicSource.parse(body, 2026, 12),
        throwsFormatException,
      );
      expect(
        () => PknuAcademicSource.parse(
          body,
          2026,
          12,
          verifiedAnnual: annual().replaceAll('2026.12.21', '2025.12.21'),
        ),
        throwsFormatException,
      );
      expect(
        () => PknuAcademicSource.parse(
          body,
          2026,
          12,
          verifiedAnnual: '<html>unavailable</html>',
        ),
        throwsFormatException,
      );
    },
  );
}
