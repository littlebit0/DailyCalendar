import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/cje_academic_source.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/cje-2026.json').readAsStringSync();

void main() {
  test(
    'CJE uses published annual JSON request and preserves both winters',
    () async {
      final source = CjeAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/web/schedule/ajax/list.do');
          expect(jsonDecode(request.body), {
            'schedule_start_dt': '2026-01-01',
            'schedule_end_dt': '2026-12-31',
          });
          return http.Response(
            fixture(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(38));
      final winter = events.where((e) => e.title == '동계 휴가').toList();
      expect(winter, hasLength(2));
      expect(winter.first.start, DateTime(2025, 12, 20));
      expect(winter.first.end, DateTime(2026, 3, 1));
      expect(winter.last.start, DateTime(2026, 12, 22));
      expect(winter.last.end, DateTime(2027, 3, 1));
      expect(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000261',
          universityName: '청주교육대학교',
          schoolKind: '4년제',
        ).academicSourceId,
        'cje',
      );
    },
  );
  test('CJE rejects wrong year, invalid periods and duplicate identities', () {
    expect(
      () => CjeAcademicSource.parse(fixture(), 2028),
      throwsFormatException,
    );
    expect(
      () => CjeAcademicSource.parse(
        fixture().replaceFirst('2026-02-28', '2026-02-30'),
        2026,
      ),
      throwsFormatException,
    );
    final data = jsonDecode(fixture());
    data['scheduleList'].add(data['scheduleList'].first);
    expect(
      () => CjeAcademicSource.parse(jsonEncode(data), 2026),
      throwsFormatException,
    );
  });
}
