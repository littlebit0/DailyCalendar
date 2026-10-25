import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/sogang_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/sogang-$year.json').readAsStringSync();
void main() {
  test(
    'Sogang coalesces daily records and preserves year boundaries',
    () async {
      final source = SogangAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/api/api/v1/mainKo/scheduleList');
          final year = int.parse(
            request.url.queryParameters['startDate']!.substring(0, 4),
          );
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      final exams = events.where((e) => e.title == '중간시험').toList();
      expect(exams.map((e) => (e.start, e.end)), [
        (DateTime(2026, 4, 21), DateTime(2026, 4, 28)),
        (DateTime(2026, 10, 20), DateTime(2026, 10, 27)),
      ]);
      final grades = events.where((e) => e.title == '학기말성적 확인').toList();
      expect(
        grades.any((e) => e.start.year == 2025 && e.end.year == 2026),
        isTrue,
      );
      expect(
        grades.any((e) => e.start.year == 2026 && e.end.year == 2027),
        isTrue,
      );
      expect(
        events
            .where((e) => e.title == '계절수업 종강' && e.start.month == 1)
            .single
            .start,
        DateTime(2026, 1, 14),
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );
  test('every published Sogang daily record is imported', () {
    List<(String, DateTime)> published(int year) => [
      for (final row in jsonDecode(fixture(year))['data'] as List)
        (
          (row['title'] as String).trim(),
          DateTime.parse((row['schedule'] as String).replaceAll('.', '-')),
        ),
    ];
    for (final year in [2025, 2026, 2027]) {
      final rows = published(year);
      final parsed = SogangAcademicSource.parse(fixture(year), year);
      expect({
        for (final e in parsed.entries)
          for (final d in e.value) (e.key, d),
      }, rows.toSet());
      expect(rows.toSet(), hasLength(rows.length));
    }
  });
  test('Sogang 2026 events cover exactly the published 2026 days', () async {
    final source = SogangAcademicSource(
      client: MockClient(
        (request) async => http.Response(
          fixture(
            int.parse(
              request.url.queryParameters['startDate']!.substring(0, 4),
            ),
          ),
          200,
          headers: {'content-type': 'application/json;charset=utf-8'},
        ),
      ),
    );
    final events = await source.fetch(2026);
    source.close();
    final days = <(String, DateTime)>[
      for (final e in events)
        for (
          var d = e.start;
          d.isBefore(e.end);
          d = DateTime(d.year, d.month, d.day + 1)
        )
          if (d.year == 2026) (e.title, d),
    ];
    final rows = SogangAcademicSource.parse(fixture(2026), 2026);
    expect(days.toSet(), {
      for (final e in rows.entries)
        for (final d in e.value) (e.key, d),
    });
    expect(days, hasLength(days.toSet().length));
    expect(events, hasLength(55));
  });
  test('Sogang profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000120',
      'academyinfo:0000120',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '서강대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'sogang',
      );
    }
  });
  test('Sogang rejects wrong year, rollover date and failed response', () {
    expect(
      () => SogangAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => SogangAcademicSource.parse(
        fixture(2026).replaceFirst('2026.04.03', '2026.02.30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SogangAcademicSource.parse('{"statusCode":500,"data":[]}', 2026),
      throwsFormatException,
    );
  });
}
