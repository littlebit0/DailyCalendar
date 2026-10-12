import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CBNU current three-row scope retains prior11 and all mode Drive JSON',
    () {
      const root =
          'work/university-research/catalog-f/cbnu/'
          'current-whole-public-path-and-politics-partial-v3-20261009/';
      Map<String, dynamic> read(String name) {
        final actual = name == 'cbnu-main-2026-2.politics-partial-v3.json'
            ? 'assets/timetable/cbnu-main-2026-2.json'
            : '$root$name';
        final data =
            jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
        if (data['courses'] is List) {
          for (final c in data['courses']) {
            if (c['metadata']?.containsKey('researchOnly') == true) {
              c['metadata']['researchOnly'] = false;
            }
          }
        }
        return data;
      }

      final raw = read('cbnu-main-2026-2.politics-partial-v3.json');
      final prior = read('prior11-current-asset-snapshot.json');
      final rawCourses = (raw['courses'] as List).cast<Map<String, dynamic>>();
      final oldCourses = (prior['courses'] as List)
          .cast<Map<String, dynamic>>();
      expect(raw['completionClaim'], isFalse);
      expect(raw['wholeSchoolCourseCoverageComplete'], isFalse);
      expect(raw['institutionId'], 'institution:academyinfo:0000030');
      expect(rawCourses, hasLength(14));
      expect(oldCourses, hasLength(11));
      final byId = {for (final c in rawCourses) c['sourceId']: c};
      expect(byId, hasLength(14));
      for (final old in oldCourses) {
        expect(byId[old['sourceId']], old);
      }
      expect(
        oldCourses.fold<int>(0, (n, c) => n + (c['schedules'] as List).length),
        435,
      );
      final expected = <String, Map<String, dynamic>>{
        '5666079-01': {
          'weekday': 1,
          'starts': [600, 660, 720],
          'room': 'N15-242(57-242)',
          'professor': '',
          'dates': 12,
        },
        '0912002-09': {
          'weekday': 2,
          'starts': [540, 600, 660],
          'room': 'N13-502(59-502)',
          'professor': '전소영',
          'dates': 14,
        },
        '0914011-05': {
          'weekday': 3,
          'starts': [780, 840, 900],
          'room': 'N23-103(교양강의실-6)',
          'professor': '홍민숙',
          'dates': 14,
        },
      };
      const excluded = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-09-27',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      final closure =
          jsonDecode(
                File(
                  'work/university-research/catalog-f/cbnu/'
                  'cbnu-current-closure-education-20261008.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final closedKeys = {
        for (final c in closure['closedCourses'] as List)
          '${c['courseCode']}-${c['section']}',
      };
      final newRows = rawCourses
          .where(
            (c) => expected.containsKey('${c['courseCode']}-${c['section']}'),
          )
          .toList();
      expect(newRows, hasLength(3));
      for (final row in newRows) {
        final key = '${row['courseCode']}-${row['section']}';
        final proof = expected[key]!;
        expect(closedKeys, isNot(contains(key)));
        expect(row['professor'], proof['professor']);
        expect(row['credits'], isNull);
        expect(row['sourceClassroom'], proof['room']);
        expect(row['remarks'], contains('정치외교학과'));
        expect(row['remarks'], contains('신입생'));
        final independent = <Map<String, dynamic>>[];
        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 6));
          day = day.add(const Duration(days: 1))
        ) {
          final date = day.toIso8601String().substring(0, 10);
          if (day.weekday == proof['weekday'] && !excluded.contains(date)) {
            for (final start in proof['starts'] as List<int>) {
              independent.add({
                'date': date,
                'weekday': proof['weekday'],
                'startMinute': start,
                'endMinute': start + 50,
                'classroom': proof['room'],
              });
            }
          }
        }
        expect(row['schedules'], independent);
        expect(independent, hasLength((proof['dates'] as int) * 3));
        if (key == '5666079-01') {
          final metadata = row['metadata'] as Map<String, dynamic>;
          final original =
              metadata['originalEducationalFields'] as Map<String, dynamic>;
          expect(original['sourceProfessorPrinted'], isTrue);
          expect(
            original['sourceProfessorConfidence'],
            'unconfirmed-small-image-teacher-field',
          );
          expect(row['remarks'], contains('판독이 불확실'));
        }
      }
      final dataset = UniversityDataset.fromJson(raw);
      expect(dataset.courses, hasLength(14));
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        555,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = dataset.courses
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        final originalById = {for (final c in originals) c.sourceId: c};
        expect(restored, hasLength(14));
        expect(
          restored.map((c) => c.sourceId).toSet(),
          originalById.keys.toSet(),
        );
        for (final c in restored) {
          expect(c.isValid, isTrue);
          final original = originalById[c.sourceId]!;
          expect(c.id, timetableCourseSyncKey(original));
          expect(c.toJson(), {
            ...original.toJson(),
            'id': timetableCourseSyncKey(original),
          });
          for (final meeting in c.meetings) {
            expect(c.modeOn(meeting, DateTime.parse(meeting.date!)), mode);
          }
        }
      }
    },
  );
}
