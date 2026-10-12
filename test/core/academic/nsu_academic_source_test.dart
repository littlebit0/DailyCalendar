import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/nsu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int month) => File(
  'test/fixtures/academic/nsu-2026-${month.toString().padLeft(2, '0')}.json',
).readAsStringSync();

void main() {
  test(
    'NSU collects twelve official months and preserves every overlapping winter event',
    () async {
      final months = <int>[];
      final source = NsuAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/calendar/getScheduleSummaryList');
          expect(request.bodyFields['departmentIdx'], '1');
          expect(request.bodyFields['year'], '2026');
          final month = int.parse(request.bodyFields['month']!);
          months.add(month);
          return http.Response(
            fixture(month),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
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
      expect(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000245',
          universityName: '남서울대학교',
          schoolKind: '4년제',
        ).academicSourceId,
        'nsu',
      );
    },
  );
  test(
    'NSU rejects failures, missing rows, invalid dates and wrong query month',
    () {
      final data = jsonDecode(fixture(1)) as Map<String, dynamic>;
      expect(
        () => NsuAcademicSource.parse(fixture(1), 2026, 6),
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
          fixture(1).replaceFirst('2026-01-05', '2026-01-32'),
          2026,
          1,
        ),
        throwsFormatException,
      );
    },
  );
}
