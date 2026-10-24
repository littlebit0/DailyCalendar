// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-r/jeju/room-conflict-known-own-clock-v4-20261009/';
Map<String, dynamic> read(String name) {
  final actual = '$root$name';
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

// Literal independently transcribed current university regular period table.
(int, int) ownClock(String period) => switch (period) {
  '1' => (540, 590),
  '2' => (600, 650),
  '3' => (660, 710),
  '4' => (720, 770),
  '5' => (780, 830),
  '6' => (840, 890),
  '7' => (900, 950),
  '8' => (960, 1010),
  '9' => (1020, 1070),
  '10' => (1110, 1155),
  '11' => (1160, 1205),
  '12' => (1210, 1255),
  '13' => (1260, 1305),
  '14' => (1310, 1355),
  '1A' => (540, 615),
  '2B' => (630, 705),
  '4A' => (720, 795),
  '5B' => (810, 885),
  '7A' => (900, 975),
  '8B' => (990, 1065),
  _ => throw StateError('Unknown own period $period'),
};
void main() {
  test(
    'Jeju actual127 reviewed native source and27 room-only candidates preserve whole fields/date/HH',
    () {
      final source = read('source-3095-original-native-education.json');
      expect(source['sourceSnapshotDate'], '2026-07-29');
      final native = {
        for (final r in source['courses']) r['enrollmentNumber']: r,
      };
      final audit = read(
        'whole127-native-operating-and-room-conflict-proof.json',
      );
      expect(audit['allReviewRecords'], hasLength(127));
      final selected = {for (final r in audit['added']) r['sourceId']};
      expect(selected, hasLength(27));
      var oldScheduled = 0,
          oldDates = 0,
          changed = 0,
          newDates = 0,
          unchanged = 0;
      final all = <UniversityCourse>[];
      for (final campus in ['ara', 'sara', 'unknown']) {
        final baseline = read('prior-jeju-$campus-whole.json');
        final before = {for (final r in baseline['courses']) r['sourceId']: r};
        final raw = read('jeju-$campus-2026-2.room-conflict-own-clock-v4.json');
        final dataset = UniversityDataset.fromJson(raw);
        for (var i = 0; i < (raw['courses'] as List).length; i++) {
          final r = raw['courses'][i] as Map;
          final original = before[r['sourceId']] as Map;
          final model = dataset.courses[i];
          if ((original['schedules'] as List).isNotEmpty) {
            oldScheduled++;
            oldDates += (original['schedules'] as List).length;
          }
          if (!selected.contains(r['sourceId'])) {
            expect(r, original);
            unchanged++;
          } else {
            changed++;
            newDates += model.meetings.length;
            for (final k in original.keys) {
              if (![
                'schedules',
                'scheduleStatus',
                'remarks',
                'metadata',
              ].contains(k)) {
                expect(r[k], original[k]);
              }
            }
            final fields = r['metadata']['originalEducationalFields'];
            expect(fields, original['metadata']['originalEducationalFields']);
            for (final key in (original['metadata'] as Map).keys) {
              if (key != 'heldReason') {
                expect(r['metadata'][key], original['metadata'][key]);
              }
            }
            expect(fields, native[fields['enrollmentNumber']]);
            expect(fields['rawOperatingMethod'], '');
            expect(r['metadata']['sourceRoomSelected'], false);
            expect(
              r['metadata']['attendanceClassroomConfirmation'],
              'unconfirmed-conflicting-published-rooms',
            );
            expect(
              (r['remarks'] as String).contains(fields['rawTimeAndRoom']),
              true,
            );
            final groups = RegExp(
              r'([월화수목금])(\d+[AB]?)\[([^\[\]]+)\]',
            ).allMatches(fields['rawTimeAndRoom']);
            final unique = <String>{};
            for (final g in groups) {
              unique.add('${g[1]}|${g[2]}');
            }
            final expected = <String>{};
            for (final group in unique) {
              final parts = group.split('|');
              final weekday = '월화수목금'.indexOf(parts[0]) + 1;
              final time = ownClock(parts[1]);
              var day = DateTime(2026, 9, 1);
              while (day.weekday != weekday) {
                day = day.add(const Duration(days: 1));
              }
              while (!day.isAfter(DateTime(2026, 12, 7))) {
                final date = day.toIso8601String().substring(0, 10);
                if (!(date.compareTo('2026-10-20') >= 0 &&
                        date.compareTo('2026-10-26') <= 0) &&
                    ![
                      '2026-09-24',
                      '2026-09-25',
                      '2026-09-26',
                      '2026-10-03',
                      '2026-10-05',
                      '2026-10-09',
                    ].contains(date)) {
                  expected.add('$date|${time.$1}|${time.$2}|');
                }
                day = day.add(const Duration(days: 7));
              }
            }
            expect(
              model.meetings
                  .map(
                    (m) =>
                        '${m.date}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
                  )
                  .toSet(),
              expected,
            );
            expect(model.meetings, hasLength(expected.length));
            expect(model.meetings.every((m) => m.classroom.isEmpty), true);
          }
          if (model.meetings.isNotEmpty) all.add(model);
        }
      }
      expect(oldScheduled, 1858);
      expect(oldDates, 67478);
      expect(changed, 27);
      expect(newDates, 826);
      expect(unchanged, 3068);
      expect(all, hasLength(1885));
      expect(all.fold<int>(0, (n, c) => n + c.meetings.length), 68304);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = all
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
        final expected = {
          for (final c in classes)
            c.sourceId: {
              ...c.toJson(),
              'id':
                  'source/${jsonEncode([c.academicYear, c.semester, c.sourceId])}',
            },
        };
        expect(restored, hasLength(classes.length));
        expect(restored.map((c) => c.sourceId).toSet(), expected.keys.toSet());
        for (final c in restored) {
          expect(c.toJson(), expected[c.sourceId]);
          expect(c.defaultMode, mode);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
