import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'jeju_current_ordinary_test.dart' as prior;

const here =
    'work/university-research/catalog-r/jeju/blended-physical-and-blank-room-v3-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path;
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
    'Jeju v3 exact blended attendance and empty room, all previous objects and full Drive',
    () {
      final courses = <UniversityCourse>[];
      var nativeCount = 0,
          previous = 0,
          previousDates = 0,
          added = 0,
          addedDates = 0,
          mixed = 0,
          blank = 0;
      for (final campus in ['ara', 'sara', 'unknown']) {
        final old = read(
          '${prior.root}jeju-$campus-2026-2.reservation-planned-v2.json',
        );
        final raw = read(
          '${here}jeju-$campus-2026-2.reservation-planned-v3.json',
        );
        final baseline = {
          for (final r in old['courses'] as List) r['sourceId']: r,
        };
        final dataset = UniversityDataset.fromJson(raw);
        final rows = raw['courses'] as List;
        for (var i = 0; i < rows.length; i++) {
          nativeCount++;
          final r = rows[i] as Map;
          final before = baseline[r['sourceId']] as Map;
          final c = dataset.courses[i];
          final isNew =
              (before['schedules'] as List).isEmpty && c.meetings.isNotEmpty;
          if (!isNew) {
            expect(r, before);
          } else {
            added++;
            addedDates += c.meetings.length;
            for (final key in before.keys.where(
              (k) => ![
                'schedules',
                'scheduleStatus',
                'sourceClassroom',
                'remarks',
                'metadata',
              ].contains(k),
            )) {
              expect(r[key], before[key]);
            }
            final metadata = r['metadata'] as Map;
            final fields = metadata['originalEducationalFields'] as Map;
            expect(
              fields,
              (before['metadata'] as Map)['originalEducationalFields'],
            );
            final original = fields['rawTimeAndRoom'] as String;
            final isMixed =
                metadata['v3SourceScope'] ==
                'printed-blended-weekly-attendance';
            final pairs = <Map<String, dynamic>>[];
            if (isMixed) {
              mixed++;
              expect(original.startsWith('블렌디드강좌'), true);
              pairs.addAll(
                prior.nativePairs(original.replaceFirst('블렌디드강좌', '').trim()),
              );
              expect(c.remarks, contains('온라인 부분 시각·방식은 생성하지'));
            } else {
              blank++;
              expect(original.startsWith('[]'), true);
              expect(c.sourceClassroom, '');
              for (final p in RegExp(
                r'([월화수목금])(\d+[AB]?)',
              ).allMatches(original)) {
                pairs.add({'day': p[1], 'period': p[2], 'room': ''});
              }
            }
            final expected = <String>{};
            for (
              var day = DateTime(2026, 9, 1);
              !day.isAfter(DateTime(2026, 12, 7));
              day = day.add(const Duration(days: 1))
            ) {
              final date = day.toIso8601String().substring(0, 10);
              if ((!day.isBefore(DateTime(2026, 10, 20)) &&
                      !day.isAfter(DateTime(2026, 10, 26))) ||
                  [
                    '2026-09-24',
                    '2026-09-25',
                    '2026-09-26',
                    '2026-10-03',
                    '2026-10-05',
                    '2026-10-09',
                  ].contains(date)) {
                continue;
              }
              for (final p in pairs) {
                final clock = prior.ownClock(p['period'] as String);
                if ('월화수목금토일'.indexOf(p['day'] as String) + 1 == day.weekday) {
                  expected.add('$date|${clock.$1}|${clock.$2}|${p['room']}');
                }
              }
            }
            expect(
              c.meetings
                  .map(
                    (m) =>
                        '${m.date}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom.replaceAll(RegExp(r'\s+'), '')}',
                  )
                  .toSet(),
              expected,
            );
            expect(c.meetings.length, expected.length);
          }
          if ((before['schedules'] as List).isNotEmpty) {
            previous++;
            previousDates += (before['schedules'] as List).length;
          }
          if (c.meetings.isNotEmpty) {
            courses.add(c);
          }
        }
      }
      expect(nativeCount, 3095);
      expect(previous, 1691);
      expect(previousDates, 62917);
      expect(added, 167);
      expect(addedDates, 4561);
      expect(mixed, 154);
      expect(blank, 13);
      expect(courses.length, 1858);
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 67478);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = courses
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored.length, classes.length);
        final expectedBySource = {
          for (final course in classes)
            course.sourceId: {
              ...course.toJson(),
              'id':
                  'source/${jsonEncode([course.academicYear, course.semester, course.sourceId])}',
            },
        };
        expect(
          restored.map((c) => c.sourceId).toSet(),
          expectedBySource.keys.toSet(),
        );
        for (final course in restored) {
          expect(course.toJson(), expectedBySource[course.sourceId]);
          expect(course.defaultMode, mode);
          for (final meeting in course.meetings) {
            expect(course.modeOn(meeting, DateTime.parse(meeting.date!)), mode);
          }
        }
      }
    },
  );
}
