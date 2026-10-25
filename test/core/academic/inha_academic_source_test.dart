import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/inha_academic_source.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture([int year = 2026]) =>
    File('test/fixtures/academic/inha-$year.html').readAsStringSync();

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  test(
    'INHA annual view places the two winters in their actual years',
    () async {
      final source = InhaAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/schdulmanage/kr/5/yearSchdul.do');
          expect(request.bodyFields['year'], '2026');
          expect(request.bodyFields['kind'], '');
          return http.Response(
            fixture(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(
        events.singleWhere((e) => e.title == '2025학년도 동계 계절학기 수업').start,
        DateTime(2025, 12, 22),
      );
      expect(
        events.singleWhere((e) => e.title == '2025학년도 동계 계절학기 수업').end,
        DateTime(2026, 1, 15),
      );
      expect(
        events.singleWhere((e) => e.title == '2026학년도 동계 계절학기 수업').end,
        DateTime(2027, 1, 14),
      );
      expect(
        events.singleWhere((e) => e.title == '2026학년도 하계 계절학기 수업').end,
        DateTime(2026, 7, 16),
      );
      expect(events.every((e) => e.end.isAfter(DateTime(2026))), isTrue);
    },
  );

  test('every published INHA row overlapping the year is imported', () {
    // The annual view repeats the preceding December; only its rows that
    // run into the selected year belong to that year.
    for (final (year, rows) in [(2025, 52), (2026, 55)]) {
      final sections = html
          .parse(fixture(year))
          .querySelectorAll('#timeTableList > ul > li');
      final current = [
        for (final section in sections)
          if (!section.querySelector('h3')!.text.contains('${year - 1}년'))
            for (final title in section.querySelectorAll('dl > dd'))
              title.text.trim(),
      ];
      expect(
        sections.expand((section) => section.querySelectorAll('dl > dt')),
        hasLength(rows),
      );
      final events = InhaAcademicSource.parse(fixture(year), year);
      expect(
        events.where((e) => e.start.year == year).map((e) => e.title),
        unorderedEquals(current),
      );
      expect(events.where((e) => e.start.year < year).map((e) => e.title), [
        '${year - 1}학년도 동계 계절학기 수업',
      ]);
      expect(events, hasLength(current.length + 1));
    }
  });

  test('INHA keeps start-and-title IDs shared by consecutive years', () {
    final previous = InhaAcademicSource.parse(fixture(2025), 2025);
    final current = InhaAcademicSource.parse(fixture(2026), 2026);
    final winter = previous.singleWhere((e) => e.title == '2025학년도 동계 계절학기 수업');
    expect(winter.sourceId, '2025-12-22T00:00:00.000:2025학년도 동계 계절학기 수업');
    expect(
      current.singleWhere((e) => e.title == winter.title).sourceId,
      winter.sourceId,
    );
  });

  test('INHA profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000169',
      'academyinfo:0000169',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '인하대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'inha',
      );
    }
  });

  test(
    'INHA rejects unavailable year, missing preceding December and malformed range',
    () {
      final body = fixture();
      expect(() => InhaAcademicSource.parse(body, 2025), throwsFormatException);
      expect(
        () => InhaAcademicSource.parse(
          body.replaceFirst('월 (2025년)', '월 (2024년)'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => InhaAcademicSource.parse(
          body.replaceFirst('12.08.(월)', '12.32.(월)'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => InhaAcademicSource.parse(
          body.replaceFirst('01.06.(화)', '01.04.(화)'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'INHA term defaults are bounded by their named official calendar rows',
    () async {
      final defaults = await TimetablePeriodDefaults.load(
        bundle: _FileBundle(),
      );
      final raw =
          jsonDecode(
                File('assets/timetable/term-periods.json').readAsStringSync(),
              )
              as Map;
      final expected = {
        '1': ('2026-03-02', '2026-06-19'),
        '여름': ('2026-06-22', '2026-07-15'),
        '2': ('2026-08-31', '2026-12-18'),
        '겨울': ('2026-12-21', '2027-01-13'),
      };
      final events = InhaAcademicSource.parse(fixture(), 2026);
      final university = (raw['additionalUniversities'] as List)
          .cast<Map>()
          .singleWhere((u) => u['university'] == 'inha');
      expect(defaults.periodsFor('inha'), hasLength(expected.length));
      for (final term in (university['terms'] as List).cast<Map>()) {
        final semester = term['semester'] as String;
        final period = defaults.periodFor(2026, semester, university: 'inha')!;
        expect(period.start, DateTime.parse(expected[semester]!.$1));
        expect(period.end, DateTime.parse(expected[semester]!.$2));
        final evidence = [
          for (final title in (term['sourceTitles'] as List).cast<String>())
            events.singleWhere((event) => event.title == title),
        ];
        final start = evidence
            .map((event) => event.start)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final end = evidence
            .map((event) => event.end)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .subtract(const Duration(days: 1));
        expect(period.start, start);
        expect(period.end, end);
        expect(period.contains(period.start), isTrue);
        expect(period.contains(period.end), isTrue);
        expect(
          period.contains(period.start.subtract(const Duration(days: 1))),
          isFalse,
        );
        expect(
          period.contains(period.end.add(const Duration(days: 1))),
          isFalse,
        );
      }
      expect(defaults.periodFor(2025, '2', university: 'inha'), isNull);
      expect(defaults.periodFor(2027, '1', university: 'inha'), isNull);
    },
  );
}
