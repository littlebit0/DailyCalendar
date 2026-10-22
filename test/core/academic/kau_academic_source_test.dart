import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kau_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/kau-2026.html').readAsStringSync();

KauAcademicSource source() => KauAcademicSource(
  client: MockClient((request) async {
    expect(request.url.path, '/kaulife/schedule.php');
    return http.Response(
      fixture(),
      200,
      headers: {'content-type': 'text/html;charset=utf-8'},
    );
  }),
);

void main() {
  test('KAU uses updated website dates and abbreviated range ends', () async {
    final kau = source();
    final events = await kau.fetch(2026);
    kau.close();
    expect(events, hasLength(45));
    expect(
      events.singleWhere((e) => e.title == '하계 계절학기 종강').start,
      DateTime(2026, 7, 20),
    );
    expect(
      events.singleWhere((e) => e.title == '1학기 보강').end,
      DateTime(2026, 6, 24),
    );
    expect(
      events.singleWhere((e) => e.title == '동계 계절학기 종강').start,
      DateTime(2026, 1, 13),
    );
    expect(
      events.singleWhere((e) => e.title == '수강신청 변경' && e.start.month == 3).end,
      DateTime(2026, 3, 10),
    );
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
  });
  test('every published KAU row is imported once across its years', () {
    final rows = html
        .parse(fixture())
        .querySelectorAll('#sub_article table.table_02 tbody > tr')
        .length;
    final y2026 = KauAcademicSource.parse(fixture(), 2026);
    final y2027 = KauAcademicSource.parse(fixture(), 2027);
    expect(rows, 56);
    expect(y2026.length + y2027.length, rows);
  });
  test(
    'next January and February rows reach the next year with the same IDs',
    () async {
      final kau = source();
      final events = await kau.fetch(2027);
      kau.close();
      expect(events, hasLength(11));
      expect(events.every((e) => e.start.year == 2027), isTrue);
      final closing = events.singleWhere((e) => e.title == '동계 계절학기 종강');
      expect(closing.start, DateTime(2027, 1, 18));
      expect(closing.sourceId, '2027-01-18T00:00:00.000:동계 계절학기 종강');
      expect(
        KauAcademicSource.parse(
          fixture(),
          2026,
        ).any((e) => e.start.year == 2027),
        isFalse,
      );
    },
  );
  test('KAU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000194',
      'academyinfo:0000194',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한국항공대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'kau',
      );
    }
  });
  test('KAU rejects unpublished year and invalid dates', () {
    expect(
      () => KauAcademicSource.parse(fixture(), 2025),
      throwsFormatException,
    );
    expect(
      () => KauAcademicSource.parse(
        fixture().replaceFirst('2026. 1. 1', '2026. 2. 30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KauAcademicSource.parse(
        fixture().replaceFirst('2학기 학사일정', '학사일정'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test('KAU failed response is an error', () async {
    final kau = KauAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(kau.fetch(2026), throwsFormatException);
    kau.close();
  });
}
