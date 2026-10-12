import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kwangwoon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.where((e) => e.title == '동계 계절수업'), hasLength(2));
      expect(
        events.singleWhere((e) => e.title == '하계 계절수업').end,
        DateTime(2026, 7, 14),
      );
      expect(
        events.singleWhere((e) => e.title == '2026학년도 2학기 개강(학기개시일)').start,
        DateTime(2026, 9, 1),
      );
      expect(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000074',
          universityName: '광운대학교',
          schoolKind: '4년제',
        ).academicSourceId,
        'kwangwoon',
      );
    },
  );
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
