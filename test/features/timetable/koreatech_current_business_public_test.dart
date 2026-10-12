// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> readJson(String path) {
  if (path.endsWith('koreatech-unknown-2026-2.business-partial-v3.json')) {
    return jsonDecode(
          File(
            'work/university-research/resume-batch-20261010/before-projection/koreatech-unknown-2026-2.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
  }
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  if (path.endsWith('koreatech-unknown-2026-2.reservation-planned-v1.json')) {
    for (final row in data['courses']) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  test(
    'Koreatech department clock and six exact joins retain old 48 and Drive',
    () {
      const base = 'work/university-research/catalog-r/koreatech/';
      const root = '${base}business-direct-clock-room-followup-v3-20261009/';
      final old = readJson(
        '${base}koreatech-unknown-2026-2.reservation-planned-v1.json',
      );
      final raw = readJson(
        '${root}koreatech-unknown-2026-2.business-partial-v3.json',
      );
      final proofs =
          readJson('${root}independent-six-native-block-proof.json')['proofs']
              as List;
      final native =
          readJson(
                '${base}koreatech-2026-2-public-educational-rows-v1.json',
              )['rows']
              as List;
      final dataset = UniversityDataset.fromJson(raw);
      final oldRows = old['courses'] as List;
      final rows = raw['courses'] as List;
      final proofBy = {for (final p in proofs) p['sourceId']: p as Map};
      expect(dataset.courses, hasLength(791));
      expect(proofBy, hasLength(6));
      expect(raw['completionClaim'], isFalse);
      var preserved = 0;
      var preservedScheduled = 0;
      var newDates = 0;
      final scheduled = <UniversityCourse>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i] as Map;
        final historical = oldRows[i] as Map;
        final course = dataset.courses[i];
        expect(row['sourceId'], historical['sourceId']);
        expect(row['metadata']['originalEducationalFields'], native[i]);
        expect(row['campus'], 'unknown');
        expect(row['courseCode'], historical['courseCode']);
        expect(row['section'], historical['section']);
        expect(row['professor'], historical['professor']);
        expect(row['sourceSchedule'], historical['sourceSchedule']);
        final proof = proofBy[row['sourceId']];
        if (proof == null) {
          expect(row, historical);
          preserved++;
          if ((historical['schedules'] as List).isNotEmpty) {
            preservedScheduled++;
          }
        } else {
          expect(proof['courseCode'], row['courseCode']);
          expect(proof['printedSection'], row['section']);
          expect(proof['printedProfessor'], row['professor']);
          expect(proof['sourceRawSchedule'], row['sourceSchedule']);
          final expected = <Map<String, dynamic>>[];
          for (
            var date = DateTime(2026, 8, 31);
            !date.isAfter(DateTime(2026, 12, 6));
            date = date.add(const Duration(days: 1))
          ) {
            final day = date.toIso8601String().substring(0, 10);
            if ([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
              '2026-11-02',
            ].contains(day)) {
              continue;
            }
            for (final block in proof['blocks'] as List) {
              if (block['weekday'] == date.weekday) {
                expected.add({
                  ...Map<String, dynamic>.from(block as Map),
                  'date': day,
                });
              }
            }
          }
          expect(row['schedules'], expected);
          expect(expected, hasLength(proof['expectedDatedMeetings'] as int));
          newDates += expected.length;
          if (row['section'] == '02' || row['section'] == '03') {
            expect(course.meetings.every((m) => m.weekday == 4), isTrue);
          }
          expect(
            row['metadata']['currentBusinessGridProof']['nativeCodeNotPrintedInDepartmentPdf'],
            isTrue,
          );
          expect(
            (row['schedules'] as List).every(
              (s) => !(s as Map).containsKey('deliveryMode'),
            ),
            isTrue,
          );
        }
        if (course.hasSchedulableMeetings) {
          scheduled.add(course);
        }
      }
      expect(preserved, 785);
      expect(preservedScheduled, 48);
      expect(newDates, 118);
      expect(scheduled, hasLength(54));
      expect(scheduled.fold<int>(0, (n, c) => n + c.meetings.length), 1198);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final encoded =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          encoded,
        ).materializeClasses();
        expect(restored, hasLength(54));
        final byId = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final original = byId[c.sourceId]!;
          final expected = Map<String, Object?>.from(original.toJson());
          expected['id'] =
              'source/${jsonEncode([2026, '2', original.sourceId])}';
          expect(c.toJson(), expected);
          expect(c.defaultMode, mode);
          expect(c.isValid, isTrue);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
