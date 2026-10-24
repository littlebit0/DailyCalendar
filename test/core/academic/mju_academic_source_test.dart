import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:html/parser.dart' as html;
import 'package:daily/core/academic/mju_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/mju-$year.html').readAsStringSync();
void main() {
  test(
    'MJU preserves winter carry-over and shared undergraduate events',
    () async {
      final requests = <int>[];
      final source = MjuAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/schdulmanage/mjukr/4/yearSchdul.do');
          final year = int.parse(Uri.splitQueryString(request.body)['year']!);
          requests.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requests, [2025, 2026]);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
      expect(
        events
            .where((e) => e.title.contains('동계 계절수업기간') && e.start.year == 2026)
            .single
            .end,
        DateTime(2027, 1, 14),
      );
      expect(
        events.any((e) => e.start.year == 2025 && e.end.year == 2026),
        isTrue,
      );
      expect(events.any((e) => e.title.contains('과정변경')), isFalse);
      expect(events.any((e) => e.title.contains('전과 및 재입학')), isTrue);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('every published MJU row is imported unless graduate-only', () {
    // Undergraduate and shared parts become events; graduate-only rows do not.
    const expected = {
      2025: (rows: 75, graduateOnly: 18, events: 59),
      2026: (rows: 79, graduateOnly: 15, events: 66),
    };
    for (final MapEntry(key: year, value: count) in expected.entries) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('#timeTableList .text-list > li');
      var graduateOnly = 0;
      var parts = 0;
      for (final row in rows) {
        row.querySelector('strong')!.remove();
        final labels = RegExp(
          r'\[([^\]]+)\]',
        ).allMatches(row.text).map((m) => m[1]!.replaceAll(' ', '')).toList();
        expect(labels.toSet().difference({'학부', '학부·대학원', '대학원'}), isEmpty);
        final kept = labels.isEmpty
            ? 1
            : labels.where((l) => l != '대학원').length;
        if (kept == 0) graduateOnly++;
        parts += kept;
      }
      expect(rows, hasLength(count.rows));
      expect(graduateOnly, count.graduateOnly);
      expect(parts, count.events);
      expect(MjuAcademicSource.parse(fixture(year), year), hasLength(parts));
    }
  });
  test('MJU profiles for both campuses resolve to its registered calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000109', null),
      ('institution:academyinfo:0000109', 'academyinfo:0000109'),
      ('institution:academyinfo:0000109', 'academyinfo:0000111'),
      ('academyinfo:0000109', null),
      ('academyinfo:0000111', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '명지대학교',
          campusId: campusId,
          schoolKind: 'fourYear',
        ).academicSourceId,
        'mju',
      );
    }
  });
  test('MJU rejects year, dates and incomplete annual list', () {
    expect(
      () => MjuAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => MjuAcademicSource.parse(
        fixture(2026).replaceFirst('.01 .01', '.02 .30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => MjuAcademicSource.parse(
        fixture(2026).replaceFirst('01월', 'bad'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => MjuAcademicSource.parse(
        fixture(2026).replaceFirst('[학부] 동계', '동계 [학부] 동계'),
        2026,
      ),
      throwsFormatException,
    );
    // A new audience label is rejected rather than treated as graduate-only.
    for (final label in ['[학 부 생]', '[대학원생]', '[학부·대학원·평생]']) {
      expect(
        () => MjuAcademicSource.parse(
          fixture(2026).replaceFirst('[학부] 동계', '$label 동계'),
          2026,
        ),
        throwsFormatException,
      );
    }
  });
}
