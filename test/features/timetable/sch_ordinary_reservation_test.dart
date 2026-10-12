import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-i/sch-ordinary-reservation-v2-20261008';
Map<String, dynamic> read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
void main() {
  test(
    'SCH current regular and block clocks, exact native preservation, own dates, three modes and full Drive',
    () {
      final candidate = read('assets/timetable/sch-unknown-2026-2.json');
      final old = read(
        'work/university-research/catalog-i/sch-unknown-2026-2.accounting-thirteen-next.json',
      );
      for (final c in old['courses']) {
        if (c['metadata']?.containsKey('researchOnly') == true) {
          c['metadata']['researchOnly'] = false;
        }
      }
      final audit = read('$folder/candidate-audit.json');
      final courses = UniversityDataset.fromJson(candidate).courses;
      final additions = (audit['addedSourceIds'] as List).toSet();
      expect(courses, hasLength(2598));
      expect(additions, hasLength(2114));
      var preservedMeetings = 0;
      for (var i = 0; i < courses.length; i++) {
        final before = old['courses'][i] as Map;
        final after = candidate['courses'][i] as Map;
        expect(after['sourceId'], before['sourceId']);
        if (!additions.contains(after['sourceId'])) {
          expect(after, before);
          if ((before['schedules'] as List).isNotEmpty) {
            preservedMeetings += (before['schedules'] as List).length;
          }
        } else {
          for (final key in before.keys.where(
            (key) => !{
              'schedules',
              'scheduleStatus',
              'departmentRemarks',
            }.contains(key),
          )) {
            expect(
              after[key],
              before[key],
              reason: '${before['sourceId']}/$key',
            );
          }
          expect(after['reservationProof']['actualAttendanceVerified'], false);
          expect(after['reservationProof']['deliveryModeOverride'], false);
          // Independently parse every native token, without candidate block fields.
          final segments = (before['sourceSchedule'] as String).split('/');
          final rooms = (before['sourceClassroom'] as String).split('/');
          final blocks = <List<dynamic>>[];
          final blockTimes = {
            '1A-2A': [540, 615],
            '2B-3B': [630, 705],
            '4A-5A': [720, 795],
            '5B-6B': [810, 885],
            '7A-8A': [900, 975],
            '8B-9B': [990, 1065],
            '10A-11A': [1080, 1155],
            '11B-12B': [1170, 1245],
          };
          for (var part = 0; part < segments.length; part++) {
            final day = '월화수목금토일'.indexOf(segments[part][0]) + 1;
            for (final token in segments[part].substring(1).split(',')) {
              final times = blockTimes[token];
              final first = times == null
                  ? 540 + (int.parse(token) - 1) * 60
                  : times[0];
              final last = times == null ? first + 50 : times[1];
              blocks.add([
                day,
                first,
                last,
                rooms.length == 1 ? rooms[0] : rooms[part],
              ]);
            }
          }
          final expected = <String>[];
          for (
            var date = DateTime(2026, 8, 31);
            !date.isAfter(DateTime(2026, 12, 6));
            date = date.add(const Duration(days: 1))
          ) {
            final day = date.toIso8601String().substring(0, 10);
            if ({
                  '2026-09-24',
                  '2026-09-25',
                  '2026-09-26',
                  '2026-09-27',
                  '2026-10-03',
                  '2026-10-05',
                  '2026-10-09',
                }.contains(day) ||
                (day.compareTo('2026-10-19') >= 0 &&
                    day.compareTo('2026-10-23') <= 0)) {
              continue;
            }
            for (final block in blocks) {
              if (block[0] == date.weekday) {
                expected.add(
                  '$day/${block[0]}/${block[1]}/${block[2]}/${block[3]}',
                );
              }
            }
          }
          final actual = courses[i].meetings
              .map(
                (m) =>
                    '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              )
              .toList();
          expect(actual, expected, reason: before['sourceId'] as String);
          for (final m in courses[i].meetings) {
            final date = m.teachingDate!;
            final text = date.toIso8601String().substring(0, 10);
            expect(date.weekday, m.weekday);
            expect(date.isBefore(DateTime(2026, 8, 31)), false);
            expect(date.isAfter(DateTime(2026, 12, 6)), false);
            expect(
              {
                '2026-09-24',
                '2026-09-25',
                '2026-09-26',
                '2026-09-27',
                '2026-10-03',
                '2026-10-05',
                '2026-10-09',
              }.contains(text),
              false,
            );
            expect(
              text.compareTo('2026-10-19') >= 0 &&
                  text.compareTo('2026-10-23') <= 0,
              false,
            );
          }
        }
      }
      expect(preservedMeetings, 263);
      // Independent direct current table Regular2=10:00–10:50,3=11:00–11:50; no guessed60-minute contact.
      final education = courses.singleWhere((c) => c.code == '10008');
      expect(
        education.meetings
            .where((m) => m.date == '2026-09-02')
            .map(
              (m) => [m.originalStartMinute, m.originalEndMinute, m.classroom],
            )
            .toList(),
        [
          [600, 650, '7313'],
          [660, 710, '7313'],
        ],
      );
      // Current sheet matching native75-minute pair, two distinct weekdays.
      final music = courses.singleWhere((c) => c.code == '10508');
      expect(
        music.meetings
            .where((m) => m.date == '2026-09-01')
            .map(
              (m) => [m.originalStartMinute, m.originalEndMinute, m.classroom],
            )
            .toList(),
        [
          [990, 1065, 'U1214'],
        ],
      );
      expect(
        music.meetings
            .where((m) => m.date == '2026-09-04')
            .map(
              (m) => [m.originalStartMinute, m.originalEndMinute, m.classroom],
            )
            .toList(),
        [
          [720, 795, 'U1214'],
        ],
      );
      final night = courses.singleWhere((c) => c.code == '12505');
      expect(
        night.meetings
            .where((m) => m.date == '2026-08-31')
            .map(
              (m) => [m.originalStartMinute, m.originalEndMinute, m.classroom],
            )
            .toList(),
        [
          [1080, 1130, '6403'],
          [1140, 1190, '6403'],
          [1200, 1250, '6403'],
        ],
      );
      for (final code in [
        '12645',
        '12692',
        '12705',
        '12904',
        '10517',
        '10507',
        '10510',
        '10509',
        '10133',
      ]) {
        expect(courses.singleWhere((c) => c.code == code).meetings, isEmpty);
      }
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2127));
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 64564);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.professor, c.professor);
          expect(saved.note, c.remarks);
          for (final m in saved.meetings) {
            expect(saved.modeOn(m, m.teachingDate!), mode);
            expect(saved.period!.contains(m.teachingDate!), true);
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          json,
        ).materializeClasses();
        expect(restored, hasLength(2127));
        for (final c in restored) {
          expect(c.defaultMode, mode);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
