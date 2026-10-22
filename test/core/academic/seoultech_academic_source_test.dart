import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/seoultech_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int semester) => File(
  'test/fixtures/academic/seoultech-$year-$semester.html',
).readAsStringSync();

// University finance office records the adapter leaves out on purpose.
bool financeRow(String title) =>
    RegExp(r'^\d{4}회계연도').hasMatch(title) &&
    RegExp(r'재정위원회|예산|대학회계').hasMatch(title);

void main() {
  test('Seoultech fetch keeps the 2026 year across both semesters', () async {
    final requested = <String>[];
    final source = SeoultechAcademicSource(
      client: MockClient((r) async {
        expect(r.url.path, '/bachelor/bachelor');
        final year = int.parse(r.url.queryParameters['year']!);
        final typ = int.parse(r.url.queryParameters['typ']!);
        requested.add('$year-$typ');
        return http.Response.bytes(
          File(
            'test/fixtures/academic/seoultech-$year-${typ - 1}.html',
          ).readAsBytesSync(),
          200,
          headers: {'content-type': 'text/html;charset=UTF-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(requested, ['2025-3', '2026-2', '2026-3']);
    expect(events, hasLength(66));
    expect(events.every((e) => e.end.isAfter(DateTime(2026))), isTrue);
    expect(events.every((e) => e.start.isBefore(DateTime(2027))), isTrue);
    expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
    expect(
      events.any(
        (e) =>
            e.title == '2025학년도 동계 계절학기[미래융합대학:겨울학기](일정별도공고)' &&
            e.start == DateTime(2025, 12, 22) &&
            e.end == DateTime(2026, 2, 19),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title == '2027학년도 1학기 타 대학교 학점교류 신청(일정 별도 공고)' &&
            e.start == DateTime(2026, 12, 8) &&
            e.end == DateTime(2027, 2, 27),
      ),
      isTrue,
    );
  });

  test('every published Seoultech academic row is imported', () {
    for (final (year, semester) in [
      (2025, 1),
      (2025, 2),
      (2026, 1),
      (2026, 2),
    ]) {
      final titles = html
          .parse(fixture(year, semester))
          .querySelectorAll('.wrap_plugin_schedule table.schedule tbody tr')
          .map((row) {
            final cell = row.querySelector('.al')!;
            for (final link in cell.querySelectorAll('.link')) {
              link.remove();
            }
            return cell.text.trim();
          })
          .toList();
      final events = SeoultechAcademicSource.parse(
        fixture(year, semester),
        year,
        semester,
      );
      expect(
        events.map((e) => e.title),
        titles.where((t) => !financeRow(t)),
        reason: '$year-$semester',
      );
    }
  });

  test('Seoultech excludes finance office records and never repairs dates', () {
    final previous = fixture(2025, 2);
    expect(previous, contains('2026.01.29 ~ 01.19'));
    final events = SeoultechAcademicSource.parse(previous, 2025, 2);
    expect(events.any((e) => e.title.contains('회계연도')), isFalse);
    expect(
      () => SeoultechAcademicSource.parse(
        previous.replaceFirst('2026회계연도 본예산 재정위원회 제출', '2026학년도 수강신청'),
        2025,
        2,
      ),
      throwsFormatException,
    );
    expect(
      () => SeoultechAcademicSource.parse(fixture(2026, 1), 2025, 1),
      throwsFormatException,
    );
    expect(
      () => SeoultechAcademicSource.parse(fixture(2026, 1), 2026, 2),
      throwsFormatException,
    );
    expect(
      () => SeoultechAcademicSource.parse(
        fixture(
          2026,
          1,
        ).replaceFirst('2026.03.27 ~ 03.27', '2026.02.30 ~ 03.27'),
        2026,
        1,
      ),
      throwsFormatException,
    );
  });

  test('Seoultech profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000036',
      'academyinfo:0000036',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '서울과학기술대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'seoultech',
      );
    }
  });
}
