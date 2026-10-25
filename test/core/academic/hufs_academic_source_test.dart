import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/hufs_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/hufs-$year.html').readAsStringSync();
void main() {
  test(
    'HUFS academic year retains next January and current year winter end',
    () async {
      final requested = <int>[];
      final source = HufsAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/schdulmanage/hufs/40/yearSchdul.do');
          final year = int.parse(Uri.splitQueryString(request.body)['year']!);
          requested.add(year);
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, [2025, 2026]);
      expect(events, hasLength(64));
      expect(
        events.any(
          (e) => e.start == DateTime(2026, 1, 13) && e.title == '계절학기 종강',
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.start == DateTime(2026, 12, 28) &&
              e.end == DateTime(2027, 1, 5),
        ),
        isTrue,
      );
      // Published on the 2025 academic-year page only, but runs into 2026.
      expect(
        events.any(
          (e) =>
              e.title == '제2학기 성적 열람 및 정정' &&
              e.start == DateTime(2025, 12, 29) &&
              e.end == DateTime(2026, 1, 3),
        ),
        isTrue,
      );
      expect(
        events.every(
          (e) =>
              e.start.isBefore(DateTime(2027)) && e.end.isAfter(DateTime(2026)),
        ),
        isTrue,
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('every published HUFS row is imported for each academic year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('#timeTableList .list-box')
          .length;
      expect(HufsAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
    expect(HufsAcademicSource.parse(fixture(2025), 2025), hasLength(56));
    expect(HufsAcademicSource.parse(fixture(2026), 2026), hasLength(63));
  });
  test('HUFS profile resolves to its registered calendar', () {
    for (final (id, campus) in [
      ('institution:academyinfo:0000192', null),
      ('institution:academyinfo:0000192', 'academyinfo:0000192'),
      ('academyinfo:0000192', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한국외국어대학교',
          schoolKind: 'fourYear',
          campusId: campus,
        ).academicSourceId,
        'hufs',
      );
    }
  });
  test('HUFS reports an unavailable calendar as an error', () {
    final source = HufsAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(source.fetch(2026), throwsFormatException);
  });
  test('HUFS rejects missing month and wrong year', () {
    expect(
      () => HufsAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => HufsAcademicSource.parse(
        fixture(2026).replaceFirst('class="box-month"', 'class="missing"'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => HufsAcademicSource.parse(
        fixture(2026).replaceFirst('03.01', '02.30'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
