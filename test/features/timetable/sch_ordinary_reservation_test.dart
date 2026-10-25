import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-i/sch-ordinary-reservation-v2-20261008';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
// 2023 요람 65쪽 「수업시간」: 교시 슬롯 = 수업 + 쉬는 시간(50분 교시 -> 60분,
// 75분 블록 -> 90분). 같은 날 같은 강의실에서 간격이 60분 미만이면 한 구간으로
// 합친다. 이미 슬롯 단위(60·180분 등)로 저장된 구간의 길이는 바꾸지 않는다.
List<Map<String, dynamic>> slotMerge(List items, Object Function(Map) key) {
  final groups = <Object, List<Map<String, dynamic>>>{};
  for (final item in items) {
    groups
        .putIfAbsent(key(item as Map), () => [])
        .add(Map<String, dynamic>.from(item));
  }
  final out = <Map<String, dynamic>>[];
  for (final group in groups.values) {
    group.sort((a, b) => (a['startMinute'] as int).compareTo(b['startMinute']));
    Map<String, dynamic>? current;
    for (final s in group) {
      final length = (s['endMinute'] as int) - (s['startMinute'] as int);
      final end =
          (s['startMinute'] as int) +
          (length == 50
              ? 60
              : length == 75
              ? 90
              : length);
      if (current != null &&
          (s['startMinute'] as int) - (current['endMinute'] as int) < 60) {
        if (end > (current['endMinute'] as int)) current['endMinute'] = end;
      } else {
        current = {...s, 'endMinute': end};
        out.add(current);
      }
    }
  }
  return out;
}

Object scheduleKey(Map s) => '${s['date']}/${s['weekday']}/${s['classroom']}';
Object blockKey(Map s) => '${s['weekday']}/${s['classroom']}';

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
          final slotted = Map<String, dynamic>.from(before);
          slotted['schedules'] =
              (slotMerge(before['schedules'] as List, scheduleKey)
                ..sort((a, b) {
                  final byDate = (a['date'] as String).compareTo(b['date']);
                  return byDate != 0
                      ? byDate
                      : (a['startMinute'] as int).compareTo(b['startMinute']);
                }));
          if (before['nativeReservationBlocks'] != null) {
            slotted['nativeReservationBlocks'] = slotMerge(
              before['nativeReservationBlocks'] as List,
              blockKey,
            );
          }
          expect(after, slotted);
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
          final expected = <Map<String, dynamic>>[];
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
                expected.add({
                  'date': day,
                  'weekday': block[0],
                  'startMinute': block[1],
                  'endMinute': block[2],
                  'classroom': block[3],
                });
              }
            }
          }
          final actual = courses[i].meetings
              .map(
                (m) =>
                    '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              )
              .toList();
          expect(
            actual,
            (slotMerge(expected, scheduleKey)..sort((a, b) {
                  final byDate = (a['date'] as String).compareTo(b['date']);
                  return byDate != 0
                      ? byDate
                      : (a['startMinute'] as int).compareTo(b['startMinute']);
                }))
                .map(
                  (e) =>
                      '${e['date']}/${e['weekday']}/${e['startMinute']}/${e['endMinute']}/${e['classroom']}',
                )
                .toList(),
            reason: before['sourceId'] as String,
          );
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
      // 2·3교시(10:00–10:50, 11:00–11:50)는 슬롯(60분)으로 이어져 10:00~12:00 한 구간.
      final education = courses.singleWhere((c) => c.code == '10008');
      expect(
        education.meetings
            .where((m) => m.date == '2026-09-02')
            .map(
              (m) => [m.originalStartMinute, m.originalEndMinute, m.classroom],
            )
            .toList(),
        [
          [600, 720, '7313'],
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
          [990, 1080, 'U1214'],
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
          [720, 810, 'U1214'],
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
          [1080, 1260, '6403'],
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
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 35380);
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
