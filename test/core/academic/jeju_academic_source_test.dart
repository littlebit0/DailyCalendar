import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/jeju_academic_source.dart';
import 'package:html/parser.dart' as html;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Jeju retains true summer and winter bounds and excludes graduate-only rows',
    () async {
      final source = JejuAcademicSource(
        client: MockClient((request) async {
          final year = request.url.queryParameters['year'];
          return http.Response(
            File('test/fixtures/academic/jeju-$year.html').readAsStringSync(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(events.length, 68);
      final closure = events.singleWhere((e) => e.title == '아라대동제 휴강');
      expect(closure.start, DateTime(2026, 5, 29));
      expect(closure.end, DateTime(2026, 5, 30));
      expect(
        events.singleWhere((e) => e.title == '1학기 보강(아라대동제)').start,
        DateTime(2026, 6, 16),
      );
      expect(events.any((e) => e.title.startsWith('(대학원)')), isFalse);
      final summer = events.singleWhere((e) => e.title == '하기계절수업 개강');
      expect(summer.start, DateTime(2026, 6, 29));
      expect(summer.end, DateTime(2026, 7, 21));
      final winter = events.singleWhere(
        (e) => e.title == '동기계절수업 개강' && e.start.year == 2026,
      );
      expect(winter.start, DateTime(2026, 12, 28));
      expect(winter.end, DateTime(2027, 1, 19));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );

  test('Jeju rejects stale year and invalid official date', () {
    final body = File(
      'test/fixtures/academic/jeju-2026.html',
    ).readAsStringSync();
    expect(() => JejuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => JejuAcademicSource.parse(
        body.replaceFirst('01.02(금)', '01.32(금)'),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('every published Jeju undergraduate row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final body = File(
        'test/fixtures/academic/jeju-$year.html',
      ).readAsStringSync();
      final rows = html
          .parse(body)
          .querySelectorAll('.academic-contents .month-wrap li');
      final graduate = rows
          .where(
            (r) => r.querySelector('span')!.text.trim().startsWith('(대학원)'),
          )
          .length;
      expect(rows.length, year == 2025 ? 60 : 59);
      expect(graduate, 12);
      // Each closure-table row adds its closure day and its make-up day.
      final closures = year == 2025 ? 12 : 10;
      expect(
        JejuAcademicSource.parse(body, year),
        hasLength(rows.length - graduate + closures * 2),
      );
    }
  });

  test('Jeju profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000027',
      'academyinfo:0000027',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '제주대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'jeju',
      );
    }
  });
}
