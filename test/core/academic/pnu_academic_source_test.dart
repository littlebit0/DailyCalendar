import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/pnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, String term) =>
    File('test/fixtures/academic/pnu-$year-$term.html').readAsStringSync();

/// Sign-in page carrying only the public request parameters the popup uses.
String signInPage(BigInt modulus) =>
    "var RSAModulus = '${modulus.toRadixString(16)}';\n"
    "var RSAExponent = '10001';\n"
    'scwin.token = "f24f34bd-d92a-424c-9a47-d898045158c9";';

/// Fetches [year] through a mock of the public sign-in page and popup.
Future<(List<AcademicEvent>, List<String>)> fetchFixtures(int year) async {
  // Fixed 2048-bit odd modulus; the mock server never decrypts requests.
  final modulus = (BigInt.one << 2047) + BigInt.from(12345);
  final terms = [
    (year - 1, '0020'),
    (year, '0010'),
    (year, '0020'),
    (year + 1, '0010'),
  ];
  final requested = <String>[];
  final source = PnuAcademicSource(
    client: MockClient((r) async {
      if (r.method == 'GET') {
        expect(r.url.toString(), 'https://onestop.pusan.ac.kr/login');
        return http.Response(signInPage(modulus), 200);
      }
      expect(r.headers['X-CSRF-TOKEN'], 'f24f34bd-d92a-424c-9a47-d898045158c9');
      if (r.url.path == '/global/info') {
        return http.Response(
          jsonEncode({
            '_Menu': [
              {'MENU_CD': '000000000000000', 'AUTH_STR': 'public'},
            ],
          }),
          200,
        );
      }
      expect(r.url.path, '/core/main/selectScheduleListPop.do');
      final (y, term) = terms[requested.length];
      requested.add('$y-$term');
      return http.Response.bytes(utf8.encode(fixture(y, term)), 200);
    }),
  );
  final events = await source.fetch(year);
  source.close();
  return (events, requested);
}

void main() {
  test('PNU fetch keeps every published row dated in the year', () async {
    // Distinct rows overlapping each year across the four fetched lists.
    for (final (year, count) in [(2025, 158), (2026, 167)]) {
      final (events, requested) = await fetchFixtures(year);
      expect(requested, [
        '${year - 1}-0020',
        '$year-0010',
        '$year-0020',
        '${year + 1}-0010',
      ]);
      expect(events, hasLength(count));
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    }
  });

  test('PNU keeps winter periods and next-term windows across years', () async {
    final (events, _) = await fetchFixtures(2026);
    expect(
      events.any(
        (e) =>
            e.title == '겨울계절수업 강의시작종료일' &&
            e.start == DateTime(2025, 12, 22) &&
            e.end == DateTime(2026, 1, 20),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title == '겨울계절수업 강의시작종료일' &&
            e.start == DateTime(2026, 12, 24) &&
            e.end == DateTime(2027, 1, 22),
      ),
      isTrue,
    );
    // Published in the 2027 first-term list but held during autumn 2026.
    expect(
      events.where(
        (e) => e.title == '겨울계절 및 도약수업 복학신청기간' && e.start.year == 2026,
      ),
      hasLength(4),
    );
  });

  test('every published PNU row is imported for each term', () {
    for (final (year, term) in [
      (2024, '0020'),
      (2025, '0010'),
      (2025, '0020'),
      (2026, '0010'),
      (2026, '0020'),
      (2027, '0010'),
    ]) {
      final document = html.parse(fixture(year, term));
      final rows = document.querySelectorAll('#resultTbody > tr').length;
      expect(int.parse(document.querySelector('.text-total')!.text), rows);
      expect(
        PnuAcademicSource.parse(fixture(year, term), year, term),
        hasLength(rows),
      );
    }
  });

  test('PNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000014',
      'academyinfo:0000014',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '부산대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'pnu',
      );
    }
  });

  test('PNU accepts an unpublished term only when asked to', () {
    final empty = fixture(2027, '0020');
    expect(
      () => PnuAcademicSource.parse(empty, 2027, '0020'),
      throwsFormatException,
    );
    expect(
      PnuAcademicSource.parse(empty, 2027, '0020', allowEmpty: true),
      isEmpty,
    );
  });

  test('PNU rejects mismatched selected year or term and incomplete table', () {
    final body = fixture(2026, '0020');
    expect(
      () => PnuAcademicSource.parse(body, 2025, '0020'),
      throwsFormatException,
    );
    expect(
      () => PnuAcademicSource.parse(body, 2026, '0010'),
      throwsFormatException,
    );
    expect(
      () => PnuAcademicSource.parse(
        body.replaceFirst('id="resultTbody"', 'id="missing"'),
        2026,
        '0020',
      ),
      throwsFormatException,
    );
  });

  test('PNU rejects invalid calendar dates instead of rolling them over', () {
    final body = fixture(2026, '0020');
    expect(body, contains('2026-04-24'));
    expect(
      () => PnuAcademicSource.parse(
        body.replaceFirst('2026-04-24', '2026-02-30'),
        2026,
        '0020',
      ),
      throwsFormatException,
    );
  });
}
