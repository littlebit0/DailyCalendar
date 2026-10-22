import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/ewha_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/ewha-$year.html').readAsStringSync();

EwhaAcademicSource source(List<String> requested) => EwhaAcademicSource(
  client: MockClient((r) async {
    expect(r.url.path, '/ewha/bachelor/calendar2026.do');
    expect(r.url.queryParameters['mode'], 'user_list');
    final year = r.url.queryParameters['year']!;
    requested.add(year);
    return http.Response.bytes(
      File('test/fixtures/academic/ewha-$year.html').readAsBytesSync(),
      200,
      headers: {'content-type': 'text/html;charset=utf-8'},
    );
  }),
);

void main() {
  test('EWHA official annual native date ranges', () {
    final rows = EwhaAcademicSource.parse(fixture(2026), 2026);
    expect(rows.length, greaterThan(40));
    expect(
      rows.any((e) => e.title == '2학기 종강' && e.start == DateTime(2026, 12, 21)),
      true,
    );
    expect(
      rows.any(
        (e) =>
            e.title == '2학기 교과목 수강철회' &&
            e.start == DateTime(2026, 9, 28) &&
            e.end == DateTime(2026, 10, 3),
      ),
      isTrue,
    );
    expect(
      rows.any(
        (e) => e.title == '2027학년도 입학식' && e.start == DateTime(2027, 2, 26),
      ),
      isTrue,
    );
  });

  test('every published EWHA row is imported for each page', () {
    for (final year in [2024, 2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.b-cal-list-box li')
          .length;
      expect(rows, greaterThan(50));
      expect(EwhaAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });

  test(
    'EWHA calendar year merges January from the previous academic year',
    () async {
      for (final (year, count) in [(2025, 54), (2026, 52)]) {
        final requested = <String>[];
        final ewha = source(requested);
        final events = await ewha.fetch(year);
        ewha.close();
        expect(requested, ['${year - 1}', '$year']);
        expect(events, hasLength(count));
        expect(
          events.every(
            (e) =>
                e.start.isBefore(DateTime(year + 1)) &&
                e.end.isAfter(DateTime(year)),
          ),
          isTrue,
        );
      }
      final requested = <String>[];
      final ewha = source(requested);
      final events = await ewha.fetch(2025);
      ewha.close();
      // Published only on the 2024 page.
      expect(
        events.any(
          (e) =>
              e.title == '설날 연휴 (공휴일)' &&
              e.start == DateTime(2025, 1, 28) &&
              e.end == DateTime(2025, 1, 31),
        ),
        isTrue,
      );
    },
  );

  test('EWHA keeps the previous start/last/title source IDs', () {
    final rows = EwhaAcademicSource.parse(fixture(2026), 2026);
    final end = rows.firstWhere((e) => e.title == '2학기 종강');
    expect(end.sourceId, '2026-12-21/2026-12-21/2학기 종강');
    expect(
      end.url,
      'https://www.ewha.ac.kr/ewha/bachelor/calendar2026.do?mode=user_list&year=2026',
    );
  });

  test('EWHA rejects a page whose year banner is not the requested year', () {
    final body = fixture(2026);
    expect(EwhaAcademicSource.parse(body, 2026), isNotEmpty);
    expect(
      () => EwhaAcademicSource.parse(body, 2025),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EwhaAcademicSource.parse(
        body.replaceAll('<span>2026</span>', ''),
        2026,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EwhaAcademicSource.parse(
        body.replaceFirst(
          '<span>2026</span>',
          '<span>2026</span><span>2027</span>',
        ),
        2026,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'EWHA rejects malformed dates, empty pages and failed responses',
    () async {
      expect(
        () => EwhaAcademicSource.parse(
          fixture(2026).replaceFirst('16(금)', '32(금)'),
          2026,
        ),
        throwsFormatException,
      );
      // Same shape as the published but not yet filled 2027 page.
      final empty = fixture(
        2026,
      ).replaceAll(RegExp(r'<p>\s*(?:\d{4}년\s*)?\d{1,2}월\s*</p>'), '');
      expect(
        () => EwhaAcademicSource.parse(empty, 2026),
        throwsFormatException,
      );
      final failing = EwhaAcademicSource(
        client: MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(failing.fetch(2026), throwsFormatException);
      failing.close();
    },
  );

  test('EWHA profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000163',
      'academyinfo:0000163',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '이화여자대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'ewha',
      );
    }
  });
}
