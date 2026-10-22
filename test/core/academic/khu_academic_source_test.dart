import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/khu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/academic/$name.html').readAsStringSync();

/// Published rows in the official four-column annual table.
int annualRows(String body) => html
    .parse(body)
    .querySelectorAll('.month')
    .expand(
      (block) => block.parent!.parent!.children
          .where((e) => e.localName == 'td')
          .elementAt(2)
          .querySelectorAll('li'),
    )
    .where((e) => e.text.trim().isNotEmpty)
    .length;

void main() {
  final url = Uri.parse('https://haksa.khu.ac.kr/');
  test(
    'KHU discovers published year links and preserves both winter terms and July revision',
    () async {
      final requested = <String>[];
      final source = KhuAcademicSource(
        client: MockClient((request) async {
          final menu = request.url.queryParameters['menuNo']!;
          requested.add(menu);
          final name = switch (menu) {
            '21200042' => 'khu-2026',
            '11600128' => 'khu-cls-index',
            '11600124' => 'khu-cls-2025-index',
            '11600125' => 'khu-2025-2',
            _ => throw StateError('Unexpected official year link'),
          };
          return http.Response(
            fixture(name),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['21200042', '11600128', '11600124', '11600125']);
      expect(events, hasLength(84));
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절학기 수업' &&
              e.start == DateTime(2025, 12, 22) &&
              e.end == DateTime(2026, 1, 14),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2학기 성적 공시 및 정정' &&
              e.start == DateTime(2025, 12, 30) &&
              e.end == DateTime(2026, 1, 3),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2학기 수강희망과목담기' &&
              e.start == DateTime(2026, 7, 13) &&
              e.end == DateTime(2026, 7, 17),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절학기 수업' &&
              e.start == DateTime(2026, 12, 22) &&
              e.end == DateTime(2027, 1, 14),
        ),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    },
  );
  test('every published KHU row is imported', () {
    final annual = fixture('khu-2026');
    expect(annualRows(annual), 82);
    expect(KhuAcademicSource.parseAnnual(annual, 2026, url), hasLength(82));
    final semester = fixture('khu-2025-2');
    final semesterRows = html
        .parse(semester)
        .querySelectorAll('table.tbl_standard_type1 td.text_left')
        .length;
    expect(semesterRows, 40);
    expect(
      KhuAcademicSource.parseSecondSemester(semester, 2025, url),
      hasLength(semesterRows),
    );
  });
  test('KHU official 2025 annual page is rejected for its year typo', () {
    // The official page prints 12.30.(화) - 2025.1.2.(금); the row is not
    // silently corrected or dropped.
    final annual = fixture('khu-2025');
    expect(annual, contains('2025.1.2.(금)'));
    expect(
      () => KhuAcademicSource.parseAnnual(annual, 2025, url),
      throwsFormatException,
    );
    // Every other published row parses once only that typo is replaced.
    expect(
      KhuAcademicSource.parseAnnual(
        annual.replaceFirst('2025.1.2.(금)', '2026.1.2.(금)'),
        2025,
        url,
      ),
      hasLength(annualRows(annual)),
    );
  });
  test('KHU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000066',
      'academyinfo:0000066',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경희대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'khu',
      );
    }
  });
  test('KHU rejects source year typo, invalid dates and incomplete months', () {
    expect(
      () => KhuAcademicSource.parseSecondSemester(
        fixture('khu-2025-2').replaceFirst('2026. 1. 2.', '2025. 1. 2.'),
        2025,
        url,
      ),
      throwsFormatException,
    );
    expect(
      () => KhuAcademicSource.parseAnnual(
        fixture('khu-2026').replaceFirst('class="month"', 'class="missing"'),
        2026,
        url,
      ),
      throwsFormatException,
    );
    expect(
      () => KhuAcademicSource.parseAnnual(fixture('khu-2026'), 2025, url),
      throwsFormatException,
    );
  });
}
