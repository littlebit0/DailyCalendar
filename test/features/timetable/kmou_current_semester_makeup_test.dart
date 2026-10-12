import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/kmou-elecom-semester-makeup-v3-20261009';
dynamic read(String name) => jsonDecode(File('$dir/$name').readAsStringSync());
void main() {
  test("Actual packaged KMOU whole native courses equal frozen v3 source", () {
    final current =
        jsonDecode(
              File(
                "assets/timetable/kmou-unknown-2026-2.json",
              ).readAsStringSync(),
            )
            as Map;
    expect(
      current["courses"],
      (read("kmou-unknown-2026-2.semester-makeup-v3.json") as Map)["courses"],
    );
    expect(current["researchOnly"], false);
  });
  final raw =
      jsonDecode(
            File(
              'assets/timetable/kmou-unknown-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final baseline = read('prior13-current-asset-snapshot.json') as Map;
  final proof = read('independent-semester-literal-proof.json') as Map;
  final hwp = read('current2026-2-revised-grid.hwp.tables.json') as List;
  final priorSource = read('prior13-source-educational-tables.json') as Map;
  final model = UniversityDataset.fromJson(raw);
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
      '2026-12-14',
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
      '2026-11-12',
      '2026-11-19',
      '2026-11-26',
      '2026-12-03',
      '2026-12-09',
      '2026-12-10',
    ],
  };
  test('All30 native cells1196 literal semester and published makeup plans', () {
    expect(model.courses, hasLength(30));
    expect(raw['completionClaim'], false);
    expect(read('held-original-cells.json'), hasLength(8));
    expect(
      sha256
          .convert(
            File('$dir/current2026-2-revised-grid.hwp').readAsBytesSync(),
          )
          .toString(),
      'da96aa7e38bf2d2fd9272be8a7a9e51f7dc9260fe13955f361c0de71ec95ced1',
    );
    var count = 0;
    for (final c in raw['courses']) {
      expect(c['courseCode'], '');
      expect(c['section'], '');
      expect(c['credits'], null);
      expect(c['classification'], '');
      expect(c['campus'], 'unknown');
      final cp = (proof['proofByCourse'] as List).singleWhere(
        (v) => v['sourceId'] == c['sourceId'],
      );
      final expected = <String>{};
      for (final r in cp['sourceRecords']) {
        String header;
        if (c['publicEducationCells'] != null) {
          header = priorSource['tables'][r['table']][r['row']][0] as String;
          expect(
            priorSource['tables'][r['table']][r['row']][r['column']],
            contains(r['room']),
          );
        } else {
          final cells = hwp[0]['tables'][r['table']]['cells'] as List;
          header =
              (cells.singleWhere(
                        (v) => v['row'] == r['row'] && v['column'] == 0,
                      )['paragraphs']
                      as List)
                  .join(' / ');
          expect(
            (c['sourceEducation']['nativeParagraphs'] as List).join('\n'),
            contains(r['room']),
          );
        }
        expect(header, r['clockText']);
        final n = RegExp(
          r'\d+',
        ).allMatches(header).map((m) => int.parse(m[0]!)).toList();
        final pm = r['row'] >= 5 ? 720 : 0;
        final start = n[1] * 60 + n[2] + pm, end = n[3] * 60 + n[4] + pm;
        expect(end - start, 50);
        for (final date in dates[r['weekday']]!) {
          expected.add(
            '$date|$start|$end|${r['room']}|${r['table']}|${r['row']}|${r['column']}',
          );
        }
      }
      final actual = <String>{};
      for (final s in c['schedules']) {
        expect(DateTime.parse(s['date']).weekday, s['weekday']);
        if (s['date'] == '2026-12-09') {
          expect(s['weekday'], 3);
          expect(s['sourceWeekday'], 4);
          expect(s['makeupForDate'], '2026-11-05');
        }
        actual.add(
          '${s['date']}|${s['startMinute']}|${s['endMinute']}|${s['classroom']}|${s['sourceTable']}|${s['sourceRow']}|${s['sourceColumn']}',
        );
      }
      expect(actual, expected);
      expect(actual.length, (c['schedules'] as List).length);
      count += actual.length;
    }
    expect(count, 1196);
  });
  test('Original13 source fields and every original179 plan remain exact', () {
    for (final b in baseline['courses']) {
      final c = (raw['courses'] as List).singleWhere(
        (v) => v['sourceId'] == b['sourceId'],
      );
      for (final key in (b as Map).keys) {
        if (!['schedules', 'period', 'remarks'].contains(key)) {
          expect(c[key], b[key]);
        }
      }
      for (final plan in b['schedules']) {
        final restored = (c['schedules'] as List).singleWhere(
          (value) =>
              value['date'] == plan['date'] &&
              value['sourceTable'] == plan['sourceTable'] &&
              value['sourceRow'] == plan['sourceRow'] &&
              value['sourceColumn'] == plan['sourceColumn'],
        );
        expect(restored, plan);
      }
      expect(c['previousResearchRemarks'], b['remarks']);
    }
  });
  test(
    'Whole30/1196 actual models each default mode and full Drive v2 roundtrip',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in model.courses) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          final plans =
              (raw['courses'] as List).singleWhere(
                    (v) => v['sourceId'] == c.sourceId,
                  )['schedules']
                  as List;
          expect(saved.meetings, hasLength(plans.length));
          for (var i = 0; i < plans.length; i++) {
            final m = saved.meetings[i], p = plans[i];
            expect(m.date, p['date']);
            expect(m.weekday, p['weekday']);
            expect(m.originalStartMinute, p['startMinute']);
            expect(m.originalEndMinute, p['endMinute']);
            expect(m.classroom, p['classroom']);
            expect(saved.modeOn(m, m.teachingDate!), mode);
            expect(saved.period!.contains(m.teachingDate!), true);
            count++;
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        expect(count, 1196);
        expect(values, hasLength(30));
        final encoded =
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
          encoded,
        ).materializeClasses();
        expect(restored, hasLength(30));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      }
    },
  );
}
