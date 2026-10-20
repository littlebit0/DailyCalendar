import 'dart:io';
import 'package:daily/core/academic/yonsei_academic_source.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/yonsei-$year.html').readAsStringSync();
void main() {
  test(
    'Yonsei common calendar keeps cross-month periods and published seasonal boundaries',
    () async {
      final requested = <String>[];
      final source = YonseiAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/schdulMng/sc/28/yearSchdul.do');
          final year = Uri.splitQueryString(r.body)['year']!;
          requested.add(year);
          return http.Response(
            fixture(int.parse(year)),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(requested, ['2025', '2026']);
      expect(events.map((e) => e.sourceId).toSet(), hasLength(events.length));
      expect(events.where((e) => e.title == '고난주간'), hasLength(1));
      final holyWeek = events.singleWhere((e) => e.title == '고난주간');
      expect(holyWeek.start, DateTime(2026, 3, 30));
      expect(holyWeek.end, DateTime(2026, 4, 5));
      expect(
        events.any(
          (e) =>
              e.title == '겨울계절제 수업 종료' &&
              e.start == DateTime(2026, 1, 20) &&
              e.end == DateTime(2026, 1, 21),
        ),
        isTrue,
      );
      for (final campus in ['academyinfo:0000149', 'academyinfo:0000150']) {
        expect(
          AcademicProfile(
            universityId: 'institution:academyinfo:0000149',
            universityName: '연세대학교',
            schoolKind: '대학교',
            campusId: campus,
          ).academicSourceId,
          'yonsei',
        );
      }
    },
  );
  test('Yonsei rejects partial years and impossible dates', () {
    expect(
      () => YonseiAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => YonseiAcademicSource.parse(
        fixture(2026).replaceFirst('01-12', '01-32'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => YonseiAcademicSource.parse(
        fixture(2026).replaceFirst('1월', '2월'),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('an explicit end month outside 1-12 is rejected, a valid one kept (#239)', () {
    String withEnd(String end) => fixture(2026).replaceAllMapped(
      RegExp(r'(03-30\s*\(Mon\)\s*~\s*)04(\s*\(Sat\))'),
      (m) => '${m[1]}$end${m[2]}',
    );
    for (final end in ['13-04', '00-04']) {
      expect(
        () => YonseiAcademicSource.parse(withEnd(end), 2026),
        throwsFormatException,
        reason: end,
      );
    }
    final holyWeek = YonseiAcademicSource.parse(
      withEnd('04-04'),
      2026,
    ).singleWhere((event) => event.title == '고난주간');
    expect(holyWeek.start, DateTime(2026, 3, 30));
    expect(holyWeek.end, DateTime(2026, 4, 5));
  });
}
