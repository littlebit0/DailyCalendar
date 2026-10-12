import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

const _root = 'work/university-research/resume-20261011/';

void main() {
  test(
    'source additions preserve every unaffected course and existing meeting',
    () {
      final receipt = _read('${_root}integration-receipt.json');
      for (final entry in receipt['assets'] as List) {
        final before = _read(entry['before'] as String);
        final after = _read(entry['asset'] as String);
        final oldRows = before['courses'] as List;
        final rows = after['courses'] as List;
        final changed = (entry['changedSourceIds'] as List).toSet();
        expect(rows.length, oldRows.length);
        final parsed = UniversityDataset.fromJson(after);
        expect(parsed.courses.length, rows.length);
        for (var i = 0; i < rows.length; i++) {
          final old = oldRows[i] as Map;
          final current = rows[i] as Map;
          expect(current['sourceId'], old['sourceId']);
          if (!changed.contains(old['sourceId'])) {
            expect(current, old, reason: old['sourceId'] as String);
            continue;
          }
          for (final field in [
            'courseCode',
            'section',
            'professor',
            'campus',
            'sourceSchedule',
            'sourceClassroom',
            'sourceEducationalVariants',
            'period',
          ]) {
            expect(current[field], old[field], reason: field);
          }
          for (final meeting in old['schedules'] as List) {
            expect(current['schedules'], contains(equals(meeting)));
          }
          expect(
            parsed.courses[i]
                .toTimetable(
                  id: 'test-${old['sourceId']}',
                  mode: LectureMode.inPerson,
                )
                .isValid,
            isTrue,
          );
        }
        final beforeHeader = Map.of(before)..remove('courses');
        final afterHeader = Map.of(after)..remove('courses');
        expect(afterHeader, beforeHeader);
      }
    },
  );

  test(
    'own business Tuesday clocks do not copy Thursday rooms or expand the term',
    () {
      final data = _read('assets/timetable/koreatech-unknown-2026-2.json');
      for (final section in ['02', '03']) {
        final row = (data['courses'] as List).cast<Map>().singleWhere(
          (row) => row['courseCode'] == 'CCT740' && row['section'] == section,
        );
        final tuesdays = (row['schedules'] as List)
            .cast<Map>()
            .where((meeting) => meeting['weekday'] == 2)
            .toList();
        expect(tuesdays, hasLength(14));
        expect(tuesdays.first['date'], '2026-09-01');
        expect(tuesdays.last['date'], '2026-12-01');
        for (final meeting in tuesdays) {
          expect(meeting['startMinute'], section == '02' ? 540 : 660);
          expect(meeting['endMinute'], section == '02' ? 660 : 780);
          expect(meeting['classroom'], '');
          expect(DateTime.parse(meeting['date'] as String).weekday, 2);
        }
        expect(
          row['metadata']['currentBusinessGridProof']['partialRoomScope'],
          isTrue,
        );
      }
    },
  );

  test(
    'KHU professor-specific Mondays exclude unassigned Wednesday and exams',
    () {
      for (final item in [
        ('seoul', 'PSC306400', 990, 1065, '정301'),
        ('global', 'APCH330200', 540, 615, '공146호'),
      ]) {
        final data = _read('assets/timetable/khu-${item.$1}-2026-2.json');
        final row = (data['courses'] as List).cast<Map>().singleWhere(
          (row) => (row['sourceId'] as String).endsWith('/${item.$2}'),
        );
        final meetings = (row['schedules'] as List).cast<Map>();
        expect(meetings, hasLength(13));
        for (final meeting in meetings) {
          expect(meeting['weekday'], 1);
          expect(meeting['startMinute'], item.$3);
          expect(meeting['endMinute'], item.$4);
          expect(meeting['classroom'], item.$5);
          expect([
            '2026-10-05',
            '2026-10-26',
            '2026-12-21',
          ], isNot(contains(meeting['date'])));
        }
        expect(row['semanticOperatingReview']['unmatchedNativeWeekdaysHeld'], [
          3,
        ]);
      }
    },
  );

  test(
    'SKKU direct dates exclude recorded and conflicting rows and retain explicit modes',
    () {
      final humanities = UniversityDataset.fromJson(
        _read('assets/timetable/skku-humanities-2026-2.json'),
      );
      final dkl = humanities.courses.singleWhere(
        (course) => course.code == 'DKL2018' && course.section == '02',
      );
      expect(dkl.meetings, hasLength(20));
      expect(
        dkl.meetings.map((meeting) => meeting.date),
        isNot(
          anyOf(
            contains('2026-09-16'),
            contains('2026-10-07'),
            contains('2026-11-04'),
            contains('2026-10-28'),
            contains('2026-12-09'),
          ),
        ),
      );
      final epn = humanities.courses.singleWhere(
        (course) => course.code == 'EPN2004' && course.section == '01',
      );
      expect(
        epn.meetings.map((meeting) => meeting.date),
        isNot(contains('2026-11-23')),
      );
      final art = humanities.courses.singleWhere(
        (course) => course.code == 'ART2069' && course.section == '01',
      );
      expect(art.meetings, hasLength(26));
      expect(
        art.meetings.every((meeting) => meeting.classroom.isEmpty),
        isTrue,
      );
      final natural = UniversityDataset.fromJson(
        _read('assets/timetable/skku-naturalScience-2026-2.json'),
      );
      final live = natural.courses
          .singleWhere(
            (course) => course.code == 'CFTD003' && course.section == '41',
          )
          .toTimetable(id: 'live', mode: LectureMode.inPerson);
      expect(live.meetings, hasLength(2));
      for (final meeting in live.meetings) {
        expect(meeting.date, '2026-09-04');
        expect(meeting.classroom, '');
        expect(
          live.modeOn(meeting, DateTime(2026, 9, 4)),
          LectureMode.liveOnline,
        );
      }
    },
  );

  test(
    'Donga retains own published windows and excludes external intensive weeks',
    () {
      final dataset = UniversityDataset.fromJson(
        _read('assets/timetable/donga-seunghak-2026-2.json'),
      );
      final course = dataset.courses.singleWhere(
        (course) => course.code == '01HMC407',
      );
      expect(course.meetings, hasLength(17));
      for (final meeting in course.meetings) {
        expect(meeting.startMinute, 990);
        expect(meeting.endMinute, 1080);
        expect(
          meeting.classroom,
          meeting.weekday == 3 ? 'S17-0106' : 'S09-0203',
        );
        expect(
          DateTime.parse(meeting.date!).isBefore(DateTime(2026, 11, 10)),
          isTrue,
        );
      }
    },
  );

  test(
    'every changed course retains dates and chosen modes through Drive serialization',
    () {
      final receipt = _read('${_root}integration-receipt.json');
      final courses = <TimetableClass>[];
      for (final entry in receipt['assets'] as List) {
        final changed = (entry['changedSourceIds'] as List).toSet();
        final dataset = UniversityDataset.fromJson(
          _read(entry['asset'] as String),
        );
        for (final course in dataset.courses.where(
          (c) => changed.contains(c.sourceId),
        )) {
          expect(
            course.meetings.every((meeting) => meeting.date != null),
            isTrue,
          );
          courses.add(
            course.toTimetable(id: course.sourceId, mode: LectureMode.inPerson),
          );
        }
      }
      expect(courses, isNotEmpty);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final configured = courses
            .map(
              (course) => TimetableClass.fromJson({
                ...course.toJson(),
                'defaultMode': mode.name,
              }),
            )
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: configured,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(configured.length));
        final bySource = {
          for (final course in configured) course.sourceId: course,
        };
        for (final course in restored) {
          final original = bySource[course.sourceId]!;
          expect(
            course.meetings.map((meeting) => meeting.toJson()).toList(),
            original.meetings.map((meeting) => meeting.toJson()).toList(),
          );
          expect(course.defaultMode, original.defaultMode);
          expect(course.overrides, original.overrides);
          expect(course.isValid, isTrue);
        }
      }
    },
  );
}
