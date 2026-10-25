import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/mokpo_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int semester) => File(
  'test/fixtures/academic/mokpo-$year-$semester.html',
).readAsStringSync();

void main() {
  test(
    'Mokpo profile resolves to its registered calendar on both campuses',
    () {
      for (final (universityId, campusId) in [
        ('institution:academyinfo:0000011', null),
        ('institution:academyinfo:0000011', 'academyinfo:0000011'),
        ('institution:academyinfo:0000011', 'academyinfo:0003312'),
        ('academyinfo:0000011', null),
        ('academyinfo:0003312', null),
      ]) {
        expect(
          AcademicProfile(
            universityId: universityId,
            universityName: '국립목포대학교',
            schoolKind: 'fourYear',
            campusId: campusId,
          ).academicSourceId,
          'mokpo',
        );
      }
    },
  );
  test('every published Mokpo row is imported for each semester', () {
    for (final (year, semester) in [
      (2024, 2),
      (2025, 1),
      (2025, 2),
      (2026, 1),
      (2026, 2),
    ]) {
      final body = fixture(year, semester);
      // Count raw list items so the check does not reuse the parser selector.
      final rows = RegExp(r'<li\b').allMatches(body).length;
      expect(rows, greaterThan(0));
      expect(MokpoAcademicSource.parse(body, year, semester), hasLength(rows));
    }
  });
  test(
    'Mokpo reads both semesters and preceding winter with explicit Daily identity',
    () async {
      final queries = <(int, int)>[];
      final source = MokpoAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/schdulmanage/www/1/mokpoMainSchdul.do');
          expect(request.headers['User-Agent'], contains('DailyCalendar'));
          final year = int.parse(request.bodyFields['year']!);
          final semester = request.bodyFields['kind'] == 'preHalf' ? 1 : 2;
          queries.add((year, semester));
          return http.Response(
            fixture(year, semester),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final previous = await source.fetch(2025);
      expect(previous, hasLength(43));
      expect(
        previous.any(
          (e) =>
              e.title == '동계방학' &&
              e.start == DateTime(2024, 12, 24) &&
              e.end == DateTime(2025, 3, 1),
        ),
        isTrue,
      );
      queries.clear();
      final events = await source.fetch(2026);
      source.close();
      expect(queries, [(2025, 2), (2026, 1), (2026, 2)]);
      expect(events, hasLength(44));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(44));
      final winter = events.singleWhere(
        (e) => e.title == '동계방학' && e.start.year == 2026,
      );
      expect(winter.start, DateTime(2026, 12, 19));
      expect(winter.end, DateTime(2027, 3, 1));
      expect(
        events.any((e) => e.title == '동계 계절수업(3주)' && e.start.year == 2025),
        isTrue,
      );
    },
  );

  test('Mokpo refuses wrong semester and missing month', () {
    final body = fixture(2026, 2);
    expect(
      () => MokpoAcademicSource.parse(body, 2026, 1),
      throwsFormatException,
    );
    expect(
      () => MokpoAcademicSource.parse(
        body.replaceFirst('id="monthArea20269"', 'id="missing"'),
        2026,
        2,
      ),
      throwsFormatException,
    );
  });

  test('Mokpo refuses a schedule item that lost or rewrapped its record', () {
    final body = fixture(2026, 2);
    for (final broken in [
      body
          .replaceFirst('<dl>', '<div><dl>')
          .replaceFirst('</dl>', '</dl></div>'),
      body.replaceFirst(RegExp(r'<dl>[\s\S]*?</dl>'), '<span>공지</span>'),
      body.replaceFirst('<li class="">', '<li class=""><dl><dt></dt></dl>'),
    ]) {
      expect(
        () => MokpoAcademicSource.parse(broken, 2026, 2),
        throwsFormatException,
      );
    }
  });

  test(
    'Mokpo refuses invalid dates and firewall HTML instead of partial imports',
    () {
      final body = fixture(2026, 2);
      expect(
        () => MokpoAcademicSource.parse(
          body.replaceFirst('09.01.', '09.32.'),
          2026,
          2,
        ),
        throwsFormatException,
      );
      expect(
        () =>
            MokpoAcademicSource.parse('<html>blocked request</html>', 2026, 2),
        throwsFormatException,
      );
    },
  );
}
