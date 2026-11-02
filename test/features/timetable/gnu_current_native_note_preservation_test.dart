import 'dart:convert';
import '../../support/gnu_break_slots.dart';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const currentDirectory =
    'work/university-research/catalog-r/gnu/native-note-preservation-v8-20261009';
const frozenV6 =
    'work/university-research/catalog-r/gnu/blank-room-and-live-source-followup-v6-20261009';
const frozenV5 =
    'work/university-research/catalog-r/gnu/remaining-campus-clock-followup-v5-20261008';
Map<String, dynamic> readJson(String path) {
  final actual = path.startsWith('$currentDirectory/gnu-')
      ? 'assets/timetable/${path.split('/').last.split('.').first}.json'
      : path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  if (data['courses'] is List) {
    data.addAll({
      'researchOnly': false,
      'productionIntegrationEnabled': true,
      'completionClaim': false,
      'wholeOperatingVerified': false,
    });
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
    'one missing native restriction restored without changing any other data',
    () {
      final models = <UniversityCourse>[];
      var nativeCount = 0;
      var changed = 0;
      var scheduled = 0;
      var dates = 0;
      var preservedV5Scheduled = 0;
      var preservedV5Dates = 0;
      final newCases = (readJson('$frozenV6/audit.json')['newCases'] as List)
          .map((r) => (r as Map)['sourceId'])
          .toSet();
      for (final campus in [
        'changwon',
        'chilam',
        'gajwa',
        'naedong',
        'tongyeong',
        'unknown',
      ]) {
        final current = readJson(
          '$currentDirectory/gnu-$campus-2026-2.native-note-v8.json',
        );
        final old = readJson(
          '$frozenV6/gnu-$campus-2026-2.blank-room-and-live-v6.json',
        );
        final earlier = readJson(
          '$frozenV5/gnu-$campus-2026-2.ordinary-university-guide-v5.json',
        );
        applyGnuBreakSlots(old);
        applyGnuBreakSlots(earlier);
        final oldRows = {
          for (final r in old['courses'] as List) (r as Map)['sourceId']: r,
        };
        final earlierRows = {
          for (final r in earlier['courses'] as List) (r as Map)['sourceId']: r,
        };
        expect(current.keys.toSet(), old.keys.toSet());
        for (final key in old.keys.where((k) => k != 'courses')) {
          expect(current[key], old[key]);
        }
        for (final r in current['courses'] as List) {
          final row = r as Map;
          final previous = oldRows[row['sourceId']] as Map;
          nativeCount++;
          if (row['sourceId'] == 'gnu/gajwa/2026-2/11000004-001') {
            changed++;
            expect(
              (row['metadata'] as Map)['originalEducationalFields']['remarks'],
              '[농학과[2]]',
            );
            expect(
              row['remarks'],
              '${previous['remarks']}\n원문 수강 제한: [농학과[2]]',
            );
            for (final key in previous.keys.where((k) => k != 'remarks')) {
              expect(
                row[key],
                previous[key],
                reason: '$key must remain deeply unchanged',
              );
            }
          } else {
            expect(row, previous);
          }
          final previousV5 = earlierRows[row['sourceId']] as Map;
          if ((previousV5['schedules'] as List).isNotEmpty) {
            expect(row, previousV5);
            preservedV5Scheduled++;
            preservedV5Dates += (previousV5['schedules'] as List).length;
          }
          if (newCases.contains(row['sourceId'])) {
            final rawNote =
                ((row['metadata'] as Map)['originalEducationalFields']
                        as Map)['remarks']
                    as String;
            if (rawNote.isNotEmpty) {
              expect(row['remarks'], contains(rawNote));
            }
          }
          final meetings = row['schedules'] as List;
          scheduled += meetings.isNotEmpty ? 1 : 0;
          dates += meetings.length;
        }
        models.addAll(UniversityDataset.fromJson(current).courses);
      }
      expect(nativeCount, 4842);
      expect(changed, 1);
      expect(scheduled, 3005);
      expect(dates, 53869);
      expect(preservedV5Scheduled, 2962);
      expect(preservedV5Dates, 53239);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        final saved = <String, TimetableClass>{};
        for (final course in models.where((c) => c.meetings.isNotEmpty)) {
          final actual = course.toTimetable(id: course.sourceId, mode: mode);
          expect(actual.isValid, isTrue);
          if (course.sourceId == 'gnu/gajwa/2026-2/11000004-001') {
            expect(actual.note, contains('[농학과[2]]'));
          }
          final key = timetableCourseSyncKey(actual);
          saved[key] = actual;
          values[key] = TimetableSyncValue(
            {...actual.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'gnu-v8-source-research',
          );
        }
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())),
        );
        expect(restored.courses.length, 3005);
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
