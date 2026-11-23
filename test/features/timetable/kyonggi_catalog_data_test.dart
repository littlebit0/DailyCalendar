import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Kyonggi profile maps Suwon main and Seoul campus catalogs', () {
    for (final id in [
      'academyinfo:0000056',
      'institution:academyinfo:0000056',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '경기대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'kyonggi');
      expect(profile.timetableCampus, 'suwon');
      final seoul = AcademicProfile(
        universityId: id,
        universityName: '경기대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000058',
      );
      expect(seoul.timetableCampus, 'seoul');
      expect(seoul.timetableSupported, isTrue);
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경기대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test(
    'actual Kyonggi subject codes and stable registration IDs preserve plans through Drive',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/kyonggi-suwon-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final model = UniversityDataset.fromJson(raw);
      expect(model.courses.length, 1640);
      expect(model.courses.where((c) => c.hasSchedulableMeetings).length, 1593);
      const closed = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
        '2026-11-08',
      };
      final values = <String, TimetableSyncValue>{};
      var count = 0;
      for (final c in model.courses) {
        expect(c.code, matches(RegExp(r'^[A-Z]{2,4}\d{3,4}$')));
        expect(c.section, isEmpty);
        expect(c.codeAndSection, c.code);
        final metadata =
            (raw['courses'] as List).singleWhere(
                  (r) => r['sourceId'] == c.sourceId,
                )['metadata']
                as Map;
        if (metadata['actualOpeningDepartmentFromPageHeader']
            case final String header) {
          expect(c.departments, [header]);
          expect(c.departmentCredits[header], c.credits);
          expect(c.remarkForDepartment(header), c.sourceRemarks);
        } else {
          expect(c.departments, isEmpty);
        }
        if (metadata['sourcePDF'] == '2026-2_교양.pdf') {
          expect(c.categoriesFor(), [CourseCategory.generalEducation]);
          expect(c.sourceRemarks, contains(metadata['nativeClassification']));
        }
        expect(c.sourceRemarks, contains('분반 번호 미게시'));
        count += c.meetings.length;
        for (final m in c.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(m.teachingDate!.isBefore(DateTime(2026, 9, 1)), isFalse);
          expect(m.teachingDate!.isAfter(DateTime(2026, 12, 14)), isFalse);
          expect(closed, isNot(contains(m.date)));
          // 학사안내(key=8430): 60분제는 50분 수업+10분 휴식(슬롯 60분),
          // 90분제(L)는 75분 수업+15분 휴식(슬롯 90분)이라 휴식 포함 슬롯이다.
          final span = m.originalEndMinute - m.originalStartMinute;
          if (c.sourceSchedule.contains('L')) {
            expect(span % 90, 0, reason: c.sourceId);
          } else {
            expect(m.originalStartMinute % 60, 0, reason: c.sourceId);
            expect(span % 60, 0, reason: c.sourceId);
          }
          for (final o in c.meetings) {
            if (identical(m, o) || m.date != o.date) continue;
            expect(
              m.classroom == o.classroom &&
                  (o.originalStartMinute - m.originalEndMinute).abs() < 60 &&
                  o.originalStartMinute >= m.originalEndMinute,
              isFalse,
              reason: '${c.sourceId} ${m.date}',
            );
          }
        }
        if (!c.hasSchedulableMeetings) {
          continue;
        }
        for (final mode in [
          LectureMode.inPerson,
          LectureMode.liveOnline,
          LectureMode.video,
        ]) {
          final imported = c.toTimetable(id: c.sourceId, mode: mode);
          expect(imported.isValid, isTrue);
          final restored = TimetableClass.fromJson(
            jsonDecode(jsonEncode(imported.toJson())) as Map<String, dynamic>,
          );
          expect(restored.toJson(), imported.toJson());
          expect(restored.defaultMode, mode);
          expect(restored.note, c.remarks);
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
      for (final registration in ['0577', '0580']) {
        final changed = model.courses.singleWhere(
          (c) => c.sourceId.endsWith(registration),
        );
        final thursdays = changed.meetings.where((m) => m.weekday == 4);
        expect(thursdays.length, 14);
        expect(
          thursdays.every(
            (m) =>
                m.originalStartMinute == 540 &&
                m.originalEndMinute == 600 &&
                m.classroom.isEmpty,
          ),
          isTrue,
        );
      }
      expect(count, 23527);
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final restoredDoc = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(restoredDoc.courses.length, 1593);
      for (final e in restoredDoc.courses.entries) {
        expect(e.value.value, values[e.key]!.value);
      }
      final split = model.courses.singleWhere(
        (c) => c.sourceId.endsWith('0415'),
      );
      expect(split.code, 'AS830');
      expect(
        split.meetings
            .where((m) => m.originalStartMinute == 540)
            .every((m) => m.classroom.contains('6303')),
        isTrue,
      );
      expect(
        split.meetings
            .where((m) => m.originalStartMinute == 600)
            .every((m) => m.classroom.contains('종합201')),
        isTrue,
      );
      for (final id in ['1633', '1634', '1635', '1638', '1639', '1640']) {
        final partial = model.courses.singleWhere(
          (c) => c.sourceId.endsWith(id),
        );
        expect(partial.meetings.map((m) => m.date), [
          '2026-09-02',
          '2026-09-09',
          '2026-09-16',
          '2026-09-23',
          '2026-10-14',
          '2026-10-21',
        ]);
        expect(partial.remarks, contains('종료일 확정 주장이 아니며'));
      }
      for (final course in model.courses.where((c) => c.code == 'IA002')) {
        expect(
          course.meetings.any(
            (m) =>
                m.date!.compareTo('2026-09-29') >= 0 &&
                m.date!.compareTo('2026-10-12') <= 0,
          ),
          isFalse,
        );
        expect(course.remarks, contains('현직자 2명 이상'));
      }
      for (final id in ['1492', '1493', '1494']) {
        expect(
          model.courses
              .singleWhere((c) => c.sourceId.endsWith(id))
              .hasSchedulableMeetings,
          isFalse,
        );
      }
      final ninth = model.courses.singleWhere(
        (c) => c.sourceId.endsWith('1340'),
      );
      expect(
        ninth.meetings.every(
          (m) => m.originalStartMinute == 1020 && m.originalEndMinute == 1080,
        ),
        isTrue,
      );
      // 2026-2 공식 변경 공지: 바뀐 요일만 반영하고 공지에 없는 강의실은 비운다.
      for (final (id, weekday, count) in [('0529', 5, 13), ('1300', 3, 15)]) {
        final moved = model.courses.singleWhere((c) => c.sourceId.endsWith(id));
        expect(moved.meetings.length, count);
        expect(
          moved.meetings.every(
            (m) =>
                m.weekday == weekday &&
                m.originalStartMinute == 840 &&
                m.originalEndMinute == 1020 &&
                m.classroom.isEmpty,
          ),
          isTrue,
        );
      }
      for (final (id, professor) in [
        ('1300', '신원경'),
        ('1313', '임용준'),
        ('1314', '한수민'),
      ]) {
        expect(
          model.courses.singleWhere((c) => c.sourceId.endsWith(id)).professor,
          professor,
        );
      }
      for (final id in ['0058', '0159', '1545', '1546']) {
        expect(
          model.courses
              .singleWhere((c) => c.sourceId.endsWith(id))
              .hasSchedulableMeetings,
          isFalse,
        );
      }
    },
  );

  test('Kyonggi Seoul partial catalog keeps official notice rows', () async {
    final datasets = await UniversityCatalog.load(
      bundle: FileAssetBundle(),
      university: 'kyonggi',
    );
    expect(datasets.map((d) => d.campus).toSet(), {'suwon', 'seoul'});
    final seoul = datasets.singleWhere((d) => d.campus == 'seoul');
    final courses = seoul.courses;
    expect(courses.length, 67);
    expect(courses.map((c) => c.sourceId).toSet().length, 67);
    expect(courses.where((c) => c.hasSchedulableMeetings).length, 54);
    expect(courses.where((c) => c.scheduleStatus == 'unscheduled').length, 13);
    expect(courses.where((c) => c.scheduleStatus == 'unrecognized'), isEmpty);
    UniversityCourse byReg(String reg) =>
        courses.singleWhere((c) => c.sourceId.endsWith('-$reg'));
    // 2차 폐강 공지 "서울 9037 대학영어5(시사영어) 금789": 서울 주간 60분제 7~9교시.
    final english = byReg('9037');
    expect(english.title, '대학영어5(시사영어)');
    expect(english.sourceSchedule, '금789');
    // 학수코드는 수원 강좌가 아니라 625109 붙임1(2026 교양 교육과정) 원문에서 온다.
    expect(english.code, 'AS364');
    expect(english.remarks, contains('AS042 시사영어 3학점 외영 AS364 대학영어5(시사영어)'));
    expect(english.sourceClassification, '교양/일반선택/교육학전공');
    // 원문에 학수코드가 없는 강좌는 비워 둔다.
    expect(byReg('9051').code, isEmpty);
    expect(english.meetings.single.weekday, 5);
    expect(english.meetings.single.originalStartMinute, 900);
    expect(english.meetings.single.originalEndMinute, 1080);
    // 변동 예정 공지: 화 567 -> 화 789 변경 후 시각.
    final changed = byReg('9126');
    expect(changed.meetings.single.originalStartMinute, 900);
    expect(changed.remarks, contains('화 567 -> 화 789'));
    // 이러닝 합반: 시각이 없어 시간 미정으로 추가된다.
    final elearning = byReg('9001');
    expect(elearning.scheduleStatus, 'unscheduled');
    expect(elearning.code, 'AT020');
    expect(elearning.remarks, contains('0001로 합반'));
    expect(byReg('9129').hasSchedulableMeetings, isFalse);
    // 625108 첨부 p.12 서울 교양 그룹 "19.대학영어(화123,Advanced)": 화 1~3교시.
    final group = courses.singleWhere((c) => c.sourceId.endsWith('-group-19'));
    expect(group.title, '대학영어');
    expect(group.code, 'AS395');
    expect(group.meetings.single.weekday, 2);
    expect(group.meetings.single.originalStartMinute, 540);
    expect(group.meetings.single.originalEndMinute, 720);
    // 같은 과목·같은 시각의 폐강 공지 강좌(9282 월67)가 있는 그룹 06은 중복으로 넣지 않는다.
    expect(courses.where((c) => c.sourceId.endsWith('-group-06')), isEmpty);
    for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
      expect(
        c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).isValid,
        isTrue,
      );
    }
  });
}
