import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-t/hufs-global-contingent-and-flipped-v11-20261009/';
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
  '10-29',
  '11-05',
  '11-12',
  '11-19',
  '11-26',
  '12-03',
];
void main() {
  test(
    'five Global ownplans, separate video deadline, exact native clocks and allprevious fullobjects',
    () {
      final proofs =
          jsonDecode(
                fixtureFile(
                  '${root}independent5-global-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proofs, hasLength(5));
      final old = read('${root}hufs-global-baseline-v10.json');
      final now = read(
        '${root}hufs-global-2026-2.global-contingent-and-flipped-v11.json',
      );
      final before = {for (final c in old['courses']) c['sourceId']: c};
      final ids = {for (final p in proofs) p['sourceId']};
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
        final p = proofs.singleWhere((p) => p['sourceId'] == c['sourceId']);
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
        for (final k in ['schedules', 'scheduleStatus', 'departmentRemarks']) {
          restored[k] = b[k];
        }
        expect(restored, b);
        final rule = p['originalRules'].single;
        final periods = RegExp(r'\d+')
            .allMatches(c['sourceSchedule'].split('(').first)
            .map((m) => int.parse(m.group(0)!))
            .toList();
        expect(rule['startMinute'], (periods.first + 8) * 60);
        expect(rule['endMinute'], (periods.last + 8) * 60 + 50);
        final expectedDates = rule['weekday'] == 1
            ? mondays
            : rule['weekday'] == 3
            ? wednesdays
            : thursdays;
        expect(c['schedules'].map((m) => m['date']).toList(), [
          for (final d in expectedDates) '2026-$d',
        ]);
        final flipped = c['courseCode'] == 'V432012';
        if (flipped) {
          expect(c['sourceSchedule'], '목 4 5 6 (0306)');
          expect(plan['fields']['methods'], contains('개별적으로 시청함(~목 4교시까지)'));
          expect(plan['fields']['methods'], contains('목 56교시'));
        }
        for (final m in c['schedules']) {
          expect(m['startMinute'], flipped ? 780 : rule['startMinute']);
          expect(m['endMinute'], rule['endMinute']);
          expect(m['classroom'], c['sourceClassroom']);
          expect(m['deliveryMode'], null);
        }
      }
      expect(added, 5);
      expect(
        read('${root}hufs-seoul-2026-2.global-contingent-and-flipped-v11.json'),
        read(
          'work/university-research/catalog-t/hufs-additional-contingent-v10-20261009/hufs-seoul-2026-2.additional-contingent-v10.json',
        ),
      );
    },
  );
  test(
    'frozen v11 all2443 wholethree-modeDrive preserves every clock, campus and prior dated live overrides',
    () {
      final all = [
        for (final campus in ['seoul', 'global'])
          ...UniversityDataset.fromJson(
            read(
              '${root}hufs-$campus-2026-2.global-contingent-and-flipped-v11.json',
            ),
          ).courses,
      ];
      expect(all, hasLength(3372));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(2443));
      expect(scheduled.expand((c) => c.meetings).length, 35279);
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
          final k = timetableCourseSyncKey(t);
          expect(records.containsKey(k), false);
          records[k] = TimetableSyncValue(
            {...t.toJson(), 'id': k},
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
