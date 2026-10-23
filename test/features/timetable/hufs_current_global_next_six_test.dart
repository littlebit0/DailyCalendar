import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-t/hufs-global-next-six-review-v12-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
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

const mondays = [
  '09-07',
  '09-14',
  '09-21',
  '09-28',
  '10-12',
  '10-19',
  '11-02',
  '11-09',
  '11-16',
  '11-23',
  '11-30',
  '12-07',
];
const wednesdays = [
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
const thursdays = [
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
];
const fridays = [
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
    'six own current contingent plans, selective actual assessment scope and allprior preserved',
    () {
      final proof =
          jsonDecode(
                fixtureFile(
                  '${root}independent6-global-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(6));
      final ids = {for (final p in proof) p['sourceId']};
      final old = read('${root}hufs-global-baseline-v11.json');
      final now = read('${root}hufs-global-2026-2.global-next-six-v12.json');
      final before = {for (final c in old['courses']) c['sourceId']: c};
      var added = 0;
      final receipt = read(
        'work/university-research/catalog-t/hufs-partial-operation-v4-20261009/own-clock-calendar-education-receipt.json',
      );
      final guide = (receipt['guides'] as List).singleWhere(
        (g) => g['campus'] == 'global',
      );
      expect(
        sha256
            .convert(fixtureFile(guide['sourceFile']).readAsBytesSync())
            .toString(),
        guide['SHA256'],
      );
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
              .convert(fixtureFile(p['sourcePlanPath']).readAsBytesSync())
              .toString(),
          p['sourcePlanSHA256'],
        );
        expect(
          plan['fields']['schedule'].split('\n').first,
          c['sourceSchedule'],
        );
        expect(
          '${plan['fields']['methods']}${plan['fields']['notes']}',
          contains(p['sourceEvidence']),
        );
        final restored = Map<String, dynamic>.from(c);
        for (final f in ['schedules', 'scheduleStatus', 'departmentRemarks']) {
          restored[f] = b[f];
        }
        expect(restored, b);
        final middle = c['courseCode'] == 'Y911111';
        expect(p['midtermOmitted'], middle);
        if (middle) {
          expect(plan['fields']['weekly']['8th'], '중간시험 기간');
        } else {
          expect(plan['fields']['weekly']['8th'], '[공개 주차: 별도 확정 운영 날짜 없음]');
        }
        final rule = p['nativeRules'].single;
        final parts = RegExp(r'\d+')
            .allMatches(c['sourceSchedule'].split('(').first)
            .map((m) => int.parse(m.group(0)!))
            .toList();
        expect(rule['startMinute'], (parts.first + 8) * 60);
        expect(rule['endMinute'], (parts.last + 8) * 60 + 50);
        final dates = switch (rule['weekday']) {
          1 => mondays,
          3 => wednesdays,
          4 => thursdays,
          5 => fridays,
          _ => throw StateError('Unexpected nativeweekday'),
        };
        expect(c['schedules'].map((m) => m['date']).toList(), [
          for (final d in dates) '2026-$d',
        ]);
        for (final m in c['schedules']) {
          expect(m['startMinute'], rule['startMinute']);
          expect(m['endMinute'], rule['endMinute']);
          expect(m['classroom'], c['sourceClassroom']);
          expect(m['deliveryMode'], null);
          expect(m['date'].compareTo('2026-12-07') <= 0, true);
        }
        if (c['courseCode'] == 'N102073') {
          expect(plan['fields']['weekly']['4th'], contains('12.11'));
          expect(plan['fields']['weekly']['6th'], contains('12. 8'));
        }
      }
      expect(added, 6);
      expect(
        now['courses'].singleWhere(
          (c) => c['courseCode'] == 'A044644',
        )['schedules'],
        isEmpty,
      );
      expect(
        read('${root}hufs-seoul-2026-2.global-next-six-v12.json'),
        read(
          'work/university-research/catalog-t/hufs-global-contingent-and-flipped-v11-20261009/hufs-seoul-2026-2.global-contingent-and-flipped-v11.json',
        ),
      );
    },
  );
  test(
    'frozen v12 all2449 wholethree-modeDrive includes prior explicit live overrides and native campus identity',
    () {
      final all = [
        for (final campus in ['seoul', 'global'])
          ...UniversityDataset.fromJson(
            read('${root}hufs-$campus-2026-2.global-next-six-v12.json'),
          ).courses,
      ];
      expect(all, hasLength(3372));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(2449));
      expect(scheduled.expand((c) => c.meetings).length, 35354);
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
