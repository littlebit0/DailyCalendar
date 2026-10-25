import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/cau_academic_source.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture([int year = 2026]) =>
    File('test/fixtures/academic/cau-$year.json').readAsStringSync();

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  test('CAU requests the published undergraduate year list', () async {
    final source = CauAcademicSource(
      client: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/ajax/FR_SCH_SVC/ScheduleListData.do');
        expect(Uri.splitQueryString(r.body), {
          'SCH_YEAR': '2026',
          'SCH_SITE_NO': '2',
        });
        return http.Response.bytes(
          utf8.encode(fixture()),
          200,
          headers: {'content-type': 'text/html;charset=utf-8'},
        );
      }),
    );
    addTearDown(source.close);
    final events = await source.fetch(2026);
    expect(events, hasLength(82));
    final winter = events.singleWhere((e) => e.title == '2025년 겨울방학');
    expect(winter.start, DateTime(2025, 12, 22));
    expect(winter.end, DateTime(2026, 3, 1));
  });

  test('CAU access failure is an error, not an empty calendar', () async {
    final source = CauAcademicSource(
      client: MockClient((_) async => http.Response('', 500)),
    );
    addTearDown(source.close);
    await expectLater(source.fetch(2026), throwsFormatException);
    expect(
      () => CauAcademicSource.parse('{"data":[]}', 2026),
      throwsFormatException,
    );
  });

  test('every published CAU row is imported for each year', () {
    // (year, published rows, unique events, verbatim duplicate rows)
    for (final (year, published, unique, duplicates) in [
      (2025, 78, 77, 1),
      (2026, 82, 82, 0),
    ]) {
      final rows = (jsonDecode(fixture(year))['data'] as List).cast<Map>();
      expect(rows, hasLength(published));
      final keys = {
        for (final row in rows)
          [
            (row['SUBJECT'] as String).trim(),
            for (final f in ['START_Y', 'START_M', 'START_D'])
              int.parse(row[f] as String),
            for (final f in ['END_Y', 'END_M', 'END_D'])
              int.parse(row[f] as String),
          ].join('|'),
      };
      expect(keys, hasLength(unique));
      expect(rows.length - keys.length, duplicates);
      final events = CauAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(unique));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(unique));
      // The official list hides rows starting after the selected year.
      for (final row in rows) {
        expect(
          int.parse(row['START_Y'] as String),
          lessThanOrEqualTo(year),
          reason: '${row['SUBJECT']}',
        );
      }
    }
    expect(
      [2025, 2026].map((y) => (jsonDecode(fixture(y))['data'] as List).length),
      [78, 82],
    );
  });

  test(
    'CAU recurring holidays use displayed date fields rather than old epochs',
    () {
      final body = fixture();
      final events = CauAcademicSource.parse(body, 2026);
      expect(events.length, 82);
      final holiday = events.singleWhere((e) => e.title == '신정(공휴일)');
      expect(holiday.start, DateTime(2026, 1, 1));
      expect(holiday.end, DateTime(2026, 1, 2));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final invalid = jsonDecode(body) as Map<String, dynamic>;
      invalid['data'][0]['START_D'] = '32';
      expect(
        () => CauAcademicSource.parse(jsonEncode(invalid), 2026),
        throwsFormatException,
      );
      expect(() => CauAcademicSource.parse(body, 2025), throwsFormatException);
    },
  );

  test('CAU verbatim duplicate row is one event with one identity', () {
    final events = CauAcademicSource.parse(fixture(2025), 2025);
    final applications = events
        .where((e) => e.title == '2026년 1학기 전공개방모집 희망전공 신청')
        .toList();
    expect(applications, hasLength(1));
    expect(applications.single.start, DateTime(2025, 12, 1));
    expect(applications.single.end, DateTime(2025, 12, 6));
    expect(applications.single.sourceId, '2025:2026년 1학기 전공개방모집 희망전공 신청:0');
  });

  test('CAU row order does not change same-title identities', () {
    final body = fixture();
    String key(AcademicEvent e) => '${e.title}|${e.start}|${e.end}';
    final original = {
      for (final e in CauAcademicSource.parse(body, 2026)) key(e): e.sourceId,
    };
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    decoded['data'] = (decoded['data'] as List).reversed.toList();
    final reordered = CauAcademicSource.parse(jsonEncode(decoded), 2026);
    expect(
      reordered.map((e) => e.sourceId).toSet(),
      hasLength(reordered.length),
    );
    for (final e in reordered) {
      expect(e.sourceId, original[key(e)], reason: key(e));
    }
    expect(
      original.values.where((id) => id.endsWith(':1')),
      isNotEmpty,
      reason: 'fixture must contain same-title rows',
    );
  });

  test('CAU profiles for both campuses resolve to its registered calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000175', null),
      ('institution:academyinfo:0000175', 'academyinfo:0000175'),
      ('institution:academyinfo:0000175', 'academyinfo:0000174'),
      ('academyinfo:0000175', null),
      ('academyinfo:0000174', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '중앙대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        'cau',
        reason: '$universityId $campusId',
      );
    }
  });

  test(
    'CAU term defaults are bounded by their named official calendar rows',
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
        '1': ('2026-03-03', '2026-06-22'),
        '여름': ('2026-06-24', '2026-07-15'),
        '2': ('2026-09-01', '2026-12-21'),
        '겨울': ('2026-12-23', '2027-01-15'),
      };
      final events = CauAcademicSource.parse(fixture(), 2026);
      final university = (raw['additionalUniversities'] as List)
          .cast<Map>()
          .singleWhere((u) => u['university'] == 'cau');
      expect(defaults.periodsFor('cau'), hasLength(expected.length));
      for (final term in (university['terms'] as List).cast<Map>()) {
        final semester = term['semester'] as String;
        final period = defaults.periodFor(2026, semester, university: 'cau')!;
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
      expect(defaults.periodFor(2025, '2', university: 'cau'), isNull);
      expect(defaults.periodFor(2027, '1', university: 'cau'), isNull);
    },
  );
}
