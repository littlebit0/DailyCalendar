import 'dart:io';
import 'package:daily/core/academic/gnue_academic_source.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int semester) =>
    File('test/fixtures/academic/gnue-$year-$semester.html').readAsStringSync();
void main() {
  test(
    'GNUE retains repeated cross-month periods and previous winter exactly once',
    () async {
      final requests = <(int, int)>[];
      final source = GnueAcademicSource(
        client: MockClient((r) async {
          final q = r.url.queryParameters;
          final year = int.parse(q['yyyy']!);
          final semester = q['contentUid'] == '4a9f18ab5c48fe8c015caa01ed5507e9'
              ? 1
              : 2;
          requests.add((year, semester));
          return http.Response(
            fixture(year, semester),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requests, [(2025, 2), (2026, 1), (2026, 2)]);
      expect(events, hasLength(34));
      final winter = events.where((e) => e.title.contains('동계방학')).toList();
      expect(winter, hasLength(2));
      expect(winter.first.start, DateTime(2025, 12, 22));
      expect(winter.first.end, DateTime(2026, 3, 1));
      expect(winter.last.start, DateTime(2026, 12, 22));
      expect(winter.last.end, DateTime(2027, 3, 1));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(34));
      expect(
        AcademicProfile(
          universityId: 'institution:academyinfo:0000252',
          universityName: '광주교육대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'gnue',
      );
    },
  );
  test('GNUE rejects stale year, incomplete months and invalid dates', () {
    expect(
      () => GnueAcademicSource.parse(fixture(2026, 2), 2025, 2),
      throwsFormatException,
    );
    expect(
      () => GnueAcademicSource.parse(
        fixture(2026, 2).replaceFirst('2026년 09월', '2026년 08월'),
        2026,
        2,
      ),
      throwsFormatException,
    );
    expect(
      () => GnueAcademicSource.parse(
        fixture(2026, 2).replaceFirst('09.01', '09.32'),
        2026,
        2,
      ),
      throwsFormatException,
    );
  });

  test('each event links to the semester page and year it came from (#245)', () {
    String page(int semester) => semester == 1
        ? '4a9f18ab5c48fe8c015caa01ed5507e9'
        : '4a9f18ab5c48fe8c015caa0228a707eb';
    for (final (year, semester) in [(2025, 2), (2026, 1), (2026, 2)]) {
      final events = GnueAcademicSource.parse(fixture(year, semester), year, semester);
      for (final event in events) {
        final url = Uri.parse(event.url!);
        expect(url.scheme, 'https');
        expect(url.host, 'www.gnue.ac.kr');
        expect(url.queryParameters, {
          'contentUid': page(semester),
          'yyyy': '$year',
        });
      }
    }
    final opening = GnueAcademicSource.parse(fixture(2026, 2), 2026, 2)
        .singleWhere((event) => event.title.contains('2학기 개강'));
    expect(Uri.parse(opening.url!).queryParameters['contentUid'], page(2));
  });
}
