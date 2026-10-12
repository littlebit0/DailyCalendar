import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/hanyang_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String campus, int year) => File(
  'test/fixtures/academic/hanyang-$campus-$year.json',
).readAsStringSync();
void main() {
  test(
    'Hanyang preserves previous winter and campus-specific official rows',
    () async {
      for (final erica in [false, true]) {
        final campus = erica ? 'erica' : 'seoul';
        final years = <int>[];
        final source = HanyangAcademicSource(
          erica: erica,
          client: MockClient((r) async {
            expect(r.method, 'POST');
            expect(r.url.path, erica ? '/-93' : '/-33');
            expect(
              r
                  .url
                  .queryParameters['_kr_ac_hanyang_calendar_web_portlet_CalendarViewPortlet_cmd'],
              'get_term_events',
            );
            final year = int.parse(
              Uri.splitQueryString(
                r.body,
              )['_kr_ac_hanyang_calendar_web_portlet_CalendarViewPortlet_sYear']!,
            );
            years.add(year);
            return http.Response(
              fixture(campus, year),
              200,
              headers: {'content-type': 'application/json;charset=utf-8'},
            );
          }),
        );
        final events = await source.fetch(2026);
        source.close();
        expect(years, [2025, 2026]);
        final winters = events
            .where((e) => RegExp(r'학년도 겨울 계절학기$').hasMatch(e.title))
            .toList();
        expect(winters, hasLength(2));
        expect(winters.first.start, DateTime(2025, 12, 22));
        expect(winters.first.end, DateTime(2026, 1, 14));
        expect(winters.last.start, DateTime(2026, 12, 23));
        expect(winters.last.end, DateTime(2027, 1, 15));
        expect(events.any((e) => e.title == '2025학년도 후기 학위수여식(서울)'), !erica);
        expect(
          AcademicProfile(
            universityId: 'institution:academyinfo:0000203',
            universityName: '한양대학교',
            schoolKind: '대학교',
            campusId: erica ? 'academyinfo:0000204' : 'academyinfo:0000203',
          ).academicSourceId,
          source.id,
        );
        expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
      }
    },
  );
  test(
    'Hanyang rejects missing months, wrong scope, invalid dates and failed response',
    () {
      Map<String, dynamic> root() =>
          jsonDecode(fixture('seoul', 2026)) as Map<String, dynamic>;
      String mutate(void Function(List<dynamic>) change) {
        final r = root();
        final data = jsonDecode(r['data'] as String) as List<dynamic>;
        change(data);
        r['data'] = jsonEncode(data);
        return jsonEncode(r);
      }

      void rejects(String body, [int year = 2026]) => expect(
        () => HanyangAcademicSource.parse(
          body,
          year,
          url: 'https://www.hanyang.ac.kr/-33',
        ),
        throwsFormatException,
      );
      rejects(mutate((d) => d.removeLast()));
      rejects(fixture('seoul', 2026), 2025);
      rejects(
        mutate((d) => d[0]['events'][0]['startDateTime'] = '2026-02-30 00:00'),
      );
      rejects(
        mutate((d) => d[0]['events'][0]['endDateTime'] = '2026-03-01 23:59'),
      );
      rejects(jsonEncode(root()..['status'] = false));
    },
  );
}
