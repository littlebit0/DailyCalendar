import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/kyonggi_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/kyonggi-$year.html').readAsStringSync();
void main() {
  test(
    'Kyonggi university-wide source retains both full winter ranges',
    () async {
      final source = KyonggiAcademicSource(
        client: MockClient((r) async {
          expect(r.url.queryParameters, {
            'key': '5819',
            'sc1': '10',
            'sc3': '2026',
          });
          return http.Response(
            fixture(2026),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(88));
      for (final dates in [
        (DateTime(2025, 12, 18), DateTime(2026, 1, 10)),
        (DateTime(2026, 12, 21), DateTime(2027, 1, 13)),
      ]) {
        expect(
          events.any(
            (e) =>
                e.title == '[학사]동계 계절수업' &&
                e.start == dates.$1 &&
                e.end == dates.$2,
          ),
          isTrue,
        );
      }
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    },
  );
  test('every published Kyonggi row in the year is imported', () {
    // Rows spanning two months are listed under both; count each once.
    for (final (year, count) in [(2025, 81), (2026, 88)]) {
      final rows = <String>{};
      for (final row
          in html
              .parse(fixture(year))
              .querySelectorAll('.schedule_content .info_box__item')) {
        final date = row.querySelector('.info_box__date')!.text.trim();
        final years = RegExp(
          r'(\d{4})\.',
        ).allMatches(date).map((m) => int.parse(m[1]!));
        if (years.first <= year && years.last >= year) {
          rows.add(
            '$date|${row.querySelector('.info_box__text')!.text.trim()}',
          );
        }
      }
      expect(rows, hasLength(count));
      expect(
        KyonggiAcademicSource.parse(fixture(year), year),
        hasLength(count),
      );
    }
  });
  test('Kyonggi profiles on both campuses resolve to one calendar', () {
    for (final (id, campus) in [
      ('institution:academyinfo:0000056', null),
      ('institution:academyinfo:0000056', 'academyinfo:0000056'),
      ('institution:academyinfo:0000056', 'academyinfo:0000058'),
      ('academyinfo:0000056', null),
      ('academyinfo:0000058', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경기대학교',
          schoolKind: 'fourYear',
          campusId: campus,
        ).academicSourceId,
        'kyonggi',
      );
    }
  });
  test('Kyonggi rejects truncated annual data and invalid dates', () {
    expect(
      () => KyonggiAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => KyonggiAcademicSource.parse(
        fixture(2026).replaceFirst('id="sc_con_202601"', 'id="missing"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => KyonggiAcademicSource.parse(
        fixture(2026).replaceFirst('2026.01.01(목)', '2026.01.32(목)'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
