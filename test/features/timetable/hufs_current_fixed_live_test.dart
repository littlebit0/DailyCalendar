// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-t/hufs-fixed-live-and-contingent-v14-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  if (data['courses'] is List) {
    data['researchOnly'] = false;
    data['productionIntegrationEnabled'] = true;
    data['completionClaim'] = false;
    data['wholeOperatingVerified'] = false;
    for (final c in data['courses']) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

const tuesday = [
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
  '11-24',
  '12-01',
];
const wednesday = [
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
];
const friday = [
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
];
void main() {
  test(
    'four own fixedclock fullplans distinguish actual live/mixed/conditional and all3368 others unchanged',
    () {
      final proof =
          jsonDecode(
                File(
                  '${root}independent4-fixed-live-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(4));
      final ids = {for (final p in proof) p['sourceId']};
      var added = 0;
      final receipt = read(
        'work/university-research/catalog-t/hufs-partial-operation-v4-20261009/own-clock-calendar-education-receipt.json',
      );
      for (final g in receipt['guides']) {
        expect(
          sha256.convert(File(g['sourceFile']).readAsBytesSync()).toString(),
          g['SHA256'],
        );
      }
      for (final campus in ['seoul', 'global']) {
        final before = {
          for (final c in read(
            '${root}hufs-$campus-baseline-v13.json',
          )['courses'])
            c['sourceId']: c,
        };
        final now = read(
          '${root}hufs-$campus-2026-2.fixed-live-and-contingent-v14.json',
        );
        expect(now['courses'].length, before.length);
        for (final c in now['courses']) {
          final b = before[c['sourceId']];
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
                .convert(File(p['sourcePlanPath']).readAsBytesSync())
                .toString(),
            p['sourcePlanSHA256'],
          );
          final f = plan['fields'];
          expect(f['schedule'].split('\n').first, c['sourceSchedule']);
          final restored = Map<String, dynamic>.from(c);
          for (final key in [
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
          ]) {
            restored[key] = b[key];
          }
          expect(restored, b);
          final live =
              c['courseCode'] == 'B073665' || c['courseCode'] == 'B073666';
          final middle = c['courseCode'] == 'D035291';
          expect(p['explicitWholeLiveOnline'], live);
          expect(p['midtermOmitted'], middle);
          if (live) {
            expect(f['methods'], contains('1대 1 온라인 실시간 수업'));
            expect(f['weekly']['8th'], '중간고사 : 없음');
          } else if (middle) {
            expect(f['notes'], contains('synchronous online classes'));
            expect(f['weekly']['8th'], '#Midterm');
          } else {
            expect(f['methods'], contains('* 필요시 온라인 수업 병행'));
            expect(f['weekly']['8th'], '[공개 주차: 별도 확정 운영 날짜 없음]');
          }
          final rule = switch (c['courseCode']) {
            'B054821' => [5, 900, 1010, '2210'],
            'D035291' => [2, 540, 710, 'C401'],
            'B073665' => [3, 900, 1010, 'C304'],
            'B073666' => [2, 900, 1010, '1307'],
            _ => throw StateError('Unexpected course'),
          };
          expect(c['sourceClassroom'], rule[3]);
          final days = switch (rule[0]) {
            2 => middle ? tuesday.where((d) => d != '10-20').toList() : tuesday,
            3 => wednesday,
            5 => friday,
            _ => throw StateError('Unexpected day'),
          };
          expect(c['schedules'].map((m) => m['date']).toList(), [
            for (final d in days) '2026-$d',
          ]);
          for (final m in c['schedules']) {
            expect(m['weekday'], rule[0]);
            expect(m['startMinute'], rule[1]);
            expect(m['endMinute'], rule[2]);
            expect(m['classroom'], live ? '' : rule[3]);
            expect(m['deliveryMode'], live ? 'liveOnline' : null);
          }
        }
      }
      expect(added, 4);
    },
  );
  test(
    'all2481 full three-mode Drive keeps explicit whole live over user defaults, source rooms and prior dated overrides',
    () {
      final all = [
        for (final campus in ['seoul', 'global'])
          ...UniversityDataset.fromJson(
            read(
              '${root}hufs-$campus-2026-2.fixed-live-and-contingent-v14.json',
            ),
          ).courses,
      ];
      expect(all, hasLength(3372));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(2481));
      expect(scheduled.expand((c) => c.meetings).length, 35802);
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
          if (c.code == 'B073665' || c.code == 'B073666') {
            expect(
              t.meetings.every(
                (m) =>
                    t.modeOn(m, m.teachingDate!) == LectureMode.liveOnline &&
                    m.classroom.isEmpty,
              ),
              true,
            );
            expect(c.sourceClassroom, isNotEmpty);
          }
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
