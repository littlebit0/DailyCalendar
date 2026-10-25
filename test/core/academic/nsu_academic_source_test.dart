import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/nsu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/nsu-$year-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();

List<Map<String, dynamic>> rows(int year, int month) =>
    ((jsonDecode(fixture(year, month)) as Map)['body']['list'] as List)
        .cast<Map<String, dynamic>>();

NsuAcademicSource source(int year, List<int> months) => NsuAcademicSource(
  client: MockClient((request) async {
    expect(request.method, 'POST');
    expect(request.url.path, '/api/calendar/getScheduleSummaryList');
    expect(request.bodyFields['departmentIdx'], '1');
    expect(request.bodyFields['year'], '$year');
    final month = int.parse(request.bodyFields['month']!);
    months.add(month);
    return http.Response(
      fixture(year, month),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

void main() {
  test(
    'NSU collects twelve official months and preserves every overlapping winter event',
    () async {
      final months = <int>[];
      final nsu = source(2026, months);
      final events = await nsu.fetch(2026);
      nsu.close();
      expect(months, List.generate(12, (i) => i + 1));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final winters = events
          .where((e) => e.title == '계절학기 개설' && e.start.month == 12)
          .toList();
      expect(winters, hasLength(2));
      expect(winters.first.start, DateTime(2025, 12, 22));
      expect(winters.first.end, DateTime(2026, 1, 6));
      expect(winters.last.end, DateTime(2027, 1, 5));
      expect(events.where((e) => e.title == '2학기 대학 자체 행정감사'), hasLength(1));
    },
  );
  test('every published NSU row is imported for each year', () async {
    for (final year in [2025, 2026]) {
      final published = <int>{};
      for (var month = 1; month <= 12; month++) {
        final monthRows = rows(year, month);
        published.addAll(monthRows.map((r) => r['id'] as int));
        expect(
          NsuAcademicSource.parse(fixture(year, month), year, month),
          hasLength(monthRows.length),
        );
      }
      final nsu = source(year, []);
      final events = await nsu.fetch(year);
      nsu.close();
      expect(events.map((e) => int.parse(e.sourceId)).toSet(), published);
      expect(events, hasLength({2025: 80, 2026: 96}[year]));
    }
  });
  test('NSU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000245',
      'academyinfo:0000245',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '남서울대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'nsu',
      );
    }
  });
  test(
    'NSU rejects failures, missing rows, invalid dates and wrong query month',
    () {
      final data = jsonDecode(fixture(2026, 1)) as Map<String, dynamic>;
      expect(
        () => NsuAcademicSource.parse(fixture(2026, 1), 2026, 6),
        throwsFormatException,
      );
      data['code'] = 999;
      expect(
        () => NsuAcademicSource.parse(jsonEncode(data), 2026, 1),
        throwsFormatException,
      );
      data['code'] = 10000;
      data['body']['total_count'] = 100;
      expect(
        () => NsuAcademicSource.parse(jsonEncode(data), 2026, 1),
        throwsFormatException,
      );
      expect(
        () => NsuAcademicSource.parse(
          fixture(2026, 1).replaceFirst('2026-01-05', '2026-01-32'),
          2026,
          1,
        ),
        throwsFormatException,
      );
    },
  );
  test('NSU failed response keeps existing events by throwing', () {
    final nsu = NsuAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(nsu.fetch(2026), throwsFormatException);
  });
}
