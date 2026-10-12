import 'dart:io';
import 'package:daily/core/academic/kumoh_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/academic/kumoh-$name.html').readAsStringSync();
void main() {
  test(
    'Kumoh validates all498 articles before year filtering and keeps both winter periods',
    () async {
      final requests = <http.Request>[];
      final source = KumohAcademicSource(
        client: MockClient((request) async {
          requests.add(request);
          expect(
            request.headers['User-Agent'],
            'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          );
          if (requests.length == 2) {
            expect(request.url.queryParameters, {
              'mode': 'list',
              'articleLimit': '498',
              'article.offset': '0',
            });
          }
          return http.Response(
            fixture(requests.length == 1 ? 'index' : 'all'),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requests, hasLength(2));
      expect(events, hasLength(92));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(92));
      expect(
        events.any(
          (e) =>
              e.title == '겨울 계절 수업' &&
              e.start == DateTime(2025, 12, 23) &&
              e.end == DateTime(2026, 1, 15),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '겨울 계절수업' &&
              e.start == DateTime(2026, 12, 23) &&
              e.end == DateTime(2027, 1, 15),
        ),
        isTrue,
      );
    },
  );
  test(
    'Kumoh rejects truncated population and invalid dates instead of importing partial results',
    () async {
      final source = KumohAcademicSource(
        client: MockClient(
          (r) async => http.Response(
            fixture('index'),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          ),
        ),
      );
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
      expect(
        () => KumohAcademicSource.parse(
          fixture('all').replaceFirst('2027-02-26', '2027-02-30'),
        ),
        throwsFormatException,
      );
    },
  );
}
