import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Kunsan integrated profile exposes own catalog and rejects foreign campuses',
    () {
      for (final id in [
        'academyinfo:0000009',
        'institution:academyinfo:0000009',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '국립군산대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'kunsan');
        expect(p.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '국립군산대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          isFalse,
        );
      }
    },
  );
  test(
    'Kunsan published planned reservations preserve partial support and official semester on Drive',
    () {
      final courses = [
        for (final campus in ['unknown', 'saemangeum'])
          ...UniversityDataset.fromJson(
            jsonDecode(
                  File(
                    'assets/timetable/kunsan-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>,
          ).courses,
      ];
      expect(courses.length, 1718);
      expect(courses.map((c) => c.sourceId).toSet().length, 1718);
      expect(courses.where((c) => c.hasSchedulableMeetings).length, 1400);
      expect(courses.expand((c) => c.meetings).length, 30885);
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized').length,
        0,
      );
      // 원문자 수가 실습 시수와 다른 음악 분반도 적힌 교시대로: 전공실습(2) 12 토① ② ④ ⑤.
      final gap = courses.singleWhere((c) => c.codeAndSection == '110404-12');
      expect(
        gap.meetings
            .map((m) => (m.originalStartMinute, m.originalEndMinute))
            .toSet(),
        {(550, 670), (730, 850)},
      );
      // 토요일 원문자도 같은 번호 교시: 기초실기(2) 01 토① = 09:10~10:10.
      final saturday = courses.singleWhere(
        (c) => c.codeAndSection == '109430-01',
      );
      expect(
        saturday.meetings
            .map((m) => (m.weekday, m.originalStartMinute, m.originalEndMinute))
            .toSet(),
        {(6, 550, 610)},
      );
      // 0시수 현장실습·12월 집중강의는 시간 미정, 시간이 빈 JST 강좌도 시간 미정.
      for (final code in ['104025-06', '116759-01', '115186-01']) {
        final c = courses.singleWhere((c) => c.codeAndSection == code);
        expect(c.scheduleStatus, 'unscheduled');
        expect(c.meetings, isEmpty);
      }
      // 야간 11~13교시는 1~10교시와 같은 60분 슬롯으로 이어 19:10~22:10.
      final night = courses.singleWhere((c) => c.codeAndSection == '100088-02');
      expect(night.sourceSchedule, '목11 12 13 [사회관-2403]');
      expect(night.meetings, hasLength(13));
      expect(
        night.meetings.every(
          (m) =>
              m.originalStartMinute == 1150 &&
              m.originalEndMinute == 1330 &&
              m.classroom == '사회관-2403',
        ),
        isTrue,
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled').length,
        318,
      );
      // 원문자 교시는 같은 번호 교시의 실습 시간이다(이론·실습 시수와 일치): 월①②=09:10~11:10.
      final circled = courses.singleWhere(
        (c) => c.codeAndSection == '115911-01',
      );
      expect(circled.sourceSchedule, '월① ②,수3 [황룡문화관-3306]');
      expect(
        circled.meetings
            .map((m) => (m.weekday, m.originalStartMinute, m.originalEndMinute))
            .toSet(),
        {(1, 550, 670), (3, 670, 730)},
      );
      expect(circled.remarks, isNot(contains('부분')));
      expect(circled.remarks, contains('원문자'));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses) {
          expect(c.remarks, contains('9월 4일·9월 9일'));
          expect(c.remarks, contains('통합정보시스템'));
          if (!c.hasSchedulableMeetings) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, isTrue);
          // 교시표 1~10교시: 09:10 시작, 50분 수업+10분 쉬는 시간 = 60분 슬롯(11교시 이후도 같은 길이).
          for (final m in c.meetings) {
            expect(m.originalStartMinute % 60, 10, reason: c.codeAndSection);
            expect(m.originalStartMinute, inInclusiveRange(550, 1150));
            expect(
              (m.originalEndMinute - m.originalStartMinute) % 60,
              0,
              reason: c.codeAndSection,
            );
          }
          expect(saved.period!.start, DateTime(2026, 8, 31));
          expect(saved.period!.end, DateTime(2026, 12, 17));
          expect(saved.note, contains('학기'));
          for (final m in saved.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            expect(m.teachingDate!.isBefore(DateTime(2026, 8, 31)), isFalse);
            expect(m.teachingDate!.isAfter(DateTime(2026, 12, 10)), isFalse);
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-09-26',
              '2026-10-03',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
          }
          final restored = TimetableClass.fromJson(
            jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
          );
          expect(restored.toJson(), saved.toJson());
          expect(restored.defaultMode, mode);
          expect(restored.note, c.remarks);
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
        }
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        expect(restored.courses.length, 1400);
        for (final e in restored.courses.entries) {
          expect(e.value.value, values[e.key]!.value);
        }
      }
    },
  );
}
