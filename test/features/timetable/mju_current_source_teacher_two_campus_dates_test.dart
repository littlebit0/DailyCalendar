import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-f/mju/current-teacher-held-night-weekday-correction-v33e-20261009';
const original =
    'work/university-research/catalog-f/mju/current-teacher-two-campus-direct-axis-v33-20261009';
dynamic read(String p) {
  final actual = p.endsWith('.teacher-corrected-v33e.json')
      ? 'assets/timetable/${p.split('/').last.split('.').first}.json'
      : p;
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
  test(
    'MJU 18 actual PDF weekday/hour cells; held night correction only; full 260/46/733 three-mode Drive',
    () {
      final proof = read(
        '$folder/all-eighteen-actual-pdf-day-and-hour-proof.json',
      );
      for (final x in proof['sourceInputs'] as List) {
        expect(
          sha256.convert(fixtureFile(x['path']).readAsBytesSync()).toString(),
          x['sha256'],
        );
      }
      expect(
        sha256
            .convert(
              fixtureFile(proof['priorCoordinateProofPath']).readAsBytesSync(),
            )
            .toString(),
        proof['priorCoordinateProofSHA256'],
      );
      final parts = <Map<String, dynamic>>[];
      final current = <String, dynamic>{};
      var unchanged = 0;
      for (final cap in ['humanities', 'natural', 'unknown']) {
        final before = cap == 'unknown'
            ? read('$original/prior-unknown-whole-archive.json')
            : read('$folder/prior-v33c-$cap-whole-archive.json');
        final after = cap == 'unknown'
            ? before
            : read('$folder/mju-$cap-2026-2.teacher-corrected-v33e.json');
        parts.add(after);
        expect(
          (after['courses'] as List).length,
          (before['courses'] as List).length,
        );
        for (var i = 0; i < (before['courses'] as List).length; i++) {
          final old = before['courses'][i];
          final now = after['courses'][i];
          expect(current.containsKey(now['sourceId']), false);
          current[now['sourceId']] = now;
          if (now['sourceId'] != proof['changedSourceId']) {
            expect(now, old);
            unchanged++;
          } else {
            final restored =
                jsonDecode(jsonEncode(now)) as Map<String, dynamic>;
            expect(
              restored['sourceEducation']['previousMistakenWeekdayResearchWholeCourseSnapshot'],
              old,
            );
            restored['sourceEducation'].remove(
              'previousMistakenWeekdayResearchWholeCourseSnapshot',
            );
            expect(
              restored['sourceEducation']['nativePublicCells']['printedDayColumn'],
              '월',
            );
            expect(restored['sourceSchedule'], '월 18:40–21:05');
            expect(restored['schedules'], isEmpty);
            expect(
              restored['sourceEducation']['holdReason'],
              'nativeClassMarkedUndecided',
            );
            restored['sourceSchedule'] = old['sourceSchedule'];
            restored['sourceEducation']['nativePublicCells']['printedDayColumn'] =
                old['sourceEducation']['nativePublicCells']['printedDayColumn'];
            restored['departmentRemarks'] = old['departmentRemarks'];
            expect(restored, old);
          }
        }
      }
      expect(unchanged, 259);
      expect(current, hasLength(260));
      expect(proof['geometry'], hasLength(18));
      final xEdges = [117.897, 203.651, 289.405, 375.158, 460.912];
      for (final g in proof['geometry'] as List) {
        final day = g['actualNativeWeekday'] as int;
        final box = g['courseCellBBox'] as List;
        expect(box[0], closeTo(xEdges[day - 1], 0.01));
        expect(box[2], closeTo(xEdges[day], 0.01));
        expect(g['dayColumnBothBoundariesMatch'], true);
        expect(g['bothBoundariesExactlyAligned'], true);
        final axes = g['axisRows'] as List;
        expect(box[1], closeTo(axes.first['bbox'][1], 0.01));
        expect(box[3], closeTo(axes.last['bbox'][3], 0.01));
        final course = current[g['sourceId']];
        expect(
          course['sourceEducation']['nativePublicCells']['printedDayColumn'],
          g['actualDayHeader'],
        );
        for (final m in course['schedules'] as List) {
          expect(m['weekday'], day);
          expect(DateTime.parse(m['date']).weekday, day);
          expect(m.containsKey('deliveryMode'), false);
        }
      }
      final courses = parts
          .expand((p) => UniversityDataset.fromJson(p).courses)
          .toList();
      expect(courses, hasLength(260));
      final plans = courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(plans, hasLength(46));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 733);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = plans
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
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
        expect(restored, hasLength(46));
        expect(restored.map((c) => c.sourceId).toSet(), expected.keys.toSet());
        for (final c in restored) {
          expect(
            c.toJson()..remove('id'),
            expected[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.isValid, true);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
