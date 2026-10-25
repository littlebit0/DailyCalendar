import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/dongguk_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(bool wise, int year) => File(
  'test/fixtures/academic/dongguk-${wise ? 'wise' : 'seoul'}-$year.html',
).readAsStringSync();

void main() {
  for (final (wise, count) in [(false, 88), (true, 86)]) {
    final campus = wise ? 'WISE' : 'Seoul';
    test(
      'Dongguk $campus keeps its own official undergraduate periods',
      () async {
        final requested = <String>[];
        final source = DonggukAcademicSource(
          wise: wise,
          client: MockClient((request) async {
            expect(
              request.url.host,
              wise ? 'wise.dongguk.ac.kr' : 'www.dongguk.edu',
            );
            final year = request.url.queryParameters['schedule_start_date']!;
            requested.add(year);
            return http.Response(
              fixture(wise, int.parse(year)),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        );
        addTearDown(source.close);
        final events = await source.fetch(2026);
        expect(requested, ['2025', '2026']);
        expect(events.length, count);
        expect(events.map((e) => e.sourceId).toSet().length, count);
        expect(events.any((e) => e.title.contains('대학원')), isFalse);
        expect(events.any((e) => e.title.contains('학·석사연계과정')), isFalse);
        final winter = events.singleWhere(
          (e) => e.title == '겨울 계절학기' && e.start == DateTime(2026, 12, 22),
        );
        expect(winter.end, DateTime(2027, 1, 14));
      },
    );

    test('every published Dongguk $campus undergraduate row is imported', () {
      // Published rows = imported + graduate-only + combined-degree applications.
      for (final (year, rows, graduate, combined, imported)
          in wise
              ? [(2025, 97, 16, 0, 81), (2026, 102, 15, 2, 85)]
              : [(2025, 121, 22, 2, 97), (2026, 102, 18, 2, 82)]) {
        final body = fixture(wise, year);
        final published = html
            .parse(body)
            .querySelectorAll('.schedule table.tbl tbody > tr');
        final events = DonggukAcademicSource.parse(body, year, wise: wise);
        expect(published, hasLength(rows));
        expect(events, hasLength(imported));
        var graduateOnly = 0, combinedDegree = 0;
        for (final row in published) {
          final cell = row.querySelectorAll('td')[1];
          final office = cell.querySelector('p')?.text ?? '';
          final title = cell.nodes
              .where((n) => n.nodeType == 3)
              .map((n) => n.text)
              .join()
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (title.contains('학·석사연계과정')) {
            combinedDegree++;
            expect(events.any((e) => e.title == title), isFalse);
            continue;
          }
          if (title.contains('대학원') ||
              (office.contains('대학원') && !office.contains('/'))) {
            graduateOnly++;
            continue;
          }
          expect(
            events.any((e) => e.title == title),
            isTrue,
            reason: '$year $title',
          );
        }
        expect(graduateOnly, graduate, reason: '$year');
        expect(combinedDegree, combined, reason: '$year');
        expect(rows, imported + graduate + combined);
      }
    });

    test('Dongguk $campus leaves out graduate-office-only rows', () {
      final body = fixture(wise, 2026);
      final titles = DonggukAcademicSource.parse(
        body,
        2026,
        wise: wise,
      ).map((e) => e.title).toSet();
      expect(titles.any((t) => t.contains('학·석사연계과정')), isFalse);
      expect(titles, contains('재입학 신청'));
      expect(
        DonggukAcademicSource.isGraduateOnly('2026-2학기 학·석사연계과정 신청', '대학원교학팀'),
        isTrue,
      );
      expect(
        DonggukAcademicSource.isGraduateOnly('수강신청 확인 및 정정', '대학원교학팀'),
        isTrue,
      );
      expect(
        DonggukAcademicSource.isGraduateOnly(
          '수강신청 확인 및 정정',
          '(주관부서: 학사지원팀/대학원실)',
        ),
        isFalse,
      );
    });

    test('Dongguk $campus rejects stale row years and invalid dates', () {
      final body = fixture(wise, 2026);
      expect(
        () => DonggukAcademicSource.parse(body, 2025, wise: wise),
        throwsFormatException,
      );
      expect(
        () => DonggukAcademicSource.parse(
          body.replaceFirst('2026.03.01.', '2026.03.32.'),
          2026,
          wise: wise,
        ),
        throwsFormatException,
      );
      expect(
        () => DonggukAcademicSource.parse(
          body.replaceAll('schedule_info_seq', 'missing'),
          2026,
          wise: wise,
        ),
        throwsFormatException,
      );
    });
  }

  test('Dongguk profiles resolve to their campus calendars', () {
    String? resolve(String universityId, [String? campusId]) => AcademicProfile(
      universityId: universityId,
      universityName: '동국대학교',
      schoolKind: 'fourYear',
      campusId: campusId,
    ).academicSourceId;
    expect(resolve('institution:academyinfo:0000100'), 'dongguk-seoul');
    expect(resolve('academyinfo:0000100'), 'dongguk-seoul');
    expect(resolve('academyinfo:0000101'), 'dongguk-wise');
    expect(
      resolve('institution:academyinfo:0000100', 'academyinfo:0000100'),
      'dongguk-seoul',
    );
    expect(
      resolve('institution:academyinfo:0000100', 'academyinfo:0000101'),
      'dongguk-wise',
    );
  });
}
