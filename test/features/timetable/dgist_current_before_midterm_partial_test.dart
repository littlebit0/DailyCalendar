import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-r/dgist-before-midterm-own-teacher-weekly-partial-v3-20261009';
const targetId = 'dgist/unknown/2026/2/HSS221-01';
const dates = [
  '2026-08-25',
  '2026-08-27',
  '2026-09-01',
  '2026-09-03',
  '2026-09-08',
  '2026-09-10',
  '2026-09-15',
  '2026-09-17',
  '2026-09-22',
  '2026-09-29',
  '2026-10-01',
  '2026-10-06',
  '2026-10-08',
];
dynamic read(String path) {
  final actual =
      path.endsWith('/dgist-unknown-2026-2.before-midterm-partial-v3.json')
      ? 'assets/timetable/dgist-unknown-2026-2.json'
      : path;
  final data = jsonDecode(fixtureFile(actual).readAsStringSync());
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
  test('DGIST exact before-midterm allocation; entire 569/196/4071 and Drive', () {
    final proof = read(
      '$folder/independent-native-plan-calendar-and-whole-proof.json',
    );
    final baseline = fixtureFile('$folder/prior569-current-whole-archive.json');
    expect(
      sha256.convert(baseline.readAsBytesSync()).toString(),
      proof['baselineSHA256'],
    );
    for (final entry in (proof['sourceInputsSHA256'] as Map).entries) {
      expect(
        sha256
            .convert(fixtureFile(entry.key as String).readAsBytesSync())
            .toString(),
        entry.value,
      );
    }
    final raw = read(
      '$folder/dgist-unknown-2026-2.before-midterm-partial-v3.json',
    );
    final prior = read(baseline.path);
    final current = raw['courses'] as List;
    final old = prior['courses'] as List;
    expect(current, hasLength(569));
    expect(current.map((c) => c['sourceId']).toSet(), hasLength(569));
    final source = <String, Map<String, dynamic>>{};
    for (final year in ['2020', '2024', '2014']) {
      final rows =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-r/dgist2026-2-$year-current-recheck-20261008.json',
                ).readAsStringSync(),
              )
              as List;
      source[year] = {
        for (final row in rows) '${row['SBJT_NO']}-${row['CLSS_NO']}': row,
      };
    }
    var preserved = 0;
    for (var i = 0; i < current.length; i++) {
      final c = current[i];
      for (final variant
          in c['sourceEducationalMetadata']['curriculumVariants']) {
        final row =
            source[variant['curriculum']]!['${c['courseCode']}-${c['section']}'];
        expect(variant['fields'], row);
        expect(row['SHYY'], '2026');
        expect(row['SHTM_DCD'], 'CMN17.20');
        expect(row['ORGN_CLSF_NM'], '대학');
        expect(c['sourceSchedule'], row['TLSN_TIME']);
        expect(c['professor'], row['PROF_NM']);
      }
      if (c['sourceId'] != targetId) {
        expect(c, old[i]);
        preserved++;
        continue;
      }
      expect(old[i], proof['priorTargetWhole']);
      final restored = Map<String, dynamic>.from(c as Map);
      expect(
        restored['previousResearchDepartmentRemarks'],
        old[i]['departmentRemarks'],
      );
      restored['departmentRemarks'] = restored.remove(
        'previousResearchDepartmentRemarks',
      );
      restored['scheduleStatus'] = old[i]['scheduleStatus'];
      restored['schedules'] = old[i]['schedules'];
      if ((old[i] as Map).containsKey('period')) {
        restored['period'] = old[i]['period'];
      } else {
        restored.remove('period');
      }
      restored.remove('sourcePartialOperationEvidence');
      expect(restored, old[i]);
    }
    expect(preserved, 568);
    final c = current.singleWhere((c) => c['sourceId'] == targetId);
    final plan = proof['currentPlanWhole']['fields'];
    expect(plan['SBJT_NO'], 'HSS221');
    expect(plan['CLSS_NO'], '01');
    expect(plan['INFO'], c['sourceSchedule']);
    expect(plan['LSN_MTHD'], contains('중간고사 이후'));
    expect(plan['LSN_MTHD'], contains('윤지성 교수'));
    expect(plan['LSN_MTHD'], contains('온라인 강의'));
    expect(c['professor'], '윤지성');
    expect(c['sourceClassroom'], 'E7 - 224');
    expect(c['period'], {'startDate': '2026-08-24', 'endDate': '2026-10-08'});
    final meetings = c['schedules'] as List;
    expect(meetings.map((m) => m['date']).toList(), dates);
    for (final m in meetings) {
      expect(m['weekday'], DateTime.parse(m['date'] as String).weekday);
      expect([2, 4], contains(m['weekday']));
      expect(m['startMinute'], 660);
      expect(m['endMinute'], 750);
      expect(m['originalStartMinute'], 660);
      expect(m['originalEndMinute'], 750);
      expect(m['classroom'], 'E7 - 224');
      expect(m.containsKey('deliveryMode'), false);
      expect(m['date'], isNot('2026-09-24'));
      expect(
        DateTime.parse(m['date'] as String).isBefore(DateTime(2026, 10, 12)),
        true,
      );
    }
    final model = UniversityDataset.fromJson(raw);
    final scheduled = model.courses
        .where((c) => c.meetings.isNotEmpty)
        .toList();
    expect(model.courses, hasLength(569));
    expect(scheduled, hasLength(196));
    expect(scheduled.expand((c) => c.meetings), hasLength(4071));
    final priorModel = UniversityDataset.fromJson(prior);
    final priorScheduled = priorModel.courses
        .where((c) => c.meetings.isNotEmpty)
        .toList();
    expect(priorScheduled, hasLength(195));
    expect(priorScheduled.expand((c) => c.meetings), hasLength(4058));
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final classes = scheduled
          .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
          .toList();
      final before = {
        for (final c in priorScheduled)
          c.sourceId: c.toTimetable(id: c.sourceId, mode: mode),
      };
      for (final c in classes.where((c) => c.sourceId != targetId)) {
        expect(c.toJson(), before[c.sourceId]!.toJson());
      }
      final doc = TimetableSyncDocument.legacy(
        courses: classes,
        termNames: {},
        activeYear: 2026,
        activeSemester: '2',
      );
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      ).materializeClasses();
      final expected = {for (final c in classes) c.sourceId: c};
      expect(restored, hasLength(196));
      expect(restored.map((c) => c.sourceId).toSet(), expected.keys.toSet());
      for (final c in restored) {
        expect(
          c.toJson()..remove('id'),
          expected[c.sourceId]!.toJson()..remove('id'),
        );
        expect(c.isValid, true);
        if (c.sourceId == targetId) {
          expect(c.period!.contains(DateTime(2026, 10, 13)), false);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    }
    expect(raw['completionClaim'], false);
  });
}
