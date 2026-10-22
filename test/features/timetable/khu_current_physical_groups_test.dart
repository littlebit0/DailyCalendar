import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009';
Map<String, dynamic> read(String name) {
  final actual = name.endsWith('.packet001-physical-groups-prepared.json')
      ? '$dir/packet001b-exact-research-note-correction/${name.replaceAll('.packet001-physical-groups-prepared.json', '.packet001b-prepared.json')}'
      : '$dir/$name';
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

// Independent source calendar literals, not copied from candidate schedules.
const expectedDates = {
  "khu/2026/2/seoul/ICFI301400": [
    "2026-09-05",
    "2026-09-12",
    "2026-09-19",
    "2026-10-10",
    "2026-10-17",
    "2026-11-07",
    "2026-11-14",
    "2026-11-28",
  ],
  "khu/2026/2/seoul/ICFI301200": [
    "2026-09-05",
    "2026-09-12",
    "2026-09-19",
    "2026-11-07",
    "2026-11-14",
    "2026-11-21",
    "2026-11-28",
    "2026-12-12",
  ],
  "khu/2026/2/seoul/ICFI401700": [
    "2026-09-07",
    "2026-09-21",
    "2026-09-28",
    "2026-10-12",
    "2026-10-19",
    "2026-11-02",
    "2026-11-09",
    "2026-11-16",
    "2026-11-23",
    "2026-11-30",
    "2026-12-07",
  ],
  "khu/2026/2/seoul/ICFI202700": [
    "2026-09-12",
    "2026-09-19",
    "2026-10-10",
    "2026-10-17",
    "2026-11-14",
    "2026-11-28",
    "2026-12-12",
  ],
  "khu/2026/2/seoul/ICFI403601": [
    "2026-09-05",
    "2026-09-12",
    "2026-09-19",
    "2026-10-10",
    "2026-10-17",
    "2026-11-14",
    "2026-11-28",
    "2026-12-12",
  ],
  "khu/2026/2/seoul/ICFI302600": [
    "2026-09-05",
    "2026-09-12",
    "2026-09-19",
    "2026-10-10",
    "2026-10-17",
    "2026-11-07",
    "2026-11-14",
    "2026-11-28",
    "2026-12-12",
  ],
  "khu/2026/2/seoul/ICFI202701": [
    "2026-09-05",
    "2026-09-12",
    "2026-09-19",
    "2026-10-10",
    "2026-10-17",
    "2026-11-07",
    "2026-11-14",
    "2026-11-21",
  ],
  "khu/2026/2/seoul/PSC404400": [
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
  ],
  "khu/2026/2/seoul/ICFI401900": [
    "2026-09-03",
    "2026-09-17",
    "2026-10-01",
    "2026-10-08",
    "2026-10-15",
    "2026-10-29",
    "2026-11-05",
  ],
};
const originalHH = {
  'ICFI301400': [780, 945, '정305'],
  'ICFI301200': [540, 705, '정304'],
  'ICFI401700': [1170, 1305, '정309'],
  'ICFI202700': [540, 705, '정305'],
  'ICFI403601': [780, 945, '정304'],
  'ICFI302600': [780, 945, '정303'],
  'ICFI202701': [780, 945, '정302'],
  'PSC404400': [900, 975, '정305'],
  'ICFI401900': [1170, 1305, '정303'],
};
void main() {
  final preservedResearchNotes = {
    for (final row in read(
      'packet001b-exact-research-note-correction/exact-note-archive-proof.json',
    )['courses'])
      row['sourceId']: row['previousResearchDepartmentRemarks'],
  };

  test(
    'KHU packet001 nine exact physical groups preserve whole4666 and full3modeDrive',
    () {
      final old = <String, dynamic>{};
      final raw = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['seoul', 'global']) {
        final previous = read('prior-$campus-whole.json');
        final current = read(
          'khu-$campus-2026-2.packet001-physical-groups-prepared.json',
        );
        for (final c in previous['courses']) {
          old[c['sourceId']] = c;
        }
        for (final c in current['courses']) {
          raw[c['sourceId']] = c;
        }
        courses.addAll(UniversityDataset.fromJson(current).courses);
      }
      expect(old, hasLength(4666));
      expect(raw.keys.toSet(), old.keys.toSet());
      expect(
        read('packet001-review-decisions.json')['decisions'],
        hasLength(50),
      );
      var originalCourses = 0;
      var originalDates = 0;
      var added = 0;
      for (final c in courses) {
        final previous = old[c.sourceId] as Map;
        if (!expectedDates.containsKey(c.sourceId)) {
          expect(raw[c.sourceId], previous, reason: c.sourceId);
          if ((previous['schedules'] as List).isNotEmpty) {
            originalCourses++;
            originalDates += (previous['schedules'] as List).length;
          }
          continue;
        }
        expect(previous['schedules'], isEmpty);
        for (final entry in previous.entries) {
          if (!{
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
            'semanticOperatingReview',
          }.contains(entry.key)) {
            expect(
              raw[c.sourceId][entry.key],
              entry.value,
              reason: '${c.sourceId}/${entry.key}',
            );
          }
        }
        for (final entry in (previous['departmentRemarks'] as Map).entries) {
          expect(
            ((preservedResearchNotes[c.sourceId] ??
                        raw[c.sourceId]['departmentRemarks'])[entry.key]
                    as String)
                .startsWith(entry.value as String),
            true,
          );
        }
        expect(c.campus, 'seoul');
        expect(
          c.meetings.map((m) => m.date).toSet(),
          expectedDates[c.sourceId]!.toSet(),
        );
        expect(c.meetings.length, expectedDates[c.sourceId]!.length);
        final hh =
            originalHH[(previous['sourceEducationalVariants'] as List)
                .first['lecture_cd']]!;
        for (final m in c.meetings) {
          expect(m.originalStartMinute, hh[0]);
          expect(m.originalEndMinute, hh[1]);
          expect(m.classroom, hh[2]);
          expect(m.teachingDate!.weekday, m.weekday);
        }
        expect(
          (raw[c.sourceId]['schedules'] as List).every(
            (m) => m['deliveryMode'] == null,
          ),
          true,
        );
        added += c.meetings.length;
      }
      expect(originalCourses, 1947);
      expect(originalDates, 36548);
      expect(added, 91);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1956));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          for (var i = 0; i < saved.meetings.length; i++) {
            final m = saved.meetings[i];
            final published = raw[c.sourceId]['schedules'][i]['deliveryMode'];
            final expected = published == 'inPerson'
                ? LectureMode.inPerson
                : published == 'liveOnline'
                ? LectureMode.liveOnline
                : mode;
            expect(saved.modeOn(m, m.teachingDate!), expected);
            expect(saved.period!.contains(m.teachingDate!), true);
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final encoded =
            jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          encoded,
        ).materializeClasses();
        expect(restored, hasLength(1956));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
  test(
    'KHU nine generated warnings removed with exact source archive and actual notes preserved',
    () {
      final proof = read(
        'packet001b-exact-research-note-correction/exact-note-archive-proof.json',
      );
      final selected = {for (final row in proof['courses']) row['sourceId']};
      final warning = proof['removedExactResearchWarning'] as String;
      expect(selected, hasLength(9));
      var checked = 0;
      for (final campus in ['seoul', 'global']) {
        final original =
            jsonDecode(
                  fixtureFile(
                    '$dir/khu-$campus-2026-2.packet001-physical-groups-prepared.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final actual = read(
          'khu-$campus-2026-2.packet001-physical-groups-prepared.json',
        );
        final models = UniversityDataset.fromJson(actual).courses;
        for (var i = 0; i < (actual['courses'] as List).length; i++) {
          final row = Map<String, dynamic>.from(actual['courses'][i] as Map);
          if (selected.contains(row['sourceId'])) {
            final archive = preservedResearchNotes[row['sourceId']];
            expect(archive, original['courses'][i]['departmentRemarks']);
            expect(models[i].remarks, isNot(contains(warning)));
            final saved = models[i].toTimetable(
              id: models[i].sourceId,
              mode: LectureMode.inPerson,
            );
            expect(saved.note, models[i].remarks);
            expect(TimetableClass.fromJson(saved.toJson()).note, saved.note);
            row['departmentRemarks'] = archive;
            checked++;
          }
          expect(row, original['courses'][i]);
        }
      }
      expect(checked, 9);
    },
  );
}
