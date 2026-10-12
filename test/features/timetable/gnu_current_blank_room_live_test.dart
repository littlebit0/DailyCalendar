import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const directory =
    'work/university-research/catalog-r/gnu/blank-room-and-live-source-followup-v6-20261009';
const baseline =
    'work/university-research/catalog-r/gnu/remaining-campus-clock-followup-v5-20261008';
Map<String, dynamic> read(String path) {
  final actual = path.startsWith('$directory/gnu-')
      ? 'assets/timetable/${path.split('/').last.split('.').first}.json'
      : path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  for (final row in data['courses'] ?? []) {
    if (row['metadata']?.containsKey('researchOnly') == true) {
      row['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  test(
    '43 native weekly source cases retain 4842 identities and full three-mode Drive',
    () {
      final audit = read('$directory/audit.json');
      final nativeRows =
          jsonDecode(
                File(
                  'work/university-research/catalogs/gnu-public-course-rows.json',
                ).readAsStringSync(),
              )
              as List;
      final clockSource = read(
        '$baseline/current2026-2-university-undergraduate-clock-education.json',
      );
      final clock = <int, List<int>>{};
      for (final rowValue in (clockSource['clockTable'] as List).skip(1)) {
        final row = rowValue as List;
        for (final column in [0, 2]) {
          final period = int.parse(
            RegExp(r'^\d+').firstMatch(row[column] as String)!.group(0)!,
          );
          final times = RegExp(r'\d{2}:\d{2}')
              .allMatches(row[column + 1] as String)
              .map((m) => m.group(0)!)
              .toList();
          int minute(String value) =>
              int.parse(value.substring(0, 2)) * 60 +
              int.parse(value.substring(3));
          clock[period] = times.map(minute).toList();
        }
      }
      expect(clock, {
        for (var n = 0; n <= 11; n++) n: [480 + 60 * n, 530 + 60 * n],
      });
      final makeup = Map<String, dynamic>.from(audit['makeup'] as Map);
      expect(makeup, {
        '2026-10-20': '2026-12-08',
        '2026-09-25': '2026-12-09',
        '2026-09-24': '2026-12-10',
        '2026-10-09': '2026-12-11',
        '2026-09-26': '2026-12-12',
        '2026-10-05': '2026-12-14',
      });
      final before = <String, Map<String, dynamic>>{};
      final after = <String, Map<String, dynamic>>{};
      final models = <UniversityCourse>[];
      for (final campus in [
        'changwon',
        'chilam',
        'gajwa',
        'naedong',
        'tongyeong',
        'unknown',
      ]) {
        final prior = read(
          '$baseline/gnu-$campus-2026-2.ordinary-university-guide-v5.json',
        );
        final current = read(
          '$directory/gnu-$campus-2026-2.blank-room-and-live-v6.json',
        );
        for (final raw in prior['courses'] as List) {
          final value = Map<String, dynamic>.from(raw as Map);
          before[value['sourceId'] as String] = value;
        }
        for (final raw in current['courses'] as List) {
          final value = Map<String, dynamic>.from(raw as Map);
          after[value['sourceId'] as String] = value;
        }
        models.addAll(UniversityDataset.fromJson(current).courses);
      }
      expect(before.length, 4842);
      expect(after.keys.toSet(), before.keys.toSet());
      final additions = {
        for (final value in audit['newCases'] as List)
          (value as Map)['sourceId'] as String: value,
      };
      expect(additions.length, 43);
      const liveIds = {
        'gnu/unknown/2026-2/11027052-001',
        'gnu/unknown/2026-2/11027053-001',
        'gnu/unknown/2026-2/11027084-001',
      };
      var unchanged = 0;
      var oldScheduled = 0;
      var oldDates = 0;
      var newDates = 0;
      var blankRooms = 0;
      var blankRoomDates = 0;
      var nurseCases = 0;
      for (final entry in after.entries) {
        final previous = before[entry.key]!;
        oldDates += (previous['schedules'] as List).length;
        oldScheduled += (previous['schedules'] as List).isNotEmpty ? 1 : 0;
        if (!additions.containsKey(entry.key)) {
          expect(entry.value, previous, reason: entry.key);
          unchanged++;
          continue;
        }
        final current = entry.value;
        expect(previous['schedules'], isEmpty);
        for (final field in previous.keys.where(
          (key) => ![
            'schedules',
            'scheduleStatus',
            'remarks',
            'metadata',
          ].contains(key),
        )) {
          expect(
            current[field],
            previous[field],
            reason: '${entry.key} $field',
          );
        }
        final metadata = current['metadata'] as Map;
        final native = metadata['originalEducationalFields'] as Map;
        expect(
          native,
          (previous['metadata'] as Map)['originalEducationalFields'],
        );
        final matchingNative = nativeRows
            .where(
              (row) =>
                  (row as Map)['sourceFile'] == native['sourceFile'] &&
                  row['sourceRow'] == native['sourceRow'],
            )
            .toList();
        expect(matchingNative.length, 1);
        expect(matchingNative.single, native);
        expect(current['courseCode'], native['code']);
        expect(current['section'], native['section']);
        expect(current['professor'], native['professor']);
        expect(native['closedFirstAnnouncement'], isFalse);
        expect(native['closedSecondAnnouncement'], isFalse);
        expect(native['remarks'], isNot(contains('집중')));
        expect(metadata['priorResearchRemarks'], previous['remarks']);
        expect(metadata['actualAttendanceConfirmed'], isFalse);
        expect(metadata['wholeLatestChangesConfirmed'], isFalse);
        final matches = RegExp(
          r'([월화수목금토일])(\d+(?:,\d+)*)(?:\[([^\]]+)\])?',
        ).allMatches(native['schedule'] as String).toList();
        expect(matches, isNotEmpty);
        final blocks = <Map<String, dynamic>>[];
        for (final match in matches) {
          final weekday = '월화수목금토일'.indexOf(match.group(1)!) + 1;
          final numbers = match.group(2)!.split(',').map(int.parse).toList();
          expect(numbers.toSet().length, numbers.length);
          if (entry.key == 'gnu/gajwa/2026-2/11006946-001' && weekday == 3) {
            expect(numbers, [10, 11, 12]);
            expect(clock.containsKey(12), isFalse);
            continue;
          }
          expect(numbers.every(clock.containsKey), isTrue);
          final runs = <List<int>>[];
          for (final number in numbers) {
            if (runs.isEmpty || number != runs.last.last + 1) {
              runs.add(<int>[]);
            }
            runs.last.add(number);
          }
          for (final run in runs) {
            blocks.add({
              'weekday': weekday,
              'startMinute': clock[run.first]![0],
              'endMinute': clock[run.last]![1],
              'classroom': match.group(3) ?? '',
            });
          }
        }
        final expected = <Map<String, dynamic>>[];
        for (final block in blocks) {
          for (
            var date = DateTime(2026, 9, 1);
            !date.isAfter(DateTime(2026, 12, 7));
            date = date.add(const Duration(days: 1))
          ) {
            final sourceDay = date.toIso8601String().substring(0, 10);
            if (date.weekday != block['weekday'] || sourceDay == '2026-10-03') {
              continue;
            }
            final actualDay = makeup[sourceDay] as String? ?? sourceDay;
            final actualDate = DateTime.parse(actualDay);
            expected.add({
              'date': actualDay,
              'weekday': actualDate.weekday,
              'startMinute': block['startMinute'],
              'endMinute': block['endMinute'],
              'classroom': block['classroom'],
              if (liveIds.contains(entry.key)) 'deliveryMode': 'liveOnline',
            });
          }
        }
        expected.sort((a, b) {
          final date = (a['date'] as String).compareTo(b['date'] as String);
          if (date != 0) {
            return date;
          }
          final start = (a['startMinute'] as int).compareTo(
            b['startMinute'] as int,
          );
          if (start != 0) {
            return start;
          }
          return (a['classroom'] as String).compareTo(b['classroom'] as String);
        });
        expect(current['schedules'], expected, reason: entry.key);
        newDates += expected.length;
        if (liveIds.contains(entry.key)) {
          expect(native['method'], '비대면수업');
          expect(native['remoteType'], '실시간 원격 화상강좌');
          expect(current['campus'], 'unknown');
        } else {
          expect(native['method'], '대면수업');
          expect(native['remoteType'], '');
        }
        if (blocks.every((b) => b['classroom'] == '') &&
            !liveIds.contains(entry.key)) {
          blankRooms++;
          blankRoomDates += expected.length;
        }
        if (native['department'] == '간호학과') {
          nurseCases++;
          expect(native['remarks'], '');
          expect(current['campus'], 'chilam');
        }
      }
      expect(unchanged, 4799);
      expect(oldScheduled, 2962);
      expect(oldDates, 53239);
      expect(newDates, 630);
      expect(blankRooms, 39);
      expect(blankRoomDates, 574);
      expect(nurseCases, 36);
      expect(models.where((c) => c.meetings.isNotEmpty).length, 3005);
      expect(
        after.values.fold<int>(
          0,
          (sum, c) => sum + (c['schedules'] as List).length,
        ),
        53869,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        final savedByKey = <String, TimetableClass>{};
        for (final course in models.where((c) => c.meetings.isNotEmpty)) {
          final saved = course.toTimetable(id: course.sourceId, mode: mode);
          expect(saved.isValid, isTrue);
          if (additions.containsKey(course.sourceId)) {
            for (final meeting in saved.meetings) {
              expect(
                saved.modeOn(meeting, DateTime.parse(meeting.date!)),
                liveIds.contains(course.sourceId)
                    ? LectureMode.liveOnline
                    : mode,
              );
            }
          }
          final key = timetableCourseSyncKey(saved);
          savedByKey[key] = saved;
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'gnu-v6-source-research',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())),
        );
        expect(restored.courses.length, 3005);
        for (final entry in savedByKey.entries) {
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
