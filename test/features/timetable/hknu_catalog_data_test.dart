import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test('HKNU integrated account uses own catalog and campus labels', () {
    for (final id in [
      'academyinfo:0000037',
      'institution:academyinfo:0000037',
    ]) {
      final p = AcademicProfile(
        universityId: id,
        universityName: '한경국립대학교',
        schoolKind: 'fourYear',
      );
      expect(p.timetableUniversity, 'hknu');
      expect(p.timetableCampus, 'anseong');
      expect(p.academicSourceId, 'hknu');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한경국립대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
    for (final campus in ['anseong', 'pyeongtaek']) {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/hknu-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        UniversityDataset.fromJson(raw).campusName,
        campus == 'anseong' ? '안성' : '평택',
      );
    }
  });

  test(
    'HKNU exact native identities, conditions, dated plans and Drive roundtrip',
    () {
      final values = <String, TimetableSyncValue>{};
      final ids = <String>{};
      var whole = 0, scheduled = 0, meetings = 0;
      var cancelled = 0, red = 0, supplements = 0, newSections = 0;
      var offline = 0, remote = 0, safety = 0, conditions = 0;
      const holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (final campus in ['anseong', 'pyeongtaek']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/hknu-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        whole += dataset.courses.length;
        final rows = (raw['courses'] as List).cast<Map<String, dynamic>>();
        for (final course in dataset.courses) {
          expect(ids.add(course.sourceId), isTrue);
          expect(course.code, matches(RegExp(r'^\d{10}$')));
          expect(course.section, matches(RegExp(r'^[A-Z]\d{2}$')));
          expect(course.codeAndSection, '${course.code}-${course.section}');
          expect(course.departments, isNotEmpty);
          final row = rows.singleWhere((r) => r['sourceId'] == course.sourceId);
          final metadata = row['metadata'] as Map<String, dynamic>;
          expect(metadata['actualAttendanceConfirmed'], isFalse);
          if (metadata.containsKey('currentPublishedStudentCondition')) {
            conditions++;
            expect(course.remarks, contains('수강신청'));
          }
          if (metadata['newPublishedNativeSection'] == true) {
            newSections++;
          }
          if (metadata.containsKey('currentFinalPublishedCancellation')) {
            cancelled++;
            expect(course.hasSchedulableMeetings, isFalse);
            expect(course.remarks, contains('최종폐강'));
          }
          final general =
              metadata['currentGeneralPublication'] as Map<String, dynamic>?;
          if (general != null) {
            if (general['redBackgroundGeneralStudentRestriction'] == true) {
              red++;
              expect(course.remarks, contains('일반 재학생 수강 불가'));
            }
            final fields =
                general['actualEducationalFields'] as Map<String, dynamic>;
            if (fields['원격여부'] == 'Y') {
              remote++;
              expect(course.hasSchedulableMeetings, isFalse);
            }
          }
          supplements +=
              (metadata['currentGeneralSupplementaryEducationalRows']
                          as List? ??
                      [])
                  .length;
          if (metadata.containsKey('currentSafetyMergedEducationalCells')) {
            safety++;
          }
          if (metadata.containsKey('publishedMixedOfflineSchedule') &&
              course.hasSchedulableMeetings) {
            offline++;
          }
          meetings += course.meetings.length;
          for (final meeting in course.meetings) {
            expect(meeting.teachingDate!.weekday, meeting.weekday);
            expect(
              meeting.date!.compareTo('2026-09-01'),
              greaterThanOrEqualTo(0),
            );
            expect(meeting.date!.compareTo('2026-12-21'), lessThanOrEqualTo(0));
            expect(holidays, isNot(contains(meeting.date)));
            if (meeting.date == '2026-12-15') {
              expect(meeting.weekday, 2);
            }
            if (meeting.date == '2026-12-16') {
              expect(meeting.weekday, 3);
            }
          }
          if (!course.hasSchedulableMeetings) {
            continue;
          }
          scheduled++;
          for (final mode in [
            LectureMode.inPerson,
            LectureMode.liveOnline,
            LectureMode.video,
          ]) {
            final imported = course.toTimetable(
              id: course.sourceId,
              mode: mode,
            );
            expect(imported.isValid, isTrue, reason: course.sourceId);
            final restored = TimetableClass.fromJson(
              jsonDecode(jsonEncode(imported.toJson())) as Map<String, dynamic>,
            );
            expect(restored.toJson(), imported.toJson());
            expect(restored.defaultMode, mode);
            expect(restored.note, course.remarks);
            if (mode == LectureMode.inPerson) {
              final key = timetableCourseSyncKey(imported);
              values[key] = TimetableSyncValue(
                {...imported.toJson(), 'id': key},
                DateTime.utc(2026, 10, 8),
                'research',
              );
            }
          }
        }
      }
      final architectureRaw =
          jsonDecode(
                File(
                  'assets/timetable/hknu-anseong-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final architectureDataset = UniversityDataset.fromJson(architectureRaw);
      final history = architectureDataset.courses.singleWhere(
        (c) => c.code == '0000270016' && c.section == 'A01',
      );
      expect(history.professor, '신혜원');
      expect(
        history.meetings.every(
          (m) =>
              m.originalStartMinute == 780 &&
              m.originalEndMinute == 960 &&
              m.classroom == '제3공학관 501호',
        ),
        isTrue,
      );
      final design = architectureDataset.courses.singleWhere(
        (c) => c.code == '0000270009' && c.section == 'A02',
      );
      expect(design.professor, '조우성 / 김준경');
      expect(
        design.meetings.every(
          (m) =>
              m.originalStartMinute == 780 &&
              m.originalEndMinute == 1130 &&
              m.classroom == 'R606',
        ),
        isTrue,
      );
      expect(design.remarks, contains('저번 학기와 같은 교수님 수강 불가'));
      final computational = architectureDataset.courses.singleWhere(
        (c) => c.code == '0000510013' && c.departments.contains('건축공학전공'),
      );
      expect(
        computational.meetings.every(
          (m) =>
              m.originalStartMinute == 720 &&
              m.originalEndMinute == 950 &&
              m.classroom == '공실관203호',
        ),
        isTrue,
      );
      final steel = architectureDataset.courses.singleWhere(
        (c) => c.code == '0000960078',
      );
      expect(
        steel.meetings.every(
          (m) => m.originalStartMinute == 960 && m.originalEndMinute == 1070,
        ),
        isTrue,
      );
      for (final course in architectureDataset.courses.where(
        (c) =>
            c.departments.contains('건축학전공') &&
            (c.code == '0000033423' ||
                c.code == '0000033330' ||
                c.code == '2002470013'),
      )) {
        expect(course.hasSchedulableMeetings, isFalse);
        expect(course.remarks, anyOf(contains('미개설'), contains('자율 운영')));
      }
      final industrial = architectureDataset.courses.singleWhere(
        (c) => c.code == '0000033335' && c.departments.contains('건축학전공'),
      );
      expect(industrial.hasSchedulableMeetings, isTrue);
      expect(
        industrial.meetings.every(
          (m) => m.originalStartMinute == 540 && m.originalEndMinute == 830,
        ),
        isTrue,
      );
      for (final code in ['0000250078', '1000230015']) {
        final course = architectureDataset.courses.singleWhere(
          (c) => c.code == code && c.section == 'B01',
        );
        expect(course.meetings.length, 30);
        expect(course.remarks, contains('실제 게시 integer 교시표'));
        expect(course.remarks, isNot(contains('전체 회의 완료가 아님')));
      }
      final nightCad = architectureDataset.courses.singleWhere(
        (c) => c.code == '1000230015' && c.section == 'B01',
      );
      expect(
        nightCad.meetings
            .where((m) => m.weekday == 4)
            .every(
              (m) =>
                  m.originalStartMinute == 1270 &&
                  m.originalEndMinute == 1360 &&
                  m.classroom == '218',
            ),
        isTrue,
      );
      expect(
        nightCad.meetings
            .where((m) => m.weekday == 2)
            .every(
              (m) =>
                  m.originalStartMinute == 1220 &&
                  m.originalEndMinute == 1360 &&
                  m.classroom == '공동실험실습관401호',
            ),
        isTrue,
      );
      expect(nightCad.remarks, contains('수강인원 제한35명'));
      final nightFluid = architectureDataset.courses.singleWhere(
        (c) => c.code == '1000230014' && c.section == 'B01',
      );
      expect(nightFluid.professor, '이정후');
      expect(
        nightFluid.meetings.every(
          (m) => m.originalStartMinute == 1080 && m.originalEndMinute == 1265,
        ),
        isTrue,
      );
      final survey = architectureDataset.courses.singleWhere(
        (c) => c.code == '0000250082' && c.section == 'B01',
      );
      expect(survey.meetings.length, 30);
      expect(
        survey.meetings
            .where((m) => m.weekday == 1)
            .every(
              (m) =>
                  m.originalStartMinute == 1270 && m.originalEndMinute == 1315,
            ),
        isTrue,
      );
      expect(survey.remarks, contains('하위학년 수업 수강은 원칙 불허'));
      final intensive = architectureDataset.courses.singleWhere(
        (c) => c.code == '2002430019' && c.section == 'B01',
      );
      expect(intensive.hasSchedulableMeetings, isFalse);
      expect(intensive.remarks, contains('몰입형'));
      expect(intensive.remarks, contains('잔여학점'));
      expect(whole, 1493);
      expect(scheduled, 1143);
      expect(meetings, 19470);
      expect(cancelled, 34);
      expect(red, 20);
      expect(supplements, 16);
      expect(newSections, 6);
      expect(remote, 3);
      expect(safety, 24);
      expect(offline, 18);
      expect(conditions, 4);
      final document = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
      );
      expect(restored.courses.length, 1143);
      for (final entry in restored.courses.entries) {
        expect(entry.value.value, values[entry.key]!.value);
      }
    },
  );
}
