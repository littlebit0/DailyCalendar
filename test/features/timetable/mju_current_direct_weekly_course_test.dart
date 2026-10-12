import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-f/mju/current-english-writing-direct-clock-v5-20261009';
const nativeUrl =
    'https://english.mju.ac.kr/bbs/english/1034/233737/artclView.do';
const literalDates = <String>[
  '2026-09-01',
  '2026-09-03',
  '2026-09-08',
  '2026-09-10',
  '2026-09-15',
  '2026-09-17',
  '2026-09-22',
  '2026-09-29',
  '2026-10-01',
  '2026-10-06',
  '2026-10-08',
  '2026-10-13',
  '2026-10-15',
  '2026-10-27',
  '2026-10-29',
  '2026-11-03',
  '2026-11-05',
  '2026-11-10',
  '2026-11-12',
  '2026-11-17',
  '2026-11-19',
  '2026-11-24',
  '2026-11-26',
  '2026-12-01',
  '2026-12-03',
];
Map<String, dynamic> read(String path) {
  final actual = path;
  return jsonDecode(fixtureFile(actual).readAsStringSync())
      as Map<String, dynamic>;
}

void main() {
  test(
    'MJU native current English writing direct75min planned dates,220whole preservation,8courses full3mode Drive',
    () {
      final proof = read('$folder/independent-literal-date-clock-proof.json');
      for (final input in proof['sourceInputs'] as List) {
        expect(
          sha256
              .convert(fixtureFile(input['path'] as String).readAsBytesSync())
              .toString(),
          input['sha256'],
        );
      }
      final native = read('$folder/current-official-course-education.json');
      expect(native['sourceUrl'], nativeUrl);
      expect(native['academicYear'], 2026);
      expect(native['semester'], '2');
      expect(native['bodyRepeatsSameWeekdayTimeProfessorEligibility'], true);
      expect(
        native['nativeTableRow']['nativeAcademicHeading'],
        '2026-2 학기 외국인 학생 전용 [영어작문] 과목 안내',
      );
      expect(native['nativeTableRow']['nativeTime'], '화/목 12:00~13:15');
      expect(native['nativeTableRow']['professor'], '이은주');
      expect(
        native['nativeTableRow']['nativeRestriction'],
        '외국인 학생 전용 과목은 한국인 학생은 수강 불가하니 수강신청에 유의 바랍니다.',
      );
      final prior = <String, dynamic>{};
      final parts = <Map<String, dynamic>>[];
      for (final campus in ['humanities', 'natural', 'unknown']) {
        final original = read(proof['priorDatasetPaths'][campus] as String);
        for (final c in original['courses'] as List) {
          prior[c['sourceId'] as String] = c;
        }
        parts.add(
          campus == 'unknown'
              ? read(
                  '$folder/mju-unknown-2026-2.english-writing-direct-clock-v5.json',
                )
              : original,
        );
      }
      expect(prior, hasLength(220));
      expect(prior.values.where((c) => c['courseName'] == '영어작문'), isEmpty);
      final current = <String, dynamic>{};
      for (final part in parts) {
        for (final c in part['courses'] as List) {
          expect(current.containsKey(c['sourceId']), false);
          current[c['sourceId'] as String] = c;
        }
      }
      expect(current, hasLength(221));
      for (final entry in prior.entries) {
        expect(current[entry.key], entry.value);
      }
      const key = '$nativeUrl#table=1&row=2';
      expect(prior.containsKey(key), false);
      final row = current[key] as Map;
      expect(
        row['sourceEducation']['nativePublicCells'],
        native['nativeTableRow'],
      );
      expect(row['courseName'], '영어작문');
      expect(row['professor'], '이은주');
      expect(row['courseCode'], '');
      expect(row['section'], '');
      expect(row['campus'], 'unknown');
      expect(row['sourceClassroom'], '');
      expect(row['sourceEducation']['nativeLectureNumberPublished'], false);
      expect(row['sourceEducation']['nativeClosureJoinPossible'], false);
      expect(row['sourceEducation']['actualOperatingMeetingsConfirmed'], false);
      final meetings = row['schedules'] as List;
      expect(meetings.map((m) => m['date']).toList(), literalDates);
      expect(proof['literalDates'], literalDates);
      for (final meeting in meetings) {
        expect(
          meeting['weekday'],
          DateTime.parse(meeting['date'] as String).weekday,
        );
        expect([2, 4], contains(meeting['weekday']));
        expect(meeting['startMinute'], 12 * 60);
        expect(meeting['endMinute'], 13 * 60 + 15);
        expect(meeting['classroom'], '');
        expect(meeting.containsKey('deliveryMode'), false);
      }
      expect(literalDates, isNot(contains('2026-09-24')));
      expect(literalDates, isNot(contains('2026-10-20')));
      expect(literalDates, isNot(contains('2026-10-22')));
      expect(
        literalDates.every(
          (s) =>
              s.compareTo('2026-09-01') >= 0 && s.compareTo('2026-12-07') <= 0,
        ),
        true,
      );
      final courses = parts
          .expand((d) => UniversityDataset.fromJson(d).courses)
          .toList();
      expect(courses, hasLength(221));
      final plans = courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(plans, hasLength(8));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 197);
      final added = courses.singleWhere((c) => c.sourceId == key);
      expect(added.meetings, hasLength(25));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = plans
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
        final lookup = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(8));
        expect(restored.map((c) => c.sourceId).toSet(), lookup.keys.toSet());
        for (final c in restored) {
          expect(
            c.toJson()..remove('id'),
            lookup[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.isValid, true);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
        final newClass = restored.singleWhere((c) => c.sourceId == key);
        expect(newClass.note, contains('한국인 학생 수강 불가'));
        expect(newClass.note, contains('미게시'));
        expect(newClass.note, contains('계획 예약'));
        expect(newClass.note, contains('내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다'));
      }
    },
  );
}
