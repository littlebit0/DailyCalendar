import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-w/sookmyung-native-clock-pending-plan-review-v20-20261009/';
Map<String, dynamic> read(String path) {
  final actual =
      path.startsWith('${root}sookmyung-') &&
          path.endsWith('native-pending-plan-v20.json')
      ? 'assets/timetable/${path.split('/').last.split('.').first}.json'
      : path;
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
void main() {
  test(
    'four pending syllabus rows publish consistent actual professor and own physical clock; all1481 others preserved',
    () {
      final proof =
          jsonDecode(
                File(
                  '${root}independent4-native-clock-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(4));
      final ids = {for (final p in proof) p['sourceId']};
      var added = 0;
      for (final campus in ['first', 'second', 'unknown']) {
        final old = read('${root}sookmyung-$campus-baseline.json');
        final now = read(
          '${root}sookmyung-$campus-2026-2.native-pending-plan-v20.json',
        );
        final before = {for (final c in old['courses']) c['sourceId']: c};
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
          expect(c['metadata']['holdReasons'], isEmpty);
          final restored = jsonDecode(jsonEncode(c)) as Map<String, dynamic>;
          for (final f in ['schedules', 'scheduleStatus', 'remarks']) {
            restored[f] = b[f];
          }
          restored['metadata']['holdReasons'] = b['metadata']['holdReasons'];
          expect(restored, b);
          for (final source in p['nativeSources']) {
            expect(
              sha256.convert(File(source['file']).readAsBytesSync()).toString(),
              source['sha256'],
            );
            final raw = read(source['file']);
            expect(raw['year'].toString(), '2026');
            expect(raw['semester'].toString(), '2');
            expect(raw['rows'][source['index0']], source['row']);
            final v = source['values'];
            expect(v['강의형태'], '대면');
            expect(v['담당교수'], c['professor']);
            expect(v['강의시간'], c['sourceSchedule']);
            expect(v['과목번호'], c['courseCode']);
            expect(v['분반'], c['section']);
            expect(v['교수법'], '');
            expect(c['remarks'], contains(v['수강유의사항']));
          }
          expect(
            sha256
                .convert(File(p['calendarFile']).readAsBytesSync())
                .toString(),
            p['calendarSHA256'],
          );
          final cal = read(p['calendarFile']);
          expect(cal['officialCurrentCalendar']['nativeSelectedYear'], '2026');
          expect(
            cal['holidayOperation']['nativeCurrentOpeningFreshVerified'],
            true,
          );
          final expected = switch (c['courseCode']) {
            '21002177' => thursday,
            '21001065' => [...tuesday, ...thursday],
            _ => [...monday, ...wednesday],
          };
          final dates = [for (final d in expected) '2026-$d']..sort();
          expect(c['schedules'].map((m) => m['date']).toList(), dates);
          final rule = switch (c['courseCode']) {
            '21002177' => [1140, 1310, '프라임관105'],
            '21003076' => [900, 1010, '명신관318'],
            '21003994' => [540, 615, '명신관505'],
            '21001065' => [810, 885, '명신관516'],
            _ => throw StateError('Unexpected course'),
          };
          for (final m in c['schedules']) {
            expect(m['weekday'], DateTime.parse(m['date']).weekday);
            expect(c['sourceSchedule'], contains('월화수목금토일'[m['weekday'] - 1]));
            expect(m['startMinute'], rule[0]);
            expect(m['endMinute'], rule[1]);
            expect(m['classroom'], rule[2]);
            expect(m['deliveryMode'], null);
          }
          expect(c['metadata']['actualAttendanceConfirmed'], false);
          expect(c['metadata']['latestWholeClosureConfirmed'], false);
        }
      }
      expect(added, 4);
    },
  );
  test(
    'all1281 full three-mode Drive preserves source campus identities and explicit mode exceptions',
    () {
      final all = [
        for (final campus in ['first', 'second', 'unknown'])
          ...UniversityDataset.fromJson(
            read(
              '${root}sookmyung-$campus-2026-2.native-pending-plan-v20.json',
            ),
          ).courses,
      ];
      expect(all, hasLength(1485));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(1281));
      expect(scheduled.expand((c) => c.meetings).length, 23676);
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
