import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/tuk_academic_source.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/tuk-$year-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();
void main() {
  test(
    'TUK includes January omitted by annual view and full winter periods',
    () async {
      final requested = <String>[];
      final source = TukAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/schdulmain/haksa/37/jsonYearSchdul.do');
          final q = Uri.splitQueryString(r.body);
          final year = int.parse(q['year']!), month = int.parse(q['month']!);
          requested.add('$year-${q['month']}');
          return http.Response(
            fixture(year, month),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, [
        '2025-12',
        for (var m = 1; m <= 12; m++) '2026-${m.toString().padLeft(2, '0')}',
      ]);
      expect(events, hasLength(73));
      final winters = events
          .where((e) => e.title.contains('동계 계절학기 수업기간'))
          .toList();
      expect(winters, hasLength(2));
      expect(winters.first.start, DateTime(2026, 1, 5));
      expect(winters.first.end, DateTime(2026, 1, 24));
      expect(winters.last.start, DateTime(2026, 12, 23));
      expect(winters.last.end, DateTime(2027, 1, 15));
      expect(
        AcademicProfile(
          universityId: 'institution:academyinfo:0000247',
          universityName: '한국공학대학교',
          schoolKind: '대학교',
        ).academicSourceId,
        'tuk',
      );
    },
  );
  test('every published TUK row is imported for the calendar year', () async {
    var rows = 0;
    for (var m = 1; m <= 12; m++) {
      final published = (jsonDecode(fixture(2026, m)) as List).length;
      expect(
        TukAcademicSource.parse(fixture(2026, m), 2026, m),
        hasLength(published),
      );
      rows += published;
    }
    final source = TukAcademicSource(
      client: MockClient((r) async {
        final q = Uri.splitQueryString(r.body);
        return http.Response(
          fixture(int.parse(q['year']!), int.parse(q['month']!)),
          200,
          headers: {'content-type': 'application/json;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(events, hasLength(rows));
    expect(events.map((e) => e.sourceId).toSet(), hasLength(rows));
  });
  test('TUK profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000247',
      'academyinfo:0000247',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한국공학대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'tuk',
      );
    }
  });
  test(
    'TUK rejects wrong year and invalid official dates; absent year cannot erase imports',
    () async {
      expect(
        () => TukAcademicSource.parse(fixture(2026, 1), 2025, 1),
        throwsFormatException,
      );
      expect(
        () => TukAcademicSource.parse(
          fixture(2026, 1).replaceFirst('2026.01.02', '2026.02.30'),
          2026,
          1,
        ),
        throwsFormatException,
      );
      final source = TukAcademicSource(
        client: MockClient((r) async => http.Response('[]', 200)),
      );
      await expectLater(source.fetch(2026), throwsFormatException);
      source.close();
    },
  );
}
