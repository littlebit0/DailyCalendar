import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/inje_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/inje-$year.html').readAsStringSync();

void main() {
  test('INJE complete public 2026 annual calendar', () async {
    final source = InjeAcademicSource(
      client: MockClient((request) async {
        expect(request.url.host, 'www.inje.ac.kr');
        expect(request.url.queryParameters, {
          'pCode': 'IF010010000',
          'viewType': 'vy',
          'setYear': '2026',
          'setMonth': '1',
        });
        return http.Response.bytes(
          File('test/fixtures/academic/inje-2026.html').readAsBytesSync(),
          200,
        );
      }),
    );
    final rows = await source.fetch(2026);
    source.close();
    expect(rows.length, greaterThan(40));
    expect(
      rows.any(
        (e) => e.title == '동계방학 시작일' && e.start == DateTime(2026, 12, 22),
      ),
      true,
    );
    expect(
      rows.any(
        (e) =>
            e.title == '2026-1복학신청' &&
            e.start == DateTime(2026, 2, 2) &&
            e.end == DateTime(2026, 2, 28) &&
            e.sourceId == '2026-02-02/2026-02-27/2026-1복학신청',
      ),
      isTrue,
    );
  });

  test('every published INJE row is imported for each year', () {
    // 2025 repeats two rows verbatim (중간고사 기간, 학기개시 90일).
    for (final (year, published, distinct) in [
      (2025, 53, 51),
      (2026, 55, 55),
    ]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.eventList li')
          .map(
            (row) =>
                '${row.querySelector('.dateTxt')!.text}|'
                '${row.querySelector('.titleTxt')!.text.trim()}',
          )
          .toList();
      expect(rows, hasLength(published));
      expect(rows.toSet(), hasLength(distinct));
      expect(
        InjeAcademicSource.parse(fixture(year), year),
        hasLength(distinct),
      );
    }
  });

  test('INJE profile resolves to its registered calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000164', null),
      ('institution:academyinfo:0000164', 'academyinfo:0000164'),
      ('institution:academyinfo:0000164', 'academyinfo:0000166'),
      ('academyinfo:0000164', null),
      ('academyinfo:0000166', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '인제대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        'inje',
      );
    }
  });

  test('INJE rejects incorrect year and malformed published date', () {
    expect(
      () => InjeAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => InjeAcademicSource.parse(
        fixture(2026).replaceFirst('01. 01.', '02. 30.'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => InjeAcademicSource.parse(
        fixture(2026).replaceAll(RegExp(r'<li>[\s\S]*?</li>'), ''),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('INJE unavailable response is an error', () async {
    final source = InjeAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });

  group('INJE month cards', () {
    final body = fixture(2026);
    final card = RegExp(
      r'<div class="monthCard">(?:(?!<div class="monthCard">)[\s\S])*?class="monthNum">4월[\s\S]*?</ul>\s*</div>\s*</div>',
    );

    test('an empty month card is kept and accepted', () {
      final match = card.firstMatch(body)!;
      final emptied = match
          .group(0)!
          .replaceAll(RegExp(r'<li>[\s\S]*?</li>'), '');
      final rows = InjeAcademicSource.parse(
        body.replaceFirst(match.group(0)!, emptied),
        2026,
      );
      final original = InjeAcademicSource.parse(body, 2026);
      expect(rows.length, lessThan(original.length));
      expect(rows.any((row) => row.start.month == 4), isFalse);
    });

    test('a missing month card is rejected as damaged', () {
      final match = card.firstMatch(body)!;
      expect(
        () => InjeAcademicSource.parse(
          body.replaceFirst(match.group(0)!, ''),
          2026,
        ),
        throwsFormatException,
      );
    });

    test('a repeated month card is rejected', () {
      final match = card.firstMatch(body)!;
      expect(
        () => InjeAcademicSource.parse(
          body.replaceFirst(match.group(0)!, match.group(0)! * 2),
          2026,
        ),
        throwsFormatException,
      );
    });
  });
}
