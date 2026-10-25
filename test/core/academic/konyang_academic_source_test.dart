import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/konyang_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/konyang-$year.html').readAsStringSync();
void main() {
  test(
    'Konyang reads both academic years that overlap the calendar year',
    () async {
      final requested = <String>[];
      final source = KonyangAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/prog/schedule/kor/sub06_01_01_01/3/haksa.do');
          final rdate = r.url.queryParameters['rdate']!;
          requested.add(rdate);
          return http.Response.bytes(
            File(
              'test/fixtures/academic/konyang-${rdate.substring(0, 4)}.html',
            ).readAsBytesSync(),
            200,
            headers: {'content-type': 'text/html;charset=UTF-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['2025-03-01', '2026-03-01']);
      // 2025학년도 1·2월 5행과 연도를 걸친 동계 계절학기 1행, 2026학년도 3~12월 44행.
      expect(events, hasLength(50));
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절학기' &&
              e.start == DateTime(2025, 12, 15) &&
              e.end == DateTime(2026, 1, 7),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '동계 계절학기' &&
              e.start == DateTime(2026, 12, 14) &&
              e.end == DateTime(2027, 1, 6),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '2025학년도 전기 학위수여식' &&
              e.start == DateTime(2026, 2, 12) &&
              e.end == DateTime(2026, 2, 13),
        ),
        isTrue,
      );
      expect(
        events.every((e) => e.start.year == 2026 || e.end.year == 2026),
        isTrue,
      );
    },
  );
  test('every published Konyang row is imported for each academic year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelector('.schedule_table_web table')!
          .querySelectorAll('tbody tr')
          .length;
      final events = KonyangAcademicSource.parse(fixture(year), year);
      expect(rows, year == 2025 ? 44 : 49);
      expect(events, hasLength(rows));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(rows));
    }
  });
  test('Konyang academic year rolls into January and February', () {
    final events = KonyangAcademicSource.parse(fixture(2026), 2026);
    expect(
      events.any(
        (e) =>
            e.title == '2027학년도 1학기 등록기간' &&
            e.start == DateTime(2027, 2, 22) &&
            e.end == DateTime(2027, 2, 27),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title == '하계 계절학기' &&
            e.start == DateTime(2026, 6, 22) &&
            e.end == DateTime(2026, 7, 11),
      ),
      isTrue,
    );
  });
  test('Konyang profile resolves to its registered calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000054', null),
      ('institution:academyinfo:0000054', 'academyinfo:0000054'),
      ('institution:academyinfo:0000054', 'academyinfo:0000055'),
      ('academyinfo:0000054', null),
      ('academyinfo:0000055', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '건양대학교',
          campusId: campusId,
          schoolKind: 'fourYear',
        ).academicSourceId,
        'konyang',
      );
    }
  });
  test('Konyang rejects incorrect year, malformed date and empty page', () {
    expect(
      () => KonyangAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => KonyangAcademicSource.parse(
        fixture(2026).replaceFirst('<td>02</td>', '<td>32</td>'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KonyangAcademicSource.parse(
        fixture(2026).replaceFirst('>3월</th>', '>3월 일정</th>'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KonyangAcademicSource.parse('<html></html>', 2026),
      throwsFormatException,
    );
  });
  test('Konyang reports an unavailable page as an error', () async {
    final source = KonyangAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
