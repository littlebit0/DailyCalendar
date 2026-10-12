import 'dart:io';
import 'package:daily/core/academic/korea_academic_source.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/korea-$year-${month.toString().padLeft(2, '0')}.html',
).readAsStringSync();
void main() {
  test(
    'KU uses monthly duration rows and latest revised common calendar for both campuses',
    () async {
      final requested = <String>[];
      final source = KoreaAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/schdulMng/ko/5/monthSchdul.do');
          final q = Uri.splitQueryString(r.body);
          final y = int.parse(q['year']!), m = int.parse(q['month']!);
          requested.add('$y-$m');
          return http.Response(
            fixture(y, m),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['2025-12', for (var m = 1; m <= 12; m++) '2026-$m']);
      expect(events, hasLength(68));
      final leave = events.singleWhere(
        (e) => e.title == '휴·복학 신청' && e.start.month == 2,
      );
      expect(leave.start, DateTime(2026, 2, 2));
      expect(leave.end, DateTime(2026, 2, 26));
      final rivalry = events.singleWhere((e) => e.title == '정기 고·연전');
      expect(rivalry.start, DateTime(2026, 10, 2));
      expect(rivalry.end, DateTime(2026, 10, 4));
      expect(events.any((e) => e.title.contains(r'\,')), isFalse);
      for (final campus in ['academyinfo:0000069', 'academyinfo:0000070']) {
        expect(
          AcademicProfile(
            universityId: 'institution:academyinfo:0000069',
            universityName: '고려대학교',
            schoolKind: '대학교',
            campusId: campus,
          ).academicSourceId,
          'korea',
        );
      }
    },
  );
  test(
    'KU rejects wrong year, wrong month and impossible published period',
    () {
      expect(
        () => KoreaAcademicSource.parse(fixture(2026, 2), 2025, 2),
        throwsFormatException,
      );
      expect(
        () => KoreaAcademicSource.parse(fixture(2026, 2), 2026, 3),
        throwsFormatException,
      );
      expect(
        () => KoreaAcademicSource.parse(
          fixture(2026, 2).replaceFirst('02.25', '02.32'),
          2026,
          2,
        ),
        throwsFormatException,
      );
    },
  );
}
