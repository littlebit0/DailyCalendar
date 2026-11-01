import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const base =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009';
const targetHH = {
  'khu/2026/2/global/GED11011G00': [5, 540, 705, ''],
};
dynamic read(String path) {
  final actual = '$base/$path';
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
    'KHU own Oct9 whole realtime class preserves physicals and all3 Drive modes',
    () {
      final previous = read(
        'packet017b-named-hangeul-live/prior-global-whole.json',
      );
      final raw = read(
        'packet017b-named-hangeul-live/khu-global-2026-2.exact-oct9-live-prepared.json',
      );
      final old = {for (final c in previous['courses']) c['sourceId']: c};
      expect(raw['courses'], hasLength(2042));
      for (final c in raw['courses']) {
        final prior = old[c['sourceId']] as Map;
        if (!targetHH.containsKey(c['sourceId'])) {
          expect(c, prior);
          continue;
        }
        for (final e in prior.entries) {
          if (!{'schedules', 'departmentRemarks'}.contains(e.key)) {
            expect(c[e.key], e.value);
          }
        }
        expect((c['schedules'] as List).sublist(0, 11), prior['schedules']);
        final hh = targetHH[c['sourceId']]!;
        expect((c['schedules'] as List).sublist(11), [
          {
            'date': '2026-10-09',
            'weekday': 5,
            'startMinute': hh[1],
            'endMinute': hh[2],
            'classroom': '',
            'deliveryMode': 'liveOnline',
          },
        ]);
        for (final entry in (prior['departmentRemarks'] as Map).entries) {
          expect(
            c['departmentRemarks'][entry.key].startsWith(entry.value + '\n'),
            true,
          );
        }
      }
      final courses = [
        ...UniversityDataset.fromJson(raw).courses,
        ...UniversityDataset.fromJson(
          read('khu-seoul-2026-2.packet017-physical-groups-prepared.json'),
        ).courses,
      ];
      expect(courses, hasLength(4666));
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2604));
      expect(courses.fold<int>(0, (a, c) => a + c.meetings.length), 49285);
      final proof = read('packet017b-named-hangeul-live/proof.json');
      expect(proof['proofs'], hasLength(1));
      for (final p in proof['proofs']) {
        final sid = p['sourceId'];
        expect(p['previousWholeObject'], old[sid]);
        expect(p['literalHH'], targetHH[sid]);
        expect(p['literalDate'], '2026-10-09');
        expect(p['exactPublishedRows'][0][0], '6주');
        expect(p['exactPublishedRows'][0][1], '10/6 ~ 10/12');
        expect(p['exactPublishedRows'][0][3], '한글날 - 실시간 ZOOM 수업');
        expect(p['originalWholeEducationPlan']['header'], [
          '2026학년도 2학기 강의계획서',
        ]);
        expect(p['originalWholeEducationPlan']['campus'], '국제');
        expect(
          p['originalWholeEducationPlan']['lectureCode'],
          (sid as String).split('/').last,
        );
        expect(p['namedHolidayDateResolutionNotPrintedMMDD'], isNull);
        expect(proof['namedHolidayDateResolutionNotPrintedMMDD'], true);
        expect(jsonEncode(p['ownCalendarProof']), contains('한글날'));
        expect(DateTime(2026, 10, 9).weekday, 5);
        final c = courses.singleWhere((c) => c.sourceId == sid);
        expect(c.meetings, hasLength(12));
        final m = c.meetings.singleWhere((m) => m.date == '2026-10-09');
        expect(m.weekday, 5);
        expect(m.originalStartMinute, targetHH[sid]![1]);
        expect(m.originalEndMinute, targetHH[sid]![2]);
        expect(m.classroom, '');
        expect(
          c.meetings.where(
            (m) => [
              '2026-09-25',
              '2026-10-23',
              '2026-10-30',
              '2026-12-18',
            ].contains(m.date),
          ),
          isEmpty,
        );
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          if (targetHH.containsKey(c.sourceId)) {
            for (final m in saved.meetings) {
              expect(
                saved.modeOn(m, m.teachingDate!),
                m.teachingDate == DateTime(2026, 10, 9)
                    ? LectureMode.liveOnline
                    : mode,
              );
              expect(saved.period!.contains(m.teachingDate!), true);
            }
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final decoded =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          decoded,
        ).materializeClasses();
        expect(restored, hasLength(2604));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
