import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet003b-twelve-explicit-live';
const literalMeetings = {
  "khu/2026/2/seoul/ECON406200": [
    {
      "date": "2026-10-28",
      "weekday": 3,
      "startMinute": 990,
      "endMinute": 1065,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-11-02",
      "weekday": 1,
      "startMinute": 990,
      "endMinute": 1065,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-12-02",
      "weekday": 3,
      "startMinute": 990,
      "endMinute": 1065,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-12-07",
      "weekday": 1,
      "startMinute": 990,
      "endMinute": 1065,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
  ],
  "khu/2026/2/seoul/ECON100401": [
    {
      "date": "2026-10-02",
      "weekday": 5,
      "startMinute": 630,
      "endMinute": 795,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-11-27",
      "weekday": 5,
      "startMinute": 630,
      "endMinute": 795,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
  ],
  "khu/2026/2/seoul/ICFI303900": [
    {
      "date": "2026-10-10",
      "weekday": 6,
      "startMinute": 540,
      "endMinute": 705,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-10-17",
      "weekday": 6,
      "startMinute": 540,
      "endMinute": 705,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-10-31",
      "weekday": 6,
      "startMinute": 540,
      "endMinute": 705,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-11-14",
      "weekday": 6,
      "startMinute": 540,
      "endMinute": 705,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-11-21",
      "weekday": 6,
      "startMinute": 540,
      "endMinute": 705,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
    {
      "date": "2026-12-05",
      "weekday": 6,
      "startMinute": 540,
      "endMinute": 705,
      "classroom": "",
      "deliveryMode": "liveOnline",
    },
  ],
};
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
    'three own current whole Zoom allocations preserve full4666 and full3mode Drive',
    () {
      final old = read('prior-seoul-whole.json');
      final raw = read('khu-seoul-2026-2.twelve-fixed-live-prepared.json');
      final oldmap = {for (final c in old['courses']) c['sourceId']: c};
      for (final c in raw['courses']) {
        final b = oldmap[c['sourceId']] as Map;
        final expected = literalMeetings[c['sourceId']];
        if (expected == null) {
          expect(c, b);
          continue;
        }
        for (final e in b.entries) {
          if (!{'schedules', 'departmentRemarks'}.contains(e.key)) {
            expect(c[e.key], e.value);
          }
        }
        final prefix = (b['schedules'] as List).length;
        expect((c['schedules'] as List).sublist(0, prefix), b['schedules']);
        expect((c['schedules'] as List).sublist(prefix), expected);
        for (final e in (b['departmentRemarks'] as Map).entries) {
          expect(
            c['departmentRemarks'][e.key].startsWith(e.value + '\n'),
            true,
          );
        }
      }
      final proof = read('proof.json');
      expect(proof['proofs'], hasLength(3));
      for (final p in proof['proofs']) {
        expect(p['previousWholeObject'], oldmap[p['sourceId']]);
        expect(p['originalWholeEducationPlan']['header'], [
          '2026학년도 2학기 강의계획서',
        ]);
        expect(p['originalWholeEducationPlan']['campus'], '서울');
      }
      final global =
          jsonDecode(
                File(
                  'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet003-next30/khu-global-2026-2.packet003-physical-groups-prepared.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final courses = [
        ...UniversityDataset.fromJson(raw).courses,
        ...UniversityDataset.fromJson(global).courses,
      ];
      expect(courses, hasLength(4666));
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2626));
      expect(courses.fold<int>(0, (a, c) => a + c.meetings.length), 49654);
      for (final e in literalMeetings.entries) {
        final c = courses.singleWhere((c) => c.sourceId == e.key);
        for (final r in e.value) {
          final m = c.meetings.singleWhere((m) => m.date == r['date']);
          expect(m.weekday, r['weekday']);
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(m.originalStartMinute, r['startMinute']);
          expect(m.originalEndMinute, r['endMinute']);
          expect(m.classroom, '');
        }
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
          final dates = literalMeetings[c.sourceId]
              ?.map((r) => r['date'])
              .toSet();
          if (dates != null) {
            for (var i = 0; i < saved.meetings.length; i++) {
              final m = saved.meetings[i];
              expect(
                saved.modeOn(m, m.teachingDate!),
                dates.contains(c.meetings[i].date)
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
        final encoded =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          encoded,
        ).materializeClasses();
        expect(restored, hasLength(2626));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
