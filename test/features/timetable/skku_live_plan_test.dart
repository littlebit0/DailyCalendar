import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public live plans retain virtual rooms, modes and exceptions in Drive',
    () {
      final courses = [
        for (final campus in ['humanities', 'naturalScience', 'icampus'])
          ...UniversityDataset.fromJson(
            jsonDecode(
                  File(
                    'assets/timetable/skku-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>,
          ).courses,
      ];
      const ids = {
        'GEDM001-E1',
        'GEDM001-E2',
        'GEDM001-E5',
        'GEDW001-24',
        'GEDW001-25',
        'GEDW001-58',
        'GEDW001-59',
      };
      const excluded = {
        'GEDM001-E2': {'2026-12-17'},
        'GEDW001-24': {'2026-10-24', '2026-11-07', '2026-11-14'},
        'GEDW001-25': {
          '2026-09-05',
          '2026-10-24',
          '2026-10-31',
          '2026-11-21',
          '2026-11-28',
        },
      };
      final live = courses
          .where((c) => ids.contains(c.codeAndSection))
          .toList();
      expect(live, hasLength(7));
      expect(live.expand((c) => c.meetings), hasLength(176));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in live) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
          for (final m in saved.meetings) {
            expect(m.classroom, isEmpty);
            expect(m.teachingDate!.weekday, m.weekday);
            expect(saved.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
            expect(excluded[c.codeAndSection] ?? {}, isNot(contains(m.date)));
            expect(
              classOccurrences([saved], [m.teachingDate!]).map((o) => o.mode),
              everyElement(LectureMode.liveOnline),
            );
          }
        }
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(
                jsonEncode(
                  TimetableSyncDocument.records(
                    courses: values,
                    schemaVersion: 2,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>,
        );
        expect(restored.courses.keys.toSet(), values.keys.toSet());
        for (final entry in restored.courses.entries) {
          expect(entry.value.value, values[entry.key]!.value);
        }
      }
      final newlyTimed = courses.singleWhere(
        (c) => c.codeAndSection == 'GEDW001-57',
      );
      expect(newlyTimed.meetings, hasLength(1));
      expect(newlyTimed.meetings.single.date, '2026-10-24');
      expect(newlyTimed.meetings.single.originalStartMinute, 630);
      expect(newlyTimed.meetings.single.originalEndMinute, 720);
      for (final id in [
        'GEDM001-E3',
        'GEDM001-E4',
        'GEDM001-E6',
        'GEDW001-23',
      ]) {
        expect(
          courses
              .singleWhere((c) => c.codeAndSection == id)
              .hasSchedulableMeetings,
          isFalse,
        );
      }
    },
  );
}
