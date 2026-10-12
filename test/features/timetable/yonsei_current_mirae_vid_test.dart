// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/yonsei-h2-vid-public-offerings-v10-20261009';
dynamic read(String name) {
  final actual = '$dir/$name';
  final data = jsonDecode(fixtureFile(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  final base = read('baseline-mirae-v9.json') as Map;
  final data = read('yonsei-mirae-2026-2.vid-v10.json') as Map<String, dynamic>;
  final all = data['courses'] as List;
  const identities = <String, (int, List<int>, String, int)>{
    'VID2006-01-01': (2, [5, 6, 7, 8], '청378', 13),
    'VID2006-02-01': (3, [1, 2, 3, 4], '청375', 14),
    'VID3033-01-01': (3, [1, 2, 3, 4], '청378', 20),
    'VID3033-02-01': (4, [5, 6, 7, 8], '청378', 21),
    'VID3036-01-01': (5, [1, 2, 3, 4], '청378', 23),
    'VID3036-02-01': (2, [6, 7, 8, 9], '청477', 24),
    'VID4002-01-01': (4, [1, 2, 3, 4], '청477', 27),
    'VID4002-02-01': (4, [1, 2, 3, 4], '청375', 28),
  };
  const dates = <int, List<String>>{
    1: [
      '2026-09-07',
      '2026-09-14',
      '2026-09-21',
      '2026-09-28',
      '2026-10-12',
      '2026-10-19',
      '2026-11-02',
      '2026-11-09',
      '2026-11-16',
      '2026-11-23',
      '2026-11-30',
      '2026-12-07',
    ],
    2: [
      '2026-09-01',
      '2026-09-08',
      '2026-09-15',
      '2026-09-22',
      '2026-09-29',
      '2026-10-06',
      '2026-10-13',
      '2026-10-27',
      '2026-11-03',
      '2026-11-10',
      '2026-11-17',
      '2026-11-24',
      '2026-12-01',
    ],
    3: [
      '2026-09-02',
      '2026-09-09',
      '2026-09-16',
      '2026-09-23',
      '2026-09-30',
      '2026-10-07',
      '2026-10-14',
      '2026-10-28',
      '2026-11-04',
      '2026-11-11',
      '2026-11-18',
      '2026-11-25',
      '2026-12-02',
    ],
    4: [
      '2026-09-03',
      '2026-09-10',
      '2026-09-17',
      '2026-10-01',
      '2026-10-08',
      '2026-10-15',
      '2026-10-29',
      '2026-11-05',
      '2026-11-12',
      '2026-11-19',
      '2026-11-26',
      '2026-12-03',
    ],
    5: [
      '2026-09-04',
      '2026-09-11',
      '2026-09-18',
      '2026-10-02',
      '2026-10-16',
      '2026-10-30',
      '2026-11-06',
      '2026-11-13',
      '2026-11-20',
      '2026-11-27',
      '2026-12-04',
    ],
  };
  const clocks = <int, List<int>>{
    0: [480, 530],
    1: [540, 590],
    2: [600, 650],
    3: [660, 710],
    4: [720, 770],
    5: [780, 830],
    6: [840, 890],
    7: [900, 950],
    8: [960, 1010],
    9: [1020, 1070],
    10: [1080, 1130],
  };
  test('Eight native exact department rows396 own dates and physical rooms', () {
    expect(
      sha256
          .convert(fixtureFile('$dir/offerings.xlsx').readAsBytesSync())
          .toString(),
      '6fde0a8551269f47178b711b5bce36f85c25a55ee03b483ae7fd99f485efba79',
    );
    final cells = read('workbook-extracted.json')['Sheet1']['rows'] as List;
    var total = 0;
    for (final entry in identities.entries) {
      final c = all.singleWhere(
            (c) => c['sourceEducation'][0]['subjtnbCorsePrcts'] == entry.key,
          ),
          e = c['sourceEducation'][0];
      final (wd, periods, room, row) = entry.value;
      final r = cells.singleWhere((r) => r['row'] == row)['cells'];
      expect(r['B$row'], c['courseCode']);
      expect(r['D$row'], int.parse(c['section']));
      expect(r['G$row'], c['professor']);
      expect(r['F$row'], c['credits']);
      expect(e['subjtClNm'], null);
      expect(e['rmvlcYn'], '0');
      expect(e['lessnSessnDivNm'], '학기');
      expect(e['prctsCorseDvclsNo'], '01');
      final expected = <String>{};
      for (final date in dates[wd]!) {
        for (var i = 0; i < periods.length; i++) {
          final period = periods[i];
          expected.add(
            '$date|$wd|${clocks[period]![0]}|${clocks[period]![1]}|$room|$period|${i < 2 ? 'lecture' : 'practice'}|inPerson',
          );
        }
      }
      final actual = <String>{};
      for (final s in c['schedules']) {
        expect(DateTime.parse(s['date']).weekday, s['weekday']);
        actual.add(
          '${s['date']}|${s['weekday']}|${s['startMinute']}|${s['endMinute']}|${s['classroom']}|${s['sourcePeriod']}|${s['sourceGroupKind']}|${s['deliveryMode']}',
        );
      }
      expect(actual, expected);
      expect(actual.length, (c['schedules'] as List).length);
      total += actual.length;
    }
    expect(total, 396);
  });
  test('Other1210whole and old994whole34972 preserved', () {
    var unchanged = 0, scheduled = 0, meetings = 0;
    for (final b in base['courses']) {
      final c = all.singleWhere((c) => c['sourceId'] == b['sourceId']);
      if (!identities.containsKey(
        b['sourceEducation'][0]['subjtnbCorsePrcts'],
      )) {
        expect(c, b);
        unchanged++;
        if ((b['schedules'] as List).isNotEmpty) {
          scheduled++;
          meetings += (b['schedules'] as List).length;
        }
      } else {
        for (final k in (b as Map).keys) {
          if (![
            'schedules',
            'scheduleStatus',
            'remarks',
            'departmentRemarks',
          ].contains(k)) {
            expect(c[k], b[k]);
          }
        }
      }
    }
    expect(unchanged, 1210);
    expect(scheduled, 994);
    expect(meetings, 34972);
  });
  test(
    'All1002 actual models35368 meetings three defaults andfullDrive v2 roundtrip',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        var total = 0;
        for (final c in UniversityDataset.fromJson(data).courses) {
          final plans =
              all.singleWhere((v) => v['sourceId'] == c.sourceId)['schedules']
                  as List;
          if (plans.isEmpty) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.note, c.remarks);
          expect(saved.isValid, true);
          expect(saved.defaultMode, mode);
          expect(saved.meetings, hasLength(plans.length));
          for (var i = 0; i < plans.length; i++) {
            final m = saved.meetings[i], p = plans[i];
            expect(m.date, p['date']);
            expect(m.weekday, p['weekday']);
            expect(m.originalStartMinute, p['startMinute']);
            expect(m.originalEndMinute, p['endMinute']);
            expect(m.classroom, p['classroom']);
            final forced = switch (p['deliveryMode']) {
              'inPerson' => LectureMode.inPerson,
              'liveOnline' => LectureMode.liveOnline,
              _ => mode,
            };
            expect(saved.modeOn(m, m.teachingDate!), forced);
            expect(saved.period!.contains(m.teachingDate!), true);
            total++;
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        expect(total, 35368);
        expect(values, hasLength(1002));
        final document =
            jsonDecode(
                  jsonEncode(
                    TimetableSyncDocument.records(
                      courses: values,
                      schemaVersion: 2,
                    ).toJson(),
                  ),
                )
                as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          document,
        ).materializeClasses();
        expect(restored, hasLength(1002));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      }
    },
  );
}
