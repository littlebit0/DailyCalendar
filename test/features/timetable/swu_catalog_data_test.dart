import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-c/swu-current-20261008';
Map<String, dynamic> read(String file) =>
    jsonDecode(fixtureFile('$directory/$file').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  test(
    'SWU academic identity and official native qualifications remain distinct',
    () {
      for (final id in [
        'institution:academyinfo:0000126',
        'academyinfo:0000126',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '서울여자대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'swu');
        expect(profile.timetableCampus, 'main');
        expect(profile.academicSourceId, 'swu');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '서울여자대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          isFalse,
        );
      }
      expect(courseCategory('평교'), CourseCategory.certification);
      expect(courseCategory('복필'), CourseCategory.requiredMajor);
      expect(courseCategory('복선'), CourseCategory.electiveMajor);
    },
  );
  final audit = read('audit.json');
  final file = (audit['datasets'] as List).single['file'] as String;
  final raw =
      jsonDecode(
            fixtureFile(
              'assets/timetable/swu-main-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final courses = UniversityDataset.fromJson(raw).courses;
  test(
    '172 actual selectors 2705 rows 1511 native offerings and educational-only immutable metadata',
    () {
      expect(audit['queryCount'], 172);
      expect(audit['queryRows'], 2705);
      expect(courses, hasLength(1511));
      expect(
        sha256
            .convert(fixtureFile('$directory/$file').readAsBytesSync())
            .toString(),
        audit['datasets'][0]['sha256'],
      );
      expect(audit['finalClosureCount'], 66);
      expect(audit['finalClosuresStillPresent'], 0);
      for (final c in courses) {
        final record = (raw['courses'] as List).singleWhere(
          (x) => x['sourceId'] == c.sourceId,
        );
        final education =
            (record['publicEducationBySelection'] as List).first['education'];
        expect(c.code, education['SB_CD']);
        expect(c.section, education['DIVCLS_CD']);
        expect(c.title, education['SB_CD_NM']);
        expect(c.sourceSchedule, education['CLASS']);
        for (final row in record['publicEducationBySelection']) {
          expect(
            (row['education'] as Map).keys.any(
              (k) => RegExp('USER|IP_MAC|FILE|TLSN_REQ|CAPA').hasMatch(k),
            ),
            false,
          );
          final department = row['query']['department'];
          if (department != '') {
            expect(c.departments, isNotEmpty);
          }
        }
        expect(c.remarks, contains('실제'));
      }
      for (final value in (read('swu-onload.json')['root'] as Map).values) {
        if (value is Map && value['row'] is List) {
          for (final row in value['row']) {
            expect(
              (row as Map).keys.toSet().difference({
                'CD',
                'CD_NM',
                'SA_CD',
                'SA_NM',
              }),
              isEmpty,
            );
          }
        }
      }
    },
  );
  test(
    'Bahrom exact partial dates chapel videos and unknown dates cannot fabricate recurrent teaching',
    () {
      for (final c in courses.where((c) => c.code == 'UA03011')) {
        final n = int.parse(c.section);
        if (n <= 43) {
          expect(c.meetings, isEmpty);
          expect(c.remarks, contains('예약표시'));
        } else {
          expect(
            c.meetings,
            hasLength(
              n <= 49
                  ? 7
                  : n <= 53
                  ? 6
                  : 7,
            ),
          );
          expect(c.meetings.every((m) => m.date != null), true);
          if (n >= 50 && n <= 53) expect(c.remarks, contains('*11월에는 없는지'));
        }
      }
      for (final c in courses.where(
        (c) => c.code == '1111111' || c.code == '1111112',
      )) {
        expect(c.meetings, isEmpty);
      }
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1281));
    },
  );

  test(
    'all dated plans match original weekday clock classroom and official holiday replacements',
    () {
      const publishedClock = {
        1: [540, 615],
        2: [630, 705],
        3: [720, 795],
        4: [810, 885],
        5: [900, 975],
        6: [990, 1065],
        7: [1080, 1130],
        8: [1140, 1190],
        9: [1200, 1250],
        10: [1260, 1310],
        11: [1320, 1370],
      };
      const holidayDates = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      const replacements = {
        '2026-12-08': 1,
        '2026-12-09': 5,
        '2026-12-10': 4,
        '2026-12-11': 5,
      };
      const bahromDates = {
        'monday': [
          '2026-09-07',
          '2026-09-14',
          '2026-09-21',
          '2026-09-28',
          '2026-10-12',
          '2026-10-26',
          '2026-11-02',
        ],
        'tuesday': [
          '2026-09-01',
          '2026-09-08',
          '2026-09-15',
          '2026-09-22',
          '2026-10-06',
          '2026-10-13',
        ],
        'friday': [
          '2026-09-04',
          '2026-09-11',
          '2026-09-18',
          '2026-10-02',
          '2026-10-16',
          '2026-10-30',
          '2026-11-06',
        ],
      };
      for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
        final record = (raw['courses'] as List).singleWhere(
          (x) => x['sourceId'] == c.sourceId,
        );
        final native = record['sourceSnapshotSchedules'] as List;
        final seen = <String>{};
        for (final m in c.meetings) {
          final nativeDay = c.code == 'UA03011'
              ? m.weekday
              : replacements[m.date] ?? m.weekday;
          final original = native.where(
            (x) =>
                x['weekday'] == nativeDay &&
                x['startMinute'] == m.originalStartMinute &&
                x['endMinute'] == m.originalEndMinute &&
                x['classroom'] == m.classroom,
          );
          expect(original, isNotEmpty, reason: c.codeAndSection);
          expect(
            seen.add(
              '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            true,
          );
          expect(
            publishedClock.values.any((x) => x[0] == m.originalStartMinute),
            true,
          );
          expect(
            publishedClock.values.any((x) => x[1] == m.originalEndMinute),
            true,
          );
          if (c.code != 'UA03011') {
            expect(holidayDates.contains(m.date), false);
            expect(
              m.teachingDate!.isAfter(DateTime(2026, 12, 7))
                  ? replacements.containsKey(m.date)
                  : true,
              true,
            );
          }
        }
        if (c.code == 'UA03011') {
          final section = int.parse(c.section);
          final expected =
              bahromDates[section <= 49
                  ? 'monday'
                  : section <= 53
                  ? 'tuesday'
                  : 'friday']!;
          expect(c.meetings.map((m) => m.date).toSet(), expected.toSet());
          expect(
            c.sourceClassroom,
            record['publicEducationBySelection'][0]['education']['CLASS'].split(
              ' / ',
            )[1],
          );
        } else {
          for (final b in native) {
            final expectedDates = <String>{};
            for (
              var day = DateTime(2026, 9, 1);
              !day.isAfter(DateTime(2026, 12, 7));
              day = day.add(const Duration(days: 1))
            ) {
              final date = timetableDateKey(day);
              if (day.weekday == b['weekday'] && !holidayDates.contains(date)) {
                expectedDates.add(date);
              }
            }
            for (final e in replacements.entries) {
              if (e.value == b['weekday']) {
                expectedDates.add(e.key);
              }
            }
            final actual = c.meetings
                .where(
                  (m) =>
                      (replacements[m.date] ?? m.weekday) == b['weekday'] &&
                      m.originalStartMinute == b['startMinute'] &&
                      m.originalEndMinute == b['endMinute'] &&
                      m.classroom == b['classroom'],
                )
                .map((m) => m.date)
                .toSet();
            expect(
              actual,
              expectedDates,
              reason: '${c.codeAndSection} native weekday ${b['weekday']}',
            );
          }
        }
      }
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      '1281 published plans 20406 dates actual full sync roundtrip $mode',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in courses) {
          if (c.meetings.isEmpty) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.defaultMode, mode);
          expect(saved.note, c.remarks);
          expect(saved.period!.start, DateTime(2026, 9, 1));
          expect(saved.period!.end, DateTime(2026, 12, 21));
          for (final m in saved.meetings) {
            count++;
            expect(m.isValid, true);
            expect(saved.period!.contains(m.teachingDate!), true);
            expect(saved.modeOn(m, m.teachingDate!), mode);
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(count, 20406);
        expect(values, hasLength(1281));
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(1281));
        for (final c in restored.materializeClasses()) {
          expect(c.isValid, true);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      },
    );
  }
}
