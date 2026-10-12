// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-v/changwon-full-plan-native-topic-conflict-correction-v6b-20261009';
dynamic read(String path) {
  final actual =
      path.endsWith('/changwon-unknown-2026-2.whole-plan-review-v6b.json')
      ? 'work/university-research/resume-batch-20261010/before-projection/changwon-unknown-2026-2.json'
      : path;
  final data = jsonDecode(File(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

const dates = <int, List<String>>{
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
  5: [
    '09-04',
    '09-11',
    '09-18',
    '10-02',
    '10-16',
    '10-23',
    '10-30',
    '11-06',
    '11-13',
    '11-20',
    '11-27',
    '12-04',
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
const rules = <String, List<List<Object>>>{
  'CNA0088-00': [
    [1, 900, 990, '22315'],
    [3, 990, 1080, '22315'],
  ],
  'GEA8583-00': [
    [2, 540, 630, 'B21116'],
    [4, 630, 720, 'B21116'],
  ],
  'ICA0173-00': [
    [2, 810, 900, '51308'],
    [4, 720, 810, '51308'],
  ],
  'MVA0074-60': [
    [3, 1100, 1250, '81405'],
  ],
  'SEA0239-00': [
    [1, 900, 990, '11409'],
    [2, 720, 810, '11310'],
  ],
  'CTA0217-00': [
    [2, 840, 1080, '34410'],
  ],
  'BMA1022-00': [
    [6, 540, 720, '81301'],
  ],
  'GEA3045-00': [
    [5, 540, 720, 'B21220'],
  ],
  'IRA0031-00': [
    [5, 540, 720, 'B21117'],
  ],
};
const exams = <String, String>{
  'CNA0088-00': '2026-10-07',
  'ICA0173-00': '2026-10-20',
  'BMA1022-00': '2026-10-24',
  'IRA0031-00': '2026-10-23',
};
void main() {
  test(
    'whole30 plans; exact9 semantic corrections/163 dates preserve1745 whole and source clock',
    () {
      final proof = read(
        '$folder/independent-native-plan-clock-date-whole-proof.json',
      );
      expect(
        sha256
            .convert(File('$folder/${proof['priorFile']}').readAsBytesSync())
            .toString(),
        proof['priorArchiveSHA256'],
      );
      for (final e in proof['sourceInputsSHA256'] as List) {
        expect(
          sha256
              .convert(File(e['path'] as String).readAsBytesSync())
              .toString(),
          e['sha256'],
        );
      }
      final old = read('$folder/${proof['priorFile']}');
      final raw = read('$folder/${proof['candidateFile']}');
      final oldBy = {for (final c in old['courses']) c['sourceId']: c};
      final frozenV6 = read('$folder/prior-v6-immutable-whole-archive.json');
      final frozenBy = {for (final c in frozenV6['courses']) c['sourceId']: c};
      final correctedBy = {for (final c in raw['courses']) c['sourceId']: c};
      var v6Preserved = 0;
      for (final entry in correctedBy.entries) {
        if ([
          'changwon/unknown/2026/2/CFA0133-00',
          'changwon/unknown/2026/2/CFA0133-01',
        ].contains(entry.key)) {
          expect(entry.value, oldBy[entry.key]);
          expect(entry.value['schedules'], isEmpty);
        } else {
          expect(entry.value, frozenBy[entry.key]);
          v6Preserved++;
        }
      }
      expect(v6Preserved, 1752);

      final reviews =
          jsonDecode(
                File(
                  '$folder/whole30-plan-review-education.json',
                ).readAsStringSync(),
              )
              as List;
      expect(reviews, hasLength(30));
      expect(reviews.where((r) => r['decision'] == 'approve'), hasLength(9));
      expect(
        reviews.where((r) => r['decision'] == 'pendingActualAllocation'),
        hasLength(19),
      );
      expect(
        reviews.where(
          (r) => r['decision'] == 'withdrawnDepartmentPracticalClockConflict',
        ),
        hasLength(2),
      );
      expect(raw['courses'], hasLength(1754));
      expect(
        (raw['courses'] as List).map((c) => c['sourceId']).toSet(),
        hasLength(1754),
      );
      final clock = read('$folder/own-current-period-clock.json');
      final periods = {
        for (final c in clock['nativePublishedPeriodClockRows'])
          c['nativePeriod']: c,
      };
      final cal = read('$folder/own-current-calendar.json');
      expect(
        cal['rows'].any(
          (r) =>
              r['schdulTitle'] == '2026-2학기 개강' && r['bgnde'] == '2026/09/01',
        ),
        true,
      );
      expect(
        cal['rows'].any(
          (r) => r['schdulTitle'] == '보강주' && r['bgnde'] == '2026/12/08',
        ),
        true,
      );
      var preserved = 0;
      var added = 0;
      for (final row in raw['courses']) {
        final c = Map<String, dynamic>.from(row as Map);
        final prior = oldBy[c['sourceId']];
        final key = '${c['courseCode']}-${c['section']}';
        if (!rules.containsKey(key)) {
          expect(c, prior);
          preserved++;
          continue;
        }
        final review = reviews.singleWhere((r) => r['key'] == key);
        final plan = read(review['sourceFile'] as String);
        expect(plan['fields'], review['wholeCurrentFields']);
        expect(plan['weekly'], review['wholeWeeklyRows']);
        expect(plan['fields']['학수번호'], c['courseCode']);
        expect(plan['fields']['분반'], c['section']);
        expect(plan['fields']['강의시간(장소)'], c['sourceSchedule']);
        expect(plan['fields']['수업운영방식'], '대면');
        expect(c['campus'], 'unknown');
        for (final source in c['sourceEducation']['originalPublicRows']) {
          expect(source['professor'], c['professor']);
          expect(source['schedule'], c['sourceSchedule']);
        }
        for (final block
            in c['sourceEducation']['regularReservationReview']['nativeClockBlocks']) {
          expect(
            periods[block['nativePeriods'].first]['startMinute'],
            block['startMinute'],
          );
          expect(
            periods[block['nativePeriods'].last]['endMinute'],
            block['endMinute'],
          );
        }
        final restored = Map<String, dynamic>.from(c);
        final archive = Map<String, dynamic>.from(
          restored.remove('previousResearchAnnotation') as Map,
        );
        expect(archive['remarks'], prior['remarks']);
        expect(archive['departmentRemarks'], prior['departmentRemarks']);
        restored['remarks'] = archive['remarks'];
        restored['departmentRemarks'] = archive['departmentRemarks'];
        restored['scheduleStatus'] = archive['scheduleStatus'];
        restored['schedules'] = prior['schedules'];
        if ((prior as Map).containsKey('period')) {
          restored['period'] = prior['period'];
        } else {
          restored.remove('period');
        }
        final edu = Map<String, dynamic>.from(
          restored['sourceEducation'] as Map,
        );
        edu.remove('sourceLexicalReview');
        edu['regularReservationReview'] =
            archive['previousRegularReservationReview'];
        restored['sourceEducation'] = edu;
        expect(restored, prior);
        final expected = <Map<String, dynamic>>[];
        for (final rule in rules[key]!) {
          for (final d in dates[rule[0] as int]!) {
            final date = '2026-$d';
            if (exams[key] == date) {
              continue;
            }
            expected.add({
              'weekday': rule[0],
              'startMinute': rule[1],
              'endMinute': rule[2],
              'classroom': rule[3],
              'date': date,
            });
          }
        }
        String sync(Map<dynamic, dynamic> m) =>
            '${m['date']}/${m['weekday']}/${m['startMinute']}/${m['endMinute']}/${m['classroom']}';
        expected.sort((a, b) => sync(a).compareTo(sync(b)));
        final actual = [
          for (final m in c['schedules']) Map<String, dynamic>.from(m),
        ];
        actual.sort((a, b) => sync(a).compareTo(sync(b)));
        expect(actual, expected);
        added += actual.length;
        expect(c['period'], {
          'startDate': '2026-09-01',
          'endDate': '2026-12-07',
        });
        expect(c['scheduleStatus'], 'scheduled');
        for (final m in actual) {
          expect(m['weekday'], DateTime.parse(m['date'] as String).weekday);
          expect(m.containsKey('deliveryMode'), false);
          expect(m['date'], isNot('2026-11-24'));
          if (key == 'IRA0031-00') {
            expect(m['date'], isNot('2026-09-25'));
            expect(m['date'], isNot('2026-10-09'));
          }
        }
      }
      expect(preserved, 1745);
      expect(added, 163);
      expect(raw['completionClaim'], false);
    },
  );
  test(
    'whole1390/28532 actual models, old1381/28369 deep and full3mode Drive',
    () {
      final proof = read(
        '$folder/independent-native-plan-clock-date-whole-proof.json',
      );
      final raw = read('$folder/${proof['candidateFile']}');
      final old = read('$folder/${proof['priorFile']}');
      final model = UniversityDataset.fromJson(raw);
      final before = UniversityDataset.fromJson(old);
      expect(model.courses, hasLength(1754));
      final scheduled = model.courses
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      final oldScheduled = before.courses
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      expect(scheduled, hasLength(1390));
      expect(scheduled.expand((c) => c.meetings), hasLength(28532));
      expect(oldScheduled, hasLength(1381));
      expect(oldScheduled.expand((c) => c.meetings), hasLength(28369));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final beforeBy = {
          for (final c in oldScheduled)
            c.sourceId: c.toTimetable(id: c.sourceId, mode: mode),
        };
        final records = <String, TimetableSyncValue>{};
        for (final c in scheduled) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true);
          if (beforeBy.containsKey(c.sourceId)) {
            expect(t.toJson(), beforeBy[c.sourceId]!.toJson());
          }
          if (rules.containsKey('${c.code}-${c.section}')) {
            expect(t.period!.contains(DateTime(2026, 8, 31)), false);
            expect(t.period!.contains(DateTime(2026, 12, 8)), false);
            for (final m in t.meetings) {
              expect(t.modeOn(m, DateTime.parse(m.date!)), mode);
            }
          }
          final key = timetableCourseSyncKey(t);
          expect(records.containsKey(key), false);
          records[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        final doc = TimetableSyncDocument.records(courses: records);
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), doc.toJson());
        final classes = restored.materializeClasses();
        expect(classes, hasLength(1390));
        final by = {
          for (final c in scheduled)
            c.sourceId: c.toTimetable(id: c.sourceId, mode: mode),
        };
        expect(classes.map((c) => c.sourceId).toSet(), by.keys.toSet());
        for (final c in classes) {
          expect(
            c.toJson()..remove('id'),
            by[c.sourceId]!.toJson()..remove('id'),
          );
        }
      }
    },
  );
}
