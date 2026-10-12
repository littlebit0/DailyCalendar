import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet030b-own-group-specific-normal';
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

// Expected additions derive from own professor/week/native HH literals, never from candidate.
const expectedAdditions = {
  "khu/2026/2/seoul/PHYS110210": [
    {
      "date": "2026-10-20",
      "weekday": 2,
      "startMinute": 780,
      "endMinute": 890,
      "classroom": "스B245",
    },
    {
      "date": "2026-12-08",
      "weekday": 2,
      "startMinute": 540,
      "endMinute": 705,
      "classroom": "스B112",
    },
  ],
  "khu/2026/2/seoul/PHYS110202": [
    {
      "date": "2026-10-13",
      "weekday": 2,
      "startMinute": 630,
      "endMinute": 795,
      "classroom": "스B114(계단)",
    },
    {
      "date": "2026-10-23",
      "weekday": 5,
      "startMinute": 540,
      "endMinute": 650,
      "classroom": "스B245",
    },
  ],
  "khu/2026/2/seoul/PHYS110203": [
    {
      "date": "2026-10-13",
      "weekday": 2,
      "startMinute": 630,
      "endMinute": 795,
      "classroom": "스B114(계단)",
    },
    {
      "date": "2026-10-23",
      "weekday": 5,
      "startMinute": 660,
      "endMinute": 770,
      "classroom": "스B245",
    },
  ],
  "khu/2026/2/seoul/PHYS110201": [
    {
      "date": "2026-10-13",
      "weekday": 2,
      "startMinute": 630,
      "endMinute": 795,
      "classroom": "스B114(계단)",
    },
    {
      "date": "2026-10-21",
      "weekday": 3,
      "startMinute": 900,
      "endMinute": 1010,
      "classroom": "스B245",
    },
  ],
};
void main() {
  test(
    'KHU030b own teacher normal dates add8 preserve whole4666 and Drive3modes',
    () {
      final old = <String, dynamic>{};
      final raw = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final ca in ['seoul', 'global']) {
        final prior = read('packet030b-prior-$ca-whole.json');
        final candidate = read(
          'khu-$ca-2026-2.packet030b-physical-groups-prepared.json',
        );
        for (final c in prior['courses']) {
          old[c['sourceId']] = c;
        }
        for (final c in candidate['courses']) {
          raw[c['sourceId']] = c;
        }
        courses.addAll(UniversityDataset.fromJson(candidate).courses);
      }
      expect(old, hasLength(4666));
      expect(raw.keys.toSet(), old.keys.toSet());
      expect(read('packet030b-independent-proof.json')['proofs'], hasLength(8));
      var added = 0;
      for (final sid in old.keys) {
        final previous = old[sid] as Map;
        final current = raw[sid] as Map;
        final extra = expectedAdditions[sid];
        if (extra == null) {
          expect(current, previous);
          continue;
        }
        for (final key in previous.keys) {
          if (key != 'schedules') {
            expect(current[key], previous[key]);
          }
        }
        expect(current['schedules'], [
          ...(previous['schedules'] as List),
          ...extra,
        ]);
        added += extra.length;
      }
      expect(added, 8);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2843));
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 53328);
      for (final sid in expectedAdditions.keys) {
        final c = courses.singleWhere((c) => c.sourceId == sid);
        for (final e in expectedAdditions[sid]!) {
          final m = c.meetings.singleWhere(
            (m) =>
                m.date == e['date'] &&
                m.originalStartMinute == e['startMinute'],
          );
          expect(m.weekday, e['weekday']);
          expect(m.teachingDate!.weekday, e['weekday']);
          expect(m.originalEndMinute, e['endMinute']);
          expect(m.classroom, e['classroom']);
          expect(
            (raw[sid]['schedules'] as List).singleWhere(
              (v) =>
                  v['date'] == e['date'] &&
                  v['startMinute'] == e['startMinute'],
            )['deliveryMode'],
            isNull,
          );
        }
      }
      // Midterm theory/ final lab are not transferred from the other professor's plan.
      expect(
        (raw['khu/2026/2/seoul/PHYS110210']['schedules'] as List)
            .where((m) => m['date'] == '2026-10-20')
            .single['startMinute'],
        780,
      );
      expect(
        (raw['khu/2026/2/seoul/PHYS110210']['schedules'] as List)
            .where((m) => m['date'] == '2026-12-08')
            .single['startMinute'],
        540,
      );
      for (final sid in [
        'khu/2026/2/seoul/PHYS110202',
        'khu/2026/2/seoul/PHYS110203',
        'khu/2026/2/seoul/PHYS110201',
      ]) {
        expect(
          (raw[sid]['schedules'] as List)
              .where((m) => m['date'] == '2026-10-13')
              .single['startMinute'],
          630,
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
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(2843));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
