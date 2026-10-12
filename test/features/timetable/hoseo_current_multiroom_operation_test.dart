// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const directory =
    'work/university-research/catalog-r/hoseo/single-run-multiroom-v4-20261009';
const baseline =
    'work/university-research/catalog-r/hoseo/full-term-ordinary-v3-20261008';
Map<String, dynamic> read(String path) {
  final actual = path.startsWith('$directory/hoseo-')
      ? 'work/university-research/resume-batch-20261010/before-projection/${path.split('/').last.split('.').first}.json'
      : path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  if (data['courses'] is List) {
    data['researchOnly'] = false;
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
    '21 literal two-room single native blocks preserve all prior sources and Drive modes',
    () {
      final audit = read('$directory/audit.json');
      final additions = {
        for (final r in audit['newCases'] as List) (r as Map)['sourceId']: r,
      };
      final proof = read('$baseline/educational-proof.json');
      final clock = <int, List<int>>{};
      int minutes(String value) =>
          int.parse(value.substring(0, 2)) * 60 + int.parse(value.substring(3));
      for (final raw
          in proof['currentClockEvidence']['validatedDayPeriods'] as List) {
        final row = raw as Map;
        clock[row['nativePeriod'] as int] = [
          minutes(row['start'] as String),
          minutes(row['end'] as String),
        ];
      }
      expect(clock.keys.toSet(), {1, 2, 3, 4, 5, 6, 7, 8});
      final excluded = (proof['excludedDates'] as List).cast<String>().toSet();
      final models = <UniversityCourse>[];
      var previousScheduled = 0;
      var previousDates = 0;
      var unchanged = 0;
      var newDates = 0;
      var nativeCount = 0;
      var rawCount = 0;
      for (final campus in ['asan', 'cheonan', 'unknown']) {
        final before = read(
          '$baseline/hoseo-$campus-2026-2.ordinary-planned.json',
        );
        final after = read(
          '$directory/hoseo-$campus-2026-2.single-run-multiroom-v4.json',
        );
        final oldRows = {
          for (final r in before['courses'] as List) (r as Map)['sourceId']: r,
        };
        expect((after['courses'] as List).length, oldRows.length);
        for (final raw in after['courses'] as List) {
          final course = raw as Map;
          final old = oldRows[course['sourceId']] as Map;
          nativeCount++;
          previousScheduled += (old['schedules'] as List).isNotEmpty ? 1 : 0;
          previousDates += (old['schedules'] as List).length;
          final metadata = course['metadata'] as Map;
          final original = metadata['originalEducationalRecords'] as List;
          rawCount += original.length;
          if (!additions.containsKey(course['sourceId'])) {
            expect(course, old);
            unchanged++;
            continue;
          }
          expect(old['schedules'], isEmpty);
          expect(
            metadata['originalEducationalRecords'],
            (old['metadata'] as Map)['originalEducationalRecords'],
          );
          for (final field in old.keys.where(
            (k) => ![
              'remarks',
              'metadata',
              'schedules',
              'scheduleStatus',
            ].contains(k),
          )) {
            expect(course[field], old[field]);
          }
          expect(course['campus'], 'unknown');
          expect(metadata['campusAllocationRoomConflict'], isFalse);
          expect(metadata['sourceRoomAllocationUnknown'], isTrue);
          expect(metadata['previousV3ResearchRemarks'], old['remarks']);
          final values = (original.first as Map)['values'] as List;
          for (final entry in original) {
            final v = (entry as Map)['values'] as List;
            expect(v[4], '대면수업');
            expect(v[8], anyOf('주간', '주간(천안)'));
            expect(v.sublist(9, 12), values.sublist(9, 12));
            if ((v[12] as String?)?.isNotEmpty ?? false) {
              expect(course['remarks'], contains(v[12]));
            }
          }
          final nativeTime = RegExp(
            r'^([월화수목금])([1-8])(?:~([1-8]))?$',
          ).firstMatch(values[9] as String)!;
          final day = '월화수목금'.indexOf(nativeTime.group(1)!) + 1;
          final first = int.parse(nativeTime.group(2)!);
          final last = int.parse(nativeTime.group(3) ?? nativeTime.group(2)!);
          final room = '강의실1: ${values[10]} / 강의실2: ${values[11]}';
          final expected = <Map<String, dynamic>>[];
          for (
            var date = DateTime(2026, 8, 31);
            !date.isAfter(DateTime(2026, 12, 18));
            date = date.add(const Duration(days: 1))
          ) {
            final key = date.toIso8601String().substring(0, 10);
            if (date.weekday == day && !excluded.contains(key)) {
              expected.add({
                'date': key,
                'weekday': day,
                'startMinute': clock[first]![0],
                'endMinute': clock[last]![1],
                'classroom': room,
              });
            }
          }
          expect(course['schedules'], expected);
          newDates += expected.length;
          expect(course['remarks'], contains('각 실 사용·배정 미확인'));
        }
        models.addAll(UniversityDataset.fromJson(after).courses);
      }
      expect(nativeCount, 2499);
      expect(rawCount, 2627);
      expect(additions.length, 21);
      expect(previousScheduled, 1497);
      expect(previousDates, 25860);
      expect(unchanged, 2478);
      expect(newDates, 324);
      expect(models.where((c) => c.meetings.isNotEmpty).length, 1518);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final saved = <String, TimetableClass>{};
        final values = <String, TimetableSyncValue>{};
        for (final course in models.where((c) => c.meetings.isNotEmpty)) {
          final actual = course.toTimetable(id: course.sourceId, mode: mode);
          expect(actual.isValid, isTrue);
          if (additions.containsKey(course.sourceId)) {
            for (final m in actual.meetings) {
              expect(actual.modeOn(m, DateTime.parse(m.date!)), mode);
            }
          }
          final key = timetableCourseSyncKey(actual);
          saved[key] = actual;
          values[key] = TimetableSyncValue(
            {...actual.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'hoseo-v4-research',
          );
        }
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())),
        );
        expect(restored.courses.length, 1518);
        for (final entry in saved.entries) {
          final actual = TimetableClass.fromJson(
            Map<String, dynamic>.from(
              restored.courses[entry.key]!.value as Map,
            ),
          );
          expect(actual.toJson(), {...entry.value.toJson(), 'id': entry.key});
          expect(actual.defaultMode, mode);
        }
      }
    },
  );
}
