import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kwangwoon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/kwangwoon-$year.html').readAsStringSync();

void main() {
  test(
    'Kwangwoon annual view includes preceding winter once and exact current periods',
    () async {
      final years = <int>[];
      final source = KwangwoonAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.host, 'www.kw.ac.kr');
          expect(request.url.path, '/KWBoard/list5_detail.jsp');
          expect(request.bodyFields['sm'], '');
          final year = int.parse(request.bodyFields['sy']!);
          years.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(years, [2025, 2026]);
      // 57 rows published for 2026 plus the winter session that began in 2025.
      expect(events, hasLength(58));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.where((e) => e.title == '동계 계절수업'), hasLength(2));
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절수업' &&
              e.start == DateTime(2025, 12, 22) &&
              e.end == DateTime(2026, 1, 15),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절수업' &&
              e.start == DateTime(2026, 12, 22) &&
              e.end == DateTime(2027, 1, 15),
        ),
        isTrue,
      );
      expect(
        events.singleWhere((e) => e.title == '하계 계절수업').end,
        DateTime(2026, 7, 14),
      );
      expect(
        events.singleWhere((e) => e.title == '2026학년도 2학기 개강(학기개시일)').start,
        DateTime(2026, 9, 1),
      );
    },
  );
  test('every published Kwangwoon annual row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.schedule-this-year .month_box .list li')
          .length;
      expect(rows, year == 2025 ? 54 : 57);
      expect(
        KwangwoonAcademicSource.parse(fixture(year), year),
        hasLength(rows),
      );
    }
  });
  test('Kwangwoon profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000074',
      'academyinfo:0000074',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '광운대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'kwangwoon',
      );
    }
  });
  test(
    'Kwangwoon rejects unexpected years, invalid dates and duplicate rows',
    () {
      final body = fixture(2026);
      expect(
        () => KwangwoonAcademicSource.parse(body, 2025),
        throwsFormatException,
      );
      expect(
        () => KwangwoonAcademicSource.parse(
          body.replaceFirst('02.02(월)', '02.32(월)'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => KwangwoonAcademicSource.parse(
          body.replaceFirst('<span>03</span>', '<span>02</span>'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
}
