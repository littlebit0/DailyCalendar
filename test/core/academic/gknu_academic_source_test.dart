import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/gknu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/gknu-$year-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();

GknuAcademicSource fixtureSource(List<String> requested) => GknuAcademicSource(
  client: MockClient((request) async {
    expect(request.url.path, '/main/module/schedule/view.do');
    expect(request.url.queryParameters['category1'], '101');
    final selected = request.url.queryParameters['notice_start_date']!;
    requested.add(selected);
    final p = selected.split('-').map(int.parse).toList();
    return http.Response(
      fixture(p[0], p[1]),
      200,
      headers: {'content-type': 'application/json;charset=utf-8'},
    );
  }),
);

void main() {
  test('GKNU retrieves every month including the previous December', () async {
    final requested = <String>[];
    final source = fixtureSource(requested);
    final events = await source.fetch(2026);
    source.close();
    expect(requested, hasLength(13));
    expect(requested.first, '2025-12');
    expect(requested.last, '2026-12');
    expect(events, hasLength(44));
    expect(
      events.any(
        (e) =>
            e.title == '2학기 기말시험' &&
            e.start == DateTime(2026, 12, 14) &&
            e.end == DateTime(2026, 12, 19),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title == '겨울방학' &&
            e.start == DateTime(2026, 12, 21) &&
            e.end == DateTime(2026, 12, 22),
      ),
      isTrue,
    );
    expect(events.any((e) => e.start.year == 2025), isFalse);
    expect(GknuAcademicSource.parse(fixture(2026, 1), 2026, 1), isEmpty);
  });

  test('every published GKNU row is imported for each year', () async {
    for (final (year, rows) in [(2025, 46), (2026, 44)]) {
      var published = 0;
      for (var month = 1; month <= 12; month++) {
        final count = (jsonDecode(fixture(year, month)) as List).length;
        expect(
          GknuAcademicSource.parse(fixture(year, month), year, month),
          hasLength(count),
        );
        published += count;
      }
      expect(published, rows);
      final source = fixtureSource([]);
      expect(await source.fetch(year), hasLength(rows));
      source.close();
    }
  });

  test('GKNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000021',
      'academyinfo:0000021',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립경국대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'gknu',
      );
    }
  });

  test(
    'GKNU rejects invalid dates, wrong month and malformed JSON envelope',
    () {
      expect(
        () => GknuAcademicSource.parse(
          fixture(2026, 12).replaceFirst('2026-12-08', '2026-02-30'),
          2026,
          12,
        ),
        throwsFormatException,
      );
      expect(
        () => GknuAcademicSource.parse(fixture(2026, 12), 2026, 11),
        throwsFormatException,
      );
      expect(
        () => GknuAcademicSource.parse('{}', 2026, 12),
        throwsFormatException,
      );
    },
  );

  test('GKNU reports an unavailable calendar instead of an empty year', () {
    final failing = GknuAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(failing.fetch(2026), throwsFormatException);
    final empty = GknuAcademicSource(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    expect(empty.fetch(2026), throwsFormatException);
  });
}
