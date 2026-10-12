import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-t/hufs-late-week-and-conditional-review-v13-20261009/';
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

const monday = [
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
const tuesday = [
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
const wednesday = [
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
const thursday = [
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
const friday = [
  '09-04',
  '09-11',
  '09-18',
  '10-02',
  '10-16',
  '10-30',
  '11-06',
  '11-13',
  '11-20',
  '11-27',
  '12-04',
];
void main() {
  test(
    '28 own fullplans individually reviewed as conditional future only, literal nativeclock/date scopes and3344 others unchanged',
    () {
      final proof =
          jsonDecode(
                File(
                  '${root}independent28-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(28));
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
            '${root}hufs-$campus-baseline-v12.json',
          )['courses'])
            c['sourceId']: c,
        };
        final now = read(
          '${root}hufs-$campus-2026-2.conditional-full-plans-v13.json',
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
          expect('${f['methods']}\n${f['notes']}', p['sourceEvidence']);
          final restored = Map<String, dynamic>.from(c);
          for (final key in [
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
          ]) {
            restored[key] = b[key];
          }
          expect(restored, b);
          final noMiddle = ['A04130201', 'O15212201'].contains(p['key']);
          expect(p['midtermOmitted'], !noMiddle);
          if (noMiddle) {
            expect(f['weekly']['8th'], '[공개 주차: 별도 확정 운영 날짜 없음]');
          } else {
            expect(
              RegExp(
                r'중간|mid',
                caseSensitive: false,
              ).hasMatch(f['weekly']['8th']),
              true,
            );
          }
          final expected = <Map<String, dynamic>>[];
          final native = RegExp(
            r'([월화수목금토일])\s*([\d\s]+)',
          ).allMatches(c['sourceSchedule'].split('(').first).toList();
          expect(native.length, (p['nativeRules'] as List).length);
          for (final match in native) {
            final day = '월화수목금토일'.indexOf(match[1]!) + 1;
            final periods = RegExp(
              r'\d+',
            ).allMatches(match[2]!).map((m) => int.parse(m.group(0)!)).toList();
            final days = switch (day) {
              1 => monday,
              2 => noMiddle ? [...tuesday, '10-20'] : tuesday,
              3 => wednesday,
              4 => thursday,
              5 => friday,
              _ => throw StateError('Unexpected nativeweekday'),
            };
            for (final date in days) {
              expected.add({
                'date': '2026-$date',
                'weekday': day,
                'startMinute': (periods.first + 8) * 60,
                'endMinute': (periods.last + 8) * 60 + 50,
                'classroom': c['sourceClassroom'],
              });
            }
          }
          expected.sort(
            (a, b) => (a['date'] as String).compareTo(b['date'] as String),
          );
          expect(c['schedules'], expected);
        }
      }
      expect(added, 28);
      final held =
          jsonDecode(
                File(
                  '${root}independent6-still-held-source-review.json',
                ).readAsStringSync(),
              )
              as List;
      expect(held, hasLength(6));
      for (final p in held) {
        final id = p['sourceId'] as String;
        final campus = id.split('/')[1];
        final course =
            (read(
                      '${root}hufs-$campus-2026-2.conditional-full-plans-v13.json',
                    )['courses']
                    as List)
                .singleWhere((c) => c['sourceId'] == id);
        expect(course['schedules'], isEmpty);
      }
    },
  );
  test(
    'frozen v13 all2477 full three-mode Drive retains native campus identity, all prior classes and explicit dated live overrides',
    () {
      final all = [
        for (final campus in ['seoul', 'global'])
          ...UniversityDataset.fromJson(
            read('${root}hufs-$campus-2026-2.conditional-full-plans-v13.json'),
          ).courses,
      ];
      expect(all, hasLength(3372));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(2477));
      expect(scheduled.expand((c) => c.meetings).length, 35749);
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
