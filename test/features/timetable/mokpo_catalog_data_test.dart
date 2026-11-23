import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Mokpo whole educational scope restores verified ordinary dates and rooms',
    () async {
      final data = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'mokpo',
      );
      expect(
        {for (final d in data) d.campus: d.courses.length},
        {'dorim': 721, 'damyang': 19, 'unknown': 576},
      );
      final courses = data.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(1316));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1233));
      // 남은 미확정은 UNCO04와 교무과 편성표 모두 시간이 빈 강좌뿐이다.
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(77),
      );
      // UNCO04 시간 칸이 빈 창의인성프로젝트2: 교무과 편성표 "금 13~18교시"(15:00~18:00).
      final mentoring = courses.singleWhere(
        (c) => c.codeAndSection == 'ZZA002-00',
      );
      expect(mentoring.meetings, hasLength(12));
      expect(
        mentoring.meetings.every(
          (m) =>
              m.weekday == 5 &&
              m.originalStartMinute == 900 &&
              m.originalEndMinute == 1080 &&
              m.classroom == '미정',
        ),
        isTrue,
      );
      expect(
        courses
            .where((c) => c.scheduleStatus == 'unrecognized')
            .every((c) => c.sourceSchedule.trim().isEmpty),
        isTrue,
      );
      // 운영 방식 검토로 보류했던 강좌: 공식 30분 교시(10교시 13:30)로 확정.
      final held = courses.singleWhere((c) => c.codeAndSection == 'AA139-00');
      expect(held.scheduleStatus, 'scheduled');
      expect(
        held.meetings
            .where((m) => m.weekday == 1)
            .every(
              (m) =>
                  m.originalStartMinute == 810 &&
                  m.originalEndMinute == 900 &&
                  m.classroom == '인문대학 351',
            ),
        isTrue,
      );
      expect(held.meetings, hasLength(27));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(6),
      );
      // 공개 UNCO04 원표의 교양필수 프론티어정신 9분반(빠져 있던 행 복원).
      final frontier = courses.where((c) => c.code == 'ZAA006').toList();
      expect(frontier, hasLength(9));
      final f09 = frontier.singleWhere((c) => c.codeAndSection == 'ZAA006-09');
      expect(f09.sourceId, 'mokpo/damyang/2026/2/ZAA006/09');
      expect(f09.meetings, hasLength(14));
      expect(
        f09.meetings.every(
          (m) =>
              m.weekday == 3 &&
              m.originalStartMinute == 900 &&
              m.originalEndMinute == 1020 &&
              m.classroom == '(담양)제5학관 강당 5110',
        ),
        isTrue,
      );
      // 최신 공개 조회의 담당교수 표기로 교체(일정은 그대로).
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'ALM048-00').professor,
        '조정현(), 이효빈()',
      );
      // 같은 강좌의 학수번호가 최신 공개 조회에서 KG631 -> KG721로 바뀌었다.
      expect(courses.where((c) => c.code == 'KG631'), isEmpty);
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'KG721-00').sourceId,
        'mokpo/dorim/2026/2/KG721/00',
      );
      final history = courses
          .singleWhere((c) => c.codeAndSection == 'HIS041-00')
          .toTimetable(id: 'history', mode: LectureMode.inPerson);
      expect(classOccurrences([history], [DateTime(2026, 9, 7)]), isEmpty);
      final intensive = courses.singleWhere(
        (c) => c.codeAndSection == 'ABC003-04',
      );
      expect(intensive.meetings, hasLength(15));
      expect(
        intensive.meetings.every(
          (m) =>
              m.originalStartMinute == 1080 &&
              m.originalEndMinute == 1260 &&
              m.classroom == '공과대학4호관 305',
        ),
        isTrue,
      );
      expect(
        intensive.meetings.map((m) => m.date).toSet(),
        containsAll(['2026-10-07', '2026-10-08', '2026-11-26']),
      );

      for (final course in courses) {
        for (final raw in course.departmentClassifications.values) {
          expect(
            courseCategory(raw),
            isNot(CourseCategory.unknown),
            reason: raw,
          );
          if (raw == '전문교양') {
            expect(courseCategory(raw), CourseCategory.generalEducation);
          }
        }
        if (!course.hasSchedulableMeetings) {
          expect(course.meetings, isEmpty, reason: course.sourceId);
          continue;
        }
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.inPerson,
        );
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: course.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
        expect(restored.note, saved.note);
        if (course.codeAndSection == 'ABC003-04') {
          expect(restored.period?.start, DateTime(2026, 10, 7));
          expect(restored.period?.end, DateTime(2026, 11, 26));
        } else {
          expect(restored.period?.start, DateTime(2026, 9, 1));
          expect(restored.period?.end, DateTime(2026, 12, 7));
        }
        expect(
          restored.meetings.every(
            (m) => m.date != null && m.teachingDate!.weekday == m.weekday,
          ),
          isTrue,
        );
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 8, 31),
              DateTime(2026, 9, 24),
              DateTime(2026, 9, 25),
              DateTime(2026, 9, 26),
              DateTime(2026, 10, 3),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 9),
              DateTime(2026, 10, 31),
              DateTime(2026, 12, 8),
              DateTime(2026, 12, 14),
              DateTime(2027, 9, 1),
            ],
          ),
          isEmpty,
          reason: course.sourceId,
        );
        expect(
          classOccurrences([restored], [restored.meetings.first.teachingDate!]),
          isNotEmpty,
        );
      }
    },
  );
  test(
    'Mokpo unified and legacy campus profiles resolve actual campus and term boundaries',
    () async {
      for (final id in [
        'institution:academyinfo:0000011',
        'academyinfo:0000011',
        'academyinfo:0003312',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '국립목포대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'mokpo');
        expect(p.timetableCampus, id.endsWith('3312') ? 'damyang' : 'dorim');
      }
      const p = AcademicProfile(
        universityId: 'institution:academyinfo:0000011',
        universityName: '국립목포대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0003312',
      );
      expect(p.timetableCampus, 'damyang');
      const wrong = AcademicProfile(
        universityId: 'institution:academyinfo:0000011',
        universityName: '국립목포대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000036',
      );
      expect(wrong.timetableCampus, isNull);
      final defaults = await TimetablePeriodDefaults.load(
        bundle: FileAssetBundle(),
      );
      final period = defaults.periodFor(2026, '2', university: 'mokpo');
      expect(period?.start, DateTime(2026, 9, 1));
      expect(period?.end, DateTime(2026, 12, 18));
    },
  );
}
