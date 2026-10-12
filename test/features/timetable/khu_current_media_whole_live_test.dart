import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet004b-whole-media-live';
const sid = 'khu/2026/2/seoul/JCOMM000100';
const literalDates = [
  "2026-09-01",
  "2026-09-03",
  "2026-09-08",
  "2026-09-10",
  "2026-09-15",
  "2026-09-17",
  "2026-09-22",
  "2026-09-29",
  "2026-10-01",
  "2026-10-06",
  "2026-10-08",
  "2026-10-13",
  "2026-10-15",
  "2026-10-27",
  "2026-10-29",
  "2026-11-03",
  "2026-11-05",
  "2026-11-10",
  "2026-11-12",
  "2026-11-17",
  "2026-11-19",
  "2026-11-24",
  "2026-11-26",
  "2026-12-01",
  "2026-12-03",
  "2026-12-08",
  "2026-12-10",
];
dynamic read(String name) {
  final actual = '$dir/$name';
  final data = jsonDecode(File(actual).readAsStringSync());
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
    'own complete Zoom guidance exact HH27 dates native school fields and full3mode Drive',
    () {
      final old = read('prior-seoul-whole.json');
      final raw = read('khu-seoul-2026-2.media-live-prepared.json');
      final proof = read('proof.json');
      final prior = {for (final c in old['courses']) c['sourceId']: c};
      expect(proof['previousWholeObject'], prior[sid]);
      expect(proof['originalWholeEducationPlan']['header'], [
        '2026학년도 2학기 강의계획서',
      ]);
      expect(proof['originalWholeEducationPlan']['campus'], '서울');
      expect(proof['originalWholeEducationPlan']['lectureCode'], 'JCOMM000100');
      expect(
        (proof['wholeLivePublishedInstruction'][1] as String).contains(
          'zoom으로 진행되는 비대면수업이지만',
        ),
        true,
      );
      for (final c in raw['courses']) {
        final b = prior[c['sourceId']] as Map;
        if (c['sourceId'] != sid) {
          expect(c, b);
          continue;
        }
        for (final e in b.entries) {
          if (!{
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
            'semanticOperatingReview',
            'sourcePartialCoverage',
          }.contains(e.key)) {
            expect(c[e.key], e.value);
          }
        }
        expect(b['schedules'], isEmpty);
        expect(c['schedules'], [
          for (final d in literalDates)
            {
              'date': d,
              'weekday': DateTime.parse(d).weekday,
              'startMinute': 720,
              'endMinute': 795,
              'classroom': '',
              'deliveryMode': 'liveOnline',
            },
        ]);
        expect(c['departmentRemarks'], {
          for (final e in (proof['schoolRemainingRemarks'] as Map).entries)
            e.key: '${e.value as String}\n${proof['exactAddedResearchNotice'] as String}',
        });
        expect(c['sourcePartialCoverage'], true);
      }
      final global =
          jsonDecode(
                File(
                  'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet004-next50/khu-global-2026-2.packet004-physical-groups-prepared.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final courses = [
        ...UniversityDataset.fromJson(raw).courses,
        ...UniversityDataset.fromJson(global).courses,
      ];
      expect(courses, hasLength(4666));
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2641));
      expect(courses.fold<int>(0, (a, c) => a + c.meetings.length), 49940);
      final target = courses.singleWhere((c) => c.sourceId == sid);
      expect(target.meetings.map((m) => m.date).toList(), literalDates);
      for (final m in target.meetings) {
        expect(m.originalStartMinute, 720);
        expect(m.originalEndMinute, 795);
        expect([2, 4].contains(m.weekday), true);
        expect(m.classroom, '');
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
          if (c.sourceId == sid) {
            for (final m in saved.meetings) {
              expect(saved.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
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
        final encoded =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          encoded,
        ).materializeClasses();
        expect(restored, hasLength(2641));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
