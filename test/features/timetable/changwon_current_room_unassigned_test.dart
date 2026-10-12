import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-v/changwon-room-unassigned-native-clock-v4-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  return data;
}

const dates = {
  1: [
    '09-07',
    '09-14',
    '09-21',
    '09-28',
    '10-12',
    '10-19',
    '10-26',
    '11-02',
    '11-09',
    '11-16',
    '11-23',
    '11-30',
    '12-07',
  ],
  2: [
    '09-01',
    '09-08',
    '09-15',
    '09-22',
    '09-29',
    '10-06',
    '10-13',
    '10-20',
    '10-27',
    '11-03',
    '11-10',
    '11-17',
    '12-01',
  ],
  3: [
    '09-02',
    '09-09',
    '09-16',
    '09-23',
    '09-30',
    '10-07',
    '10-14',
    '10-21',
    '10-28',
    '11-04',
    '11-11',
    '11-18',
    '11-25',
    '12-02',
  ],
  4: [
    '09-03',
    '09-10',
    '09-17',
    '10-01',
    '10-08',
    '10-15',
    '10-22',
    '10-29',
    '11-05',
    '11-12',
    '11-19',
    '11-26',
    '12-03',
  ],
  6: [
    '09-05',
    '09-12',
    '09-19',
    '10-17',
    '10-24',
    '10-31',
    '11-07',
    '11-14',
    '11-21',
    '11-28',
    '12-05',
  ],
};
const rules = {
  'BSA0017': [
    [6, 540, 720, ''],
  ],
  'CNA0143': [
    [2, 990, 1080, '22414'],
    [4, 900, 990, ''],
  ],
  'OSA0106': [
    [1, 540, 720, ''],
    [3, 540, 720, ''],
  ],
  'OSA0108': [
    [1, 540, 720, ''],
    [3, 540, 720, ''],
  ],
};
void main() {
  test(
    'four native clocks keep missing rooms blank and preserve1750 whole other rows',
    () {
      final proof =
          jsonDecode(
                fixtureFile(
                  '${root}independent4-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(4));
      final ids = {for (final p in proof) p['sourceId']};
      final clock = read(
        'work/university-research/catalog-v/changwon-ordinary-weekly-reservations-v3/current-undergraduate-native-clock-education.json',
      );
      final periods = {
        for (final r in clock['nativePublishedPeriodClockRows'])
          r['nativePeriod']: r,
      };
      final calendar = read(
        'work/university-research/catalog-v/changwon-current-semester-calendar-20261008.json',
      );
      expect(
        calendar['rows'].any(
          (r) =>
              r['schdulTitle'] == '2026-2학기 개강' && r['bgnde'] == '2026/09/01',
        ),
        true,
      );
      expect(
        calendar['rows'].any(
          (r) => r['schdulTitle'] == '보강주' && r['bgnde'] == '2026/12/08',
        ),
        true,
      );
      for (final p in proof) {
        for (final b in p['nativeClockBlocks']) {
          expect(
            periods[b['nativePeriods'].first]['startMinute'],
            b['startMinute'],
          );
          expect(periods[b['nativePeriods'].last]['endMinute'], b['endMinute']);
        }
      }

      final before = read('${root}changwon-baseline-v3.json');
      final now = read(
        '${root}changwon-unknown-2026-2.room-unassigned-v4.json',
      );
      final old = {for (final c in before['courses']) c['sourceId']: c};
      expect(now['courses'].length, 1754);
      int added = 0;
      for (final c in now['courses']) {
        final b = old[c['sourceId']];
        if (!ids.contains(c['sourceId'])) {
          expect(c, b);
          continue;
        }
        added++;
        final p = proof.singleWhere((p) => p['sourceId'] == c['sourceId']);
        expect(p['baselineRow'], b);
        final plan = read(p['sourcePlanPath']);
        expect(plan, p['educationPlan']);
        expect(
          sha256
              .convert(fixtureFile(p['sourcePlanPath']).readAsBytesSync())
              .toString(),
          p['sourcePlanSHA256'],
        );
        expect(plan['fields']['강의시간(장소)'], c['sourceSchedule']);
        expect(plan['fields']['수업운영방식'], '대면');
        expect(c['campus'], 'unknown');
        for (final k in b.keys.where(
          (k) => ![
            'schedules',
            'scheduleStatus',
            'sourceEducation',
            'remarks',
          ].contains(k),
        )) {
          expect(c[k], b[k], reason: k);
        }
        final edu = Map<String, dynamic>.from(c['sourceEducation']);
        final oldEdu = Map<String, dynamic>.from(b['sourceEducation']);
        edu.remove('regularReservationReview');
        oldEdu.remove('regularReservationReview');
        expect(edu, oldEdu);
        expect(
          c['sourceEducation']['regularReservationReview']['nativeClockBlocks'],
          b['sourceEducation']['regularReservationReview']['nativeClockBlocks'],
        );
        final expected = <Map<String, dynamic>>[];
        for (final rule in rules[c['courseCode']]!) {
          for (final d in dates[rule[0]]!) {
            expected.add({
              'weekday': rule[0],
              'startMinute': rule[1],
              'endMinute': rule[2],
              'classroom': rule[3],
              'date': '2026-$d',
            });
          }
        }
        expected.sort(
          (a, b) => ('${a['date']}/${a['startMinute']}').compareTo(
            '${b['date']}/${b['startMinute']}',
          ),
        );
        final actual = [
          for (final m in c['schedules']) Map<String, dynamic>.from(m),
        ];
        actual.sort(
          (a, b) => ('${a['date']}/${a['startMinute']}').compareTo(
            '${b['date']}/${b['startMinute']}',
          ),
        );
        expect(actual, expected);
        expect(c['scheduleStatus'], 'scheduled');
      }
      expect(added, 4);
    },
  );
  test(
    'all1381 dated offerings preserve three user modes and full Drive roundtrip',
    () {
      final dataset = UniversityDataset.fromJson(
        read('${root}changwon-unknown-2026-2.room-unassigned-v4.json'),
      );
      final scheduled = dataset.courses
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      expect(scheduled, hasLength(1381));
      expect(scheduled.fold<int>(0, (n, c) => n + c.meetings.length), 28369);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final records = <String, TimetableSyncValue>{};
        for (final c in scheduled) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true);
          expect(t.defaultMode, mode);
          expect(TimetableClass.fromJson(t.toJson()).toJson(), t.toJson());
          final key = timetableCourseSyncKey(t);
          expect(records.containsKey(key), false);
          records[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        final doc = TimetableSyncDocument.records(courses: records);
        expect(
          TimetableSyncDocument.fromJson(
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
          ).toJson(),
          doc.toJson(),
        );
      }
    },
  );
}
