import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/jbnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int semester) =>
    File('test/fixtures/academic/jbnu-$year-$semester.html').readAsStringSync();

JbnuAcademicSource mockSource(List<String> requests) => JbnuAcademicSource(
  client: MockClient((request) async {
    if (request.method == 'GET') {
      return http.Response(
        '<meta name="_csrf" content="test-public-csrf">',
        200,
        headers: {'set-cookie': 'JSESSIONID=test-anonymous; Path=/; HttpOnly'},
      );
    }
    expect(request.headers['Cookie'], 'JSESSIONID=test-anonymous');
    expect(request.headers['X-CSRF-Token'], 'test-public-csrf');
    final body = Uri.splitQueryString(request.body);
    final year = body['acYear']!;
    final semester = body['acSemester']!;
    requests.add('$year-$semester');
    return http.Response(
      fixture(int.parse(year), int.parse(semester)),
      200,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }),
);

void main() {
  test(
    'JBNU uses anonymous CSRF session and preserves undergraduate portion of mixed entries',
    () async {
      final requests = <String>[];
      final source = mockSource(requests);
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(requests, ['2025-2', '2026-1', '2026-2']);
      expect(events.length, 37);
      expect(
        events.any(
          (e) => e.title == '제1학기 개강' && e.start == DateTime(2026, 3, 3),
        ),
        isTrue,
      );
      expect(events.any((e) => e.title.contains('대학원')), isFalse);
      final winter = events.singleWhere((e) => e.title == '동기 계절수업 시작');
      expect(winter.start, DateTime(2026, 12, 24));
      expect(events.map((e) => e.sourceId).toSet().length, 37);
    },
  );
  test(
    'every published undergraduate JBNU row is imported for each year',
    () async {
      for (final (year, published) in [(2025, 44), (2026, 43)]) {
        final expected = <String>[];
        var rows = 0;
        for (final (y, s) in [(year - 1, 2), (year, 1), (year, 2)]) {
          for (final row
              in html
                  .parse(fixture(y, s))
                  .querySelectorAll('dl.academic > div')) {
            final range = row.querySelector('dt')!.text.trim().split('~');
            final start = DateTime.parse(range.first.trim());
            final last = DateTime.parse(range.last.trim());
            if (start.year > year || last.year < year) continue;
            rows++;
            // Graduate-school items are left out by design.
            final title = row
                .querySelector('dd')!
                .text
                .split(',')
                .map((s) => s.trim())
                .where((s) => !s.contains('대학원'))
                .join(', ');
            if (title.isNotEmpty) {
              expected.add('${start.toIso8601String()} $title');
            }
          }
        }
        expect(rows, published);
        final events = await mockSource([]).fetch(year);
        expect(events, hasLength(published - 6));
        expect(
          events.map((e) => '${e.start.toIso8601String()} ${e.title}').toList()
            ..sort(),
          expected..sort(),
        );
        expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
      }
    },
  );
  test('JBNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000025',
      'academyinfo:0000025',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '전북대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'jbnu',
      );
    }
  });
  test('JBNU refuses stale semester and rolled-over invalid dates', () {
    final body = fixture(2026, 1);
    expect(
      () => JbnuAcademicSource.parse(body, 2025, 1),
      throwsFormatException,
    );
    expect(
      () => JbnuAcademicSource.parse(
        body.replaceFirst('2026-03-03', '2026-03-32'),
        2026,
        1,
      ),
      throwsFormatException,
    );
  });
}
