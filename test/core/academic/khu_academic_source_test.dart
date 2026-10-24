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
  KhuAcademicSource source(Map<String, String> pages, List<String> requested) =>
      KhuAcademicSource(
        client: MockClient((request) async {
          final menu = request.url.queryParameters['menuNo']!;
          requested.add(menu);
          final body = pages[menu];
          if (body == null) throw StateError('Unexpected official year link');
          return http.Response(
            body,
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
  test('KHU 2026 reads only the official 2026 annual page', () async {
    final requested = <String>[];
    final khu = source({'21200042': fixture('khu-2026')}, requested);
    final events = await khu.fetch(2026);
    khu.close();
    expect(requested, ['21200042']);
    // 2026 rows of the 2026 annual page; 2025 academic-year rows are not read.
    expect(events, hasLength(70));
    expect(events.every((e) => !e.start.isBefore(DateTime(2026, 3))), isTrue);
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
  });
  test('KHU 2025 is rejected as unsupported without any request', () async {
    final requested = <String>[];
    final khu = source({'21200042': fixture('khu-2026')}, requested);
    await expectLater(khu.fetch(2025), throwsFormatException);
    khu.close();
    expect(requested, isEmpty);
  });
  test('KHU 2027 keeps January and February of the 2026 annual page', () async {
    // The index gains a 2027 link once published; the 2027 page here is the
    // 2026 page shifted by one year.
    final index = fixture(
      'khu-2026',
    ).replaceFirst('menuNo=21200043" >2024학년도', 'menuNo=21200044" >2027학년도');
    final next = index.replaceAll('2027', '2028').replaceAll('2026', '2027');
    final requested = <String>[];
    final khu = source({'21200042': index, '21200044': next}, requested);
    final events = await khu.fetch(2027);
    khu.close();
    expect(requested, ['21200042', '21200044']);
    final carried = events
        .where((e) => e.url.endsWith('menuNo=21200042'))
        .toList();
    // Every 2026 annual row reaching into 2027 is kept, and only those.
    expect(
      carried.map((e) => e.sourceId).toSet(),
      KhuAcademicSource.parseAnnual(index, 2026, url)
          .where((e) => e.end.isAfter(DateTime(2027)))
          .map((e) => e.sourceId)
          .toSet(),
    );
    expect(carried, isNotEmpty);
    expect(
      carried.any(
        (e) =>
            e.title == '동계 계절학기 수업' &&
            e.start == DateTime(2026, 12, 22) &&
            e.end == DateTime(2027, 1, 14),
      ),
      isTrue,
    );
    expect(carried.any((e) => e.title == '2027학년도 1학기 등록'), isTrue);
    expect(
      events.any(
        (e) => e.title == '동계 계절학기 수업' && e.start == DateTime(2027, 12, 22),
      ),
      isTrue,
    );
    expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
  });
  test('every published KHU row is imported', () {
    final annual = fixture('khu-2026');
    expect(annualRows(annual), 82);
    expect(KhuAcademicSource.parseAnnual(annual, 2026, url), hasLength(82));
  });
  test('KHU official 2025 annual page is rejected for its year typo', () {
    // The official page prints 12.30.(화) - 2025.1.2.(금); the row is not
    // silently corrected or dropped, which is why fetch starts at 2026.
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
  test('KHU rejects invalid months and a mismatched academic year', () {
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
