import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-s/bu-contract-scoped-clock-v2-20261009';
dynamic read(String name) {
  final path = name == 'baekseok-unknown-2026-2.contract-clock-v2.json'
      ? 'assets/timetable/baekseok-unknown-2026-2.json'
      : '$dir/$name';
  final data = jsonDecode(File(path).readAsStringSync());
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
  final raw =
      read('baekseok-unknown-2026-2.contract-clock-v2.json')
          as Map<String, dynamic>;
  final base = read('baseline2571-current-asset.json') as Map;
  final proof = read('independent-contract-literal-proof.json') as Map;
  final model = UniversityDataset.fromJson(raw);
  const dates = <int, List<String>>{
    1: [
      '2026-09-07',
      '2026-09-14',
      '2026-09-21',
      '2026-09-28',
      '2026-10-12',
      '2026-10-26',
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
      '2026-10-22',
      '2026-10-29',
      '2026-11-05',
      '2026-11-12',
      '2026-11-19',
      '2026-11-26',
      '2026-12-03',
      '2026-12-10',
    ],
  };
  const clocks = <int, List<int>>{
    1: [540, 590],
    2: [600, 650],
    3: [660, 710],
    4: [720, 770],
    5: [780, 830],
    6: [840, 890],
    7: [900, 950],
    8: [960, 1010],
    9: [1020, 1070],
  };
  test(
    'Twenty exact contract native rows and scoped direct clock260 actual dates',
    () {
      expect(model.courses, hasLength(2571));
      final native = read('contract20-native-source-rows.json') as List;
      final pdfProof = read('independent-public-pdf20-reextract.json') as Map;
      final gridProof =
          read('independent-actual-grid-exam-reextract.json') as Map;
      expect(pdfProof['currentPDFRowsIndependentlyReextracted'], 20);
      expect(gridProof['actualPDFGrid75RawCellsEqualCached'], true);
      expect(
        sha256
            .convert(File('$dir/2026_2_ear.pdf').readAsBytesSync())
            .toString(),
        pdfProof['pdfSHA256'],
      );
      expect(
        sha256
            .convert(
              File(
                '$dir/bu-current-contract-2026-2-clock-crop.png',
              ).readAsBytesSync(),
            )
            .toString(),
        proof['clockCropSHA256'],
      );
      final contracts = (raw['courses'] as List)
          .where(
            (c) =>
                (c['departments'] as List).length == 1 &&
                (c['departments'] as List).single == '계약학과',
          )
          .toList();
      expect(contracts, hasLength(20));
      var plans = 0;
      for (final c in contracts) {
        final n = native.singleWhere(
          (n) =>
              n['publishedCombinedCode'] == '${c['courseCode']}${c['section']}',
        );
        final v = n['values'] as List;
        expect(c['courseName'], v[3]);
        expect(c['professor'], v[7]);
        expect(c['sourceSchedule'], v[8]);
        expect(c['sourceClassroom'], v[9]);
        expect(c['classification'], v[1]);
        expect(c['credits'], double.parse(v[5]));
        expect(c['departmentRemarks']['계약학과'], v[10]);
        final m = RegExp(r'^([월화수목금])([1-9](?:,[1-9])*)$').firstMatch(v[8]);
        expect(m, isNotNull);
        final wd = '월화수목금'.indexOf(m!.group(1)!) + 1;
        final periods = m.group(2)!.split(',').map(int.parse).toList();
        final expected = dates[wd]!
            .map(
              (d) =>
                  '$d|$wd|${clocks[periods.first]![0]}|${clocks[periods.last]![1]}|${v[9]}',
            )
            .toSet();
        final actual = <String>{};
        for (final s in c['schedules']) {
          expect(DateTime.parse(s['date']).weekday, s['weekday']);
          expect(s['sourceWeekday'], wd);
          expect(s['sourcePeriodNumbers'], periods);
          expect(s['deliveryMode'], 'inPerson');
          actual.add(
            '${s['date']}|${s['weekday']}|${s['startMinute']}|${s['endMinute']}|${s['classroom']}',
          );
        }
        expect(actual, expected);
        expect(c['schedules'], hasLength(13));
        plans += actual.length;
        expect(c['period'], {
          'startDate': '2026-09-01',
          'endDate': '2026-12-14',
        });
        expect(
          c['scopedClockProof']['wholePrivateIdentifierAttachmentRetained'],
          false,
        );
      }
      expect(plans, 260);
      expect(proof['knownExactClosedContractMatches'], 0);
      expect(proof['knownExactScheduleChangesContractMatches'], 0);
      expect(raw['completionClaim'], false);
    },
  );
  test(
    'All other2551 objects equal and prior2 courses26 complete objects preserved',
    () {
      var unchanged = 0, oldPlans = 0;
      for (final b in base['courses']) {
        final c = (raw['courses'] as List).singleWhere(
          (c) => c['sourceId'] == b['sourceId'],
        );
        if (!((b['departments'] as List).length == 1 &&
            (b['departments'] as List).single == '계약학과')) {
          expect(c, b);
          unchanged++;
          oldPlans += (b['schedules'] as List).length;
          continue;
        }
        for (final k in (b as Map).keys) {
          if (![
            'departmentRemarks',
            'schedules',
            'scheduleStatus',
            'period',
          ].contains(k)) {
            expect(c[k], b[k]);
          }
        }
        expect(c['sourceEducationalMetadata'], b['sourceEducationalMetadata']);
        expect(c['campus'], 'unknown');
        expect(c['previousResearchDepartmentRemarks'], b['departmentRemarks']);
      }
      expect(unchanged, 2551);
      expect(oldPlans, 26);
    },
  );
  test(
    'All22 actual models286 meetings three defaults and fullDrive v2 roundtrip',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in model.courses) {
          final plans =
              (raw['courses'] as List).singleWhere(
                    (v) => v['sourceId'] == c.sourceId,
                  )['schedules']
                  as List;
          if (plans.isEmpty) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
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
            expect(
              saved.modeOn(m, m.teachingDate!),
              p['deliveryMode'] == 'inPerson' ? LectureMode.inPerson : mode,
            );
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
        expect(count, 286);
        expect(values, hasLength(22));
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
        expect(restored, hasLength(22));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      }
    },
  );
}
