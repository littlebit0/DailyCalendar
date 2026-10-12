// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const folder =
    'work/university-research/catalog-c/syu-current-career-native-clock-review-v5-20261009';
Map<String, dynamic> read(String name) {
  final actual = '$folder/$name';
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  if (data['courses'] is List) data['researchOnly'] = false;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

const literalDates =
    '2026-09-01 2026-09-08 2026-09-15 2026-09-22 2026-09-29 2026-10-13 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01';
const nursing = {
  '62',
  '65',
  '64',
  '63',
  '66',
  '67',
  '68',
  '69',
  '70',
  '71',
  '72',
  '1540',
};
const pt = {'296', '297', '302', '298', '305', '304', '303'};

void main() {
  test(
    'SYU scoped19 native identity and literal ownHH/date; all previous whole objects',
    () {
      final raw = read('syu-main-2026-2.scoped-career-own-clock-v5.json');
      final prior = read('prior-current-1391-94-956-baseline.json');
      final proof = read('independent-native-scoped-clock-date-proof.json');
      final old = {
        for (final r in prior['courses'] as List) (r as Map)['sourceId']: r,
      };
      final proofs = {
        for (final r in proof['proofs'] as List) (r as Map)['sourceId']: r,
      };
      final rows = raw['courses'] as List;
      expect(rows, hasLength(1391));
      expect(proofs, hasLength(19));
      expect(proof['literalTuesdayDates'], literalDates.split(' '));
      expect(raw['completionClaim'], false);
      expect(raw['researchOnly'], false);
      var preserved = 0;
      for (final value in rows) {
        final row = value as Map;
        final sourceId = row['sourceId'];
        final original = old[sourceId] as Map;
        final p = proofs[sourceId];
        if (p == null) {
          expect(row, original, reason: '$sourceId');
          preserved++;
          continue;
        }
        expect(p['originalWholeObject'], original);
        for (final key in [
          'sourceId',
          'campus',
          'academicYear',
          'semester',
          'courseCode',
          'courseName',
          'section',
          'professor',
          'classification',
          'departmentClassifications',
          'credits',
          'departmentCredits',
          'departments',
          'sourceSchedule',
          'sourceClassroom',
        ]) {
          expect(row[key], original[key], reason: '$sourceId/$key');
        }
        final education = row['sourceEducation'] as Map;
        final oldEducation = original['sourceEducation'] as Map;
        for (final key in oldEducation.keys) {
          expect(education[key], oldEducation[key], reason: '$sourceId/$key');
        }
        expect(
          education['previousResearchDepartmentRemarks'],
          original['departmentRemarks'],
        );
        expect(education['wholeUniversityClockConfirmed'], false);
        expect(education['actualOperatingVerified'], false);
        expect(
          p['nativeAllEducationalCells'],
          oldEducation['nativePublicCells'],
        );
        expect(p['sourceImagePublishedOfficialCourseCode'], '');
        expect(p['sourceImagePublishedOfficialSection'], '');
      }
      expect(preserved, 1372);
      final dataset = UniversityDataset.fromJson(raw);
      expect(
        dataset.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(113),
      );
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        1165,
      );
      for (final c in dataset.courses.where(
        (c) => proofs.containsKey(c.sourceId),
      )) {
        final nr = c.sourceId.split('/').last;
        expect(nursing.contains(nr) || pt.contains(nr), true);
        expect(c.code, '1006074');
        expect(c.section, '');
        expect(c.title, '인생설계와 진로 II');
        expect(c.campus, 'main');
        expect(c.meetings, hasLength(11));
        final start = nursing.contains(nr) ? 1020 : 780;
        final end = nursing.contains(nr) ? 1070 : 830;
        if (pt.contains(nr)) {
          expect(c.sourceClassroom, '');
        }
        expect(
          c.meetings
              .map(
                (m) =>
                    '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
              )
              .toSet(),
          literalDates
              .split(' ')
              .map((d) => '$d|2|$start|$end|${c.sourceClassroom}')
              .toSet(),
        );
        for (final m in c.meetings) {
          expect(DateTime.parse(m.date!).weekday, 2);
        }
      }
    },
  );
  test(
    'SYU full113 allthree user modes, complete Drive records and materialization',
    () {
      final dataset = UniversityDataset.fromJson(
        read('syu-main-2026-2.scoped-career-own-clock-v5.json'),
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in dataset.courses.where(
          (c) => c.hasSchedulableMeetings,
        )) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true, reason: c.sourceId);
          expect(t.defaultMode, mode);
          for (final m in t.meetings) {
            expect(t.modeOn(m, DateTime.parse(m.date!)), mode);
          }
          final key = timetableCourseSyncKey(t);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        expect(values, hasLength(113));
        final doc = TimetableSyncDocument.records(courses: values);
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), doc.toJson());
        for (final e in values.entries) {
          expect(restored.courses[e.key]!.value, e.value.value);
        }
        final classes = restored.materializeClasses();
        expect(classes, hasLength(113));
        expect(classes.map((c) => c.sourceId).toSet(), hasLength(113));
        expect(classes.fold<int>(0, (n, c) => n + c.meetings.length), 1165);
        for (final c in classes) {
          expect(c.isValid, true);
          final key = timetableCourseSyncKey(c);
          expect(c.toJson(), values[key]!.value);
          expect(c.defaultMode, mode);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
