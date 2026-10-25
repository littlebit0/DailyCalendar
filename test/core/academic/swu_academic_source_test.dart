import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/swu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/swu-$year-${month.toString().padLeft(2, '0')}.html',
).readAsStringSync();

SwuAcademicSource source(int year, List<int> months) => SwuAcademicSource(
  client: MockClient((request) async {
    expect(request.url.path, '/schdulMng/swu/15/monthSchdul.do');
    final data = Uri.splitQueryString(request.body);
    expect(data['year'], '$year');
    final month = int.parse(data['month']!);
    months.add(month);
    return http.Response(
      fixture(year, month),
      200,
      headers: {'content-type': 'text/html;charset=utf-8'},
    );
  }),
);

/// Published record numbers across the year's twelve monthly lists.
Set<String> publishedIds(int year) => {
  for (var month = 1; month <= 12; month++)
    for (final row
        in html.parse(fixture(year, month)).querySelectorAll('.monthList dl'))
      RegExp(
        r"set_layer\('(\d+)'",
      ).firstMatch(row.querySelector('dd a')!.attributes['onclick']!)![1]!,
};

void main() {
  test(
    'SWU gets full periods from all monthly views rather than start-only annual',
    () async {
      final months = <int>[];
      final swu = source(2026, months);
      final events = await swu.fetch(2026);
      swu.close();
      expect(months, List.generate(12, (i) => i + 1));
      expect(
        events.where((e) => e.title == '중간고사(권장)').map((e) => (e.start, e.end)),
        [
          (DateTime(2026, 4, 21), DateTime(2026, 4, 28)),
          (DateTime(2026, 10, 20), DateTime(2026, 10, 27)),
        ],
      );
      expect(
        events.where((e) => e.title == '성적정정').map((e) => (e.start, e.end)),
        [(DateTime(2025, 12, 30), DateTime(2026, 1, 4))],
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('every published SWU row is imported for each year', () async {
    for (final year in [2025, 2026]) {
      for (var month = 1; month <= 12; month++) {
        final rows = html
            .parse(fixture(year, month))
            .querySelectorAll('.monthList dl')
            .length;
        expect(
          SwuAcademicSource.parse(fixture(year, month), year, month),
          hasLength(rows),
          reason: '$year-$month',
        );
      }
      // Rows spanning two months appear in both lists under one record number.
      final swu = source(year, []);
      expect(await swu.fetch(year), hasLength(publishedIds(year).length));
      swu.close();
    }
  });
  test('SWU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000126',
      'academyinfo:0000126',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '서울여자대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'swu',
      );
    }
  });
  test('SWU rejects wrong month/year and invalid dates', () {
    expect(
      () => SwuAcademicSource.parse(fixture(2026, 10), 2025, 10),
      throwsFormatException,
    );
    expect(
      () => SwuAcademicSource.parse(fixture(2026, 10), 2026, 11),
      throwsFormatException,
    );
    expect(
      () => SwuAcademicSource.parse(
        fixture(2026, 10).replaceFirst('10.03', '02.30'),
        2026,
        10,
      ),
      throwsFormatException,
    );
    expect(
      () => SwuAcademicSource.parse(
        fixture(2026, 10).replaceFirst('class="monthList"', 'class="missing"'),
        2026,
        10,
      ),
      throwsFormatException,
    );
  });
  test('SWU fails instead of returning an empty calendar', () async {
    final swu = SwuAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(swu.fetch(2026), throwsFormatException);
    swu.close();
  });
}
