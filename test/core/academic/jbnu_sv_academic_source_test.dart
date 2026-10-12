import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/jbnu_academic_source.dart';
import 'package:daily/core/academic/sv_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'JBNU uses anonymous CSRF session and preserves undergraduate portion of mixed entries',
    () async {
      final requests = <String>[];
      final source = JbnuAcademicSource(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<meta name="_csrf" content="test-public-csrf">',
              200,
              headers: {
                'set-cookie': 'JSESSIONID=test-anonymous; Path=/; HttpOnly',
              },
            );
          }
          expect(request.headers['Cookie'], 'JSESSIONID=test-anonymous');
          expect(request.headers['X-CSRF-Token'], 'test-public-csrf');
          final body = Uri.splitQueryString(request.body);
          final year = body['acYear'];
          final semester = body['acSemester'];
          requests.add('$year-$semester');
          return http.Response(
            File(
              'test/fixtures/academic/jbnu-$year-$semester.html',
            ).readAsStringSync(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(requests, ['2025-2', '2026-1', '2026-2']);
      expect(events.length, 37);
      expect(
        events.any(
          (e) => e.title == '제1학기 개강' && e.start == DateTime(2026, 3, 3),
        ),
        isTrue,
      );
      expect(events.any((e) => e.title.contains('대학원')), isFalse);
      final winter = events.singleWhere((e) => e.title == '동기 계절수업 시작');
      expect(winter.start, DateTime(2026, 12, 24));
      expect(events.map((e) => e.sourceId).toSet().length, 37);
    },
  );
  test('JBNU refuses stale semester and rolled-over invalid dates', () {
    final body = File(
      'test/fixtures/academic/jbnu-2026-1.html',
    ).readAsStringSync();
    expect(
      () => JbnuAcademicSource.parse(body, 2025, 1),
      throwsFormatException,
    );
    expect(
      () => JbnuAcademicSource.parse(
        body.replaceFirst('2026-03-03', '2026-03-32'),
        2026,
        1,
      ),
      throwsFormatException,
    );
  });
  for (final sunchon in [true, false]) {
    test(
      'ScheduleView ${sunchon ? 'SCNU' : 'Changwon'} retains winter overlaps and deduplicates monthly results',
      () async {
        final months = <String>[];
        final client = MockClient((request) async {
          final fields = Uri.splitQueryString(request.body);
          final month = sunchon ? '' : fields['dateFirst']!.split('/')[1];
          months.add(month);
          return http.Response(
            File(
              'test/fixtures/academic/${sunchon ? 'sunchon-2026' : 'changwon-2026-$month'}.json',
            ).readAsStringSync(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final source = sunchon
            ? SvAcademicSource.sunchon(client: client)
            : SvAcademicSource.changwon(client: client);
        addTearDown(source.close);
        final events = await source.fetch(2026);
        final count = sunchon ? 70 : 66;
        expect(months.length, sunchon ? 1 : 12);
        expect(events.length, count);
        expect(events.map((e) => e.sourceId).toSet().length, count);
        expect(events.where((e) => e.title == '신정').length, 1);
        expect(
          events.any((e) => e.start.year == 2025 && e.end.year == 2026),
          isTrue,
        );
        expect(events.any((e) => e.start.month == 12), isTrue);
      },
    );
  }
  test('ScheduleView refuses a malformed date and foreign source identity', () {
    final rows =
        jsonDecode(
              File(
                'test/fixtures/academic/sunchon-2026.json',
              ).readAsStringSync(),
            )
            as List;
    rows.first['bgnde'] = '2026/01/32';
    expect(
      () => SvAcademicSource.parse(jsonEncode(rows), 2026, sunchon: true),
      throwsFormatException,
    );
    rows.first['bgnde'] = '2026/01/01';
    rows.first['sysId'] = 'another-school';
    expect(
      () => SvAcademicSource.parse(jsonEncode(rows), 2026, sunchon: true),
      throwsFormatException,
    );
  });
  test('Changwon branches never receive main campus dates by fallback', () {
    for (final entry in {
      'academyinfo:0003297': 'changwon-geochang',
      'academyinfo:0003298': 'changwon-namhae',
      'academyinfo:0000100': null,
    }.entries) {
      expect(
        AcademicProfile(
          universityId: 'institution:academyinfo:0000028',
          universityName: '국립창원대학교',
          schoolKind: 'fourYear',
          campusId: entry.key,
        ).academicSourceId,
        entry.value,
      );
    }
  });
}
