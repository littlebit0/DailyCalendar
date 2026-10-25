import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/cnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String school, int year) =>
    File('test/fixtures/academic/$school-$year.html').readAsStringSync();
void main() {
  test(
    'CNU preceding December and year crossing winter remain complete',
    () async {
      final source = CnuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.host, 'plus.cnu.ac.kr');
          return http.Response(
            fixture('cnu', int.parse(request.url.queryParameters['year']!)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(69));
      expect(
        events.any(
          (e) =>
              e.title == '동기 계절학기' &&
              e.start == DateTime(2025, 12, 22) &&
              e.end == DateTime(2026, 1, 14),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '동기 계절학기' &&
              e.start == DateTime(2026, 12, 21) &&
              e.end == DateTime(2027, 1, 13),
        ),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('every published CNU row is imported for each year', () {
    for (final (year, published, repeated) in [(2025, 70, 0), (2026, 70, 1)]) {
      final rows = [
        for (final (i, box)
            in html
                .parse(fixture('cnu', year))
                .querySelectorAll('.calen_box')
                .indexed)
          for (final row in box.querySelectorAll('.fr_list > ul > li'))
            '$i:${row.text.trim()}',
      ];
      expect(rows, hasLength(published));
      // The 2026 page repeats one identical row (03.03~03.09 수강신청 확인 및 변경).
      expect(rows.toSet(), hasLength(published - repeated));
      expect(
        CnuAcademicSource.parse(fixture('cnu', year), year),
        hasLength(published - repeated),
      );
    }
  });
  test('CNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000029',
      'academyinfo:0000029',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '충남대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'cnu',
      );
    }
  });
  test('CNU rejects missing month and impossible date', () {
    expect(
      () => CnuAcademicSource.parse(
        fixture(
          'cnu',
          2026,
        ).replaceFirst('class="calen_box"', 'class="missing"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => CnuAcademicSource.parse(
        fixture('cnu', 2026).replaceFirst('01.01(목)', '02.30(목)'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => CnuAcademicSource.parse(fixture('cnu', 2026), 2025),
      throwsFormatException,
    );
  });
}
