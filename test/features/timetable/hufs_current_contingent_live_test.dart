import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-t/hufs-contingent-and-dated-live-v9-20261009/';
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

const tuesdays = [
  '09-01',
  '09-08',
  '09-15',
  '09-22',
  '09-29',
  '10-06',
  '10-13',
  '10-27',
  '11-03',
  '11-10',
  '11-17',
  '11-24',
  '12-01',
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
const liveDates = {'2026-09-01', '2026-09-22', '2026-10-06', '2026-11-10'};
void main() {
  test(
    'current school clock and semester source constrain reservation scope',
    () {
      final receipt = read(
        'work/university-research/catalog-t/hufs-partial-operation-v4-20261009/own-clock-calendar-education-receipt.json',
      );
      final guide = receipt['guides'].first;
      expect(
        sha256.convert(File(guide['sourceFile']).readAsBytesSync()).toString(),
        guide['SHA256'],
      );
      expect(
        guide['clockEducationExcerpt'],
        contains('09:00 10:00 11:00 12:00'),
      );
      expect(
        guide['clockEducationExcerpt'],
        contains('09:50 10:50 11:50 12:50'),
      );
      expect(
        receipt['calendarEducationExcerpt'],
        contains('10. 20(화) - 10. 26.(월)'),
      );
      expect(
        receipt['calendarEducationExcerpt'],
        contains('12. 8(화) - 12. 14(월) 제2학기 보강주간'),
      );
      final proof =
          jsonDecode(
                File(
                  '${root}independent6-contingent-dated-live-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      for (final p in proof) {
        final rule = p['nativeRules'].single;
        final periods = RegExp(r'\d+')
            .allMatches(p['baselineRow']['sourceSchedule'].split('(').first)
            .map((m) => int.parse(m.group(0)!))
            .toList();
        expect(rule['startMinute'], (periods.first + 8) * 60);
        expect(rule['endMinute'], (periods.last + 8) * 60 + 50);
        final eighth = p['educationPlan']['fields']['weekly']['8th'] as String;
        expect(eighth, anyOf(contains('중간'), contains('시험')));
      }
    },
  );
  test(
    'six exact own plans preserve all prior native objects and independently enumerated teaching dates',
    () {
      final proof =
          jsonDecode(
                File(
                  '${root}independent6-contingent-dated-live-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(6));
      final old = read('${root}hufs-seoul-baseline-v8.json');
      final now = read(
        '${root}hufs-seoul-2026-2.contingent-and-dated-live-v9.json',
      );
      final before = {for (final c in old['courses']) c['sourceId']: c};
      final ids = {for (final p in proof) p['sourceId']};
      var added = 0;
      for (final c in now['courses']) {
        final b = before[c['sourceId']];
        if (!ids.contains(c['sourceId'])) {
          expect(c, b);
          continue;
        }
        added++;
        final p = proof.singleWhere((p) => p['sourceId'] == c['sourceId']);
        final plan = read(p['sourcePlanPath'] as String);
        expect(plan, p['educationPlan']);
        expect(
          sha256
              .convert(File(p['sourcePlanPath'] as String).readAsBytesSync())
              .toString(),
          p['sourcePlanSHA256'],
        );
        expect(
          plan['fields']['schedule'].split('\n').first,
          c['sourceSchedule'],
        );
        expect(
          '${plan['fields']['methods']}${plan['fields']['notes']}',
          contains(p['conditionalEvidence']),
        );
        final restored = Map<String, dynamic>.from(c);
        for (final field in [
          'schedules',
          'scheduleStatus',
          'departmentRemarks',
        ]) {
          restored[field] = b[field];
        }
        expect(restored, b);
        expect(b['schedules'], isEmpty);
        final rule = p['nativeRules'].single;
        expect(c['schedules'].map((m) => m['date']).toList(), [
          for (final date in rule['weekday'] == 2 ? tuesdays : thursdays)
            '2026-$date',
        ]);
        for (final m in c['schedules']) {
          expect(m['weekday'], rule['weekday']);
          expect(m['startMinute'], rule['startMinute']);
          expect(m['endMinute'], rule['endMinute']);
          final isLive =
              c['courseCode'] == 'C012192' && liveDates.contains(m['date']);
          expect(m['classroom'], isLive ? '' : c['sourceClassroom']);
          expect(m['deliveryMode'], isLive ? 'liveOnline' : null);
        }
      }
      expect(added, 6);
      expect(
        now['courses'].singleWhere(
          (c) => c['courseCode'] == 'A071423',
        )['schedules'],
        isEmpty,
      );
      final global = read(
        '${root}hufs-global-2026-2.contingent-and-dated-live-v9.json',
      );
      expect(
        global,
        read(
          'work/university-research/catalog-t/hufs-fixed-time-cross-campus-v8-20261009/hufs-global-2026-2.fixed-time-cross-campus-v8.json',
        ),
      );
    },
  );
  test(
    'all2435 full three-mode Drive restore retains dated live overrides and native clocks',
    () {
      final all = [
        for (final campus in ['seoul', 'global'])
          ...UniversityDataset.fromJson(
            read(
              '${root}hufs-$campus-2026-2.contingent-and-dated-live-v9.json',
            ),
          ).courses,
      ];
      expect(all, hasLength(3372));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(2435));
      expect(scheduled.expand((c) => c.meetings).length, 35181);
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
          if (c.sourceId == 'hufs/seoul/2026/2/C012192/01') {
            expect(t.overrides, hasLength(4));
            for (final m in t.meetings) {
              expect(
                t.modeOn(m, DateTime.parse(m.date!)),
                liveDates.contains(m.date) ? LectureMode.liveOnline : mode,
              );
              expect(m.originalStartMinute, 720);
              expect(m.originalEndMinute, 890);
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
