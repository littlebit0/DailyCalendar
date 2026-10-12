import 'dart:io';
import 'package:daily/core/academic/inha_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/inha-2026.html').readAsStringSync();

void main() {
  test(
    'INHA annual view places the two winters in their actual years',
    () async {
      final source = InhaAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/schdulmanage/kr/5/yearSchdul.do');
          expect(request.bodyFields['year'], '2026');
          expect(request.bodyFields['kind'], '');
          return http.Response(
            fixture(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(
        events.singleWhere((e) => e.title == '2025학년도 동계 계절학기 수업').start,
        DateTime(2025, 12, 22),
      );
      expect(
        events.singleWhere((e) => e.title == '2025학년도 동계 계절학기 수업').end,
        DateTime(2026, 1, 15),
      );
      expect(
        events.singleWhere((e) => e.title == '2026학년도 동계 계절학기 수업').end,
        DateTime(2027, 1, 14),
      );
      expect(
        events.singleWhere((e) => e.title == '2026학년도 하계 계절학기 수업').end,
        DateTime(2026, 7, 16),
      );
      expect(events.every((e) => e.end.isAfter(DateTime(2026))), isTrue);
    },
  );

  test(
    'INHA rejects unavailable year, missing preceding December and malformed range',
    () {
      final body = fixture();
      expect(() => InhaAcademicSource.parse(body, 2025), throwsFormatException);
      expect(
        () => InhaAcademicSource.parse(
          body.replaceFirst('월 (2025년)', '월 (2024년)'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => InhaAcademicSource.parse(
          body.replaceFirst('12.08.(월)', '12.32.(월)'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => InhaAcademicSource.parse(
          body.replaceFirst('01.06.(화)', '01.04.(화)'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
}
