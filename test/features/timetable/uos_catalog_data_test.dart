import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'UOS current whole catalog preserves unknown clocks and excludes nonregular source slots',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'uos',
      )).single;
      final courses = data.courses;
      expect(courses, hasLength(2112));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2112));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1488));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(619),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(5),
      );
      // 2026-11-23 사용자 결정: 11~15교시는 같은 60분 슬롯으로 이어 계산한다.
      final late = courses.singleWhere((c) => c.codeAndSection == '46105-01');
      expect(late.meetings.single.startMinute, 1320);
      expect(late.meetings.single.endMinute, 1440);
      final evening = courses.singleWhere(
        (c) => c.codeAndSection == '45129-01',
      );
      expect(evening.meetings.single.startMinute, 1080);
      expect(evening.meetings.single.endMinute, 1320);
      final rooms = courses.singleWhere((c) => c.codeAndSection == '01997-01');
      expect(rooms.meetings.single.startMinute, 960);
      expect(rooms.meetings.single.classroom, '33-101, 5-202');
      final digital = courses.singleWhere(
        (c) => c.codeAndSection == '02080-01',
      );
      expect(digital.meetings.single.startMinute, 900);
      expect(digital.meetings.single.endMinute, 960);
      expect(digital.meetings.single.classroom, '20-118,19');
      // 교시 슬롯 = 수업 50분 + 쉬는 시간 10분(09:00부터 60분 간격, 15교시까지).
      for (final c in courses) {
        for (final m in c.meetings) {
          expect(
            m.startMinute,
            inInclusiveRange(540, 1380),
            reason: c.sourceId,
          );
          expect((m.startMinute - 540) % 60, 0, reason: c.sourceId);
          expect((m.endMinute - 540) % 60, 0, reason: c.sourceId);
        }
        for (final m in c.meetings) {
          for (final n in c.meetings) {
            if (identical(m, n) || m.weekday != n.weekday) continue;
            if (m.classroom != n.classroom) continue;
            expect(
              n.startMinute - m.endMinute,
              isNot(inInclusiveRange(0, 59)),
              reason: '${c.sourceId} 연속 구간은 합쳐야 함',
            );
          }
        }
      }
      for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: c.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
      }
      final career = courses.where((c) => c.code == '01951');
      expect(career, hasLength(21));
      for (final c in career) {
        expect(c.meetings, isEmpty);
        expect(c.departmentRemarks.values.join('\n'), contains('비실시간'));
        expect(c.sourceSchedule, isNotEmpty);
      }
      for (final code in [
        '01564',
        '02072',
        '02082',
        '02089',
        '02105',
        '92105',
        '92106',
        '92107',
        '92108',
        '92109',
      ]) {
        for (final c in courses.where((c) => c.code == code)) {
          expect(c.meetings, isEmpty);
          expect(c.period, isNull);
        }
      }
      expect(
        courses
            .singleWhere((c) => c.codeAndSection == '34058-01')
            .meetings
            .first
            .classroom,
        '11-304,5',
      );
    },
  );

  test(
    'UOS academic profile enables catalog with real teaching year and term boundaries',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000040',
        universityName: '서울시립대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000040',
      );
      expect(profile.timetableUniversity, 'uos');
      expect(profile.timetableCampus, 'main');
      final period = (await TimetablePeriodDefaults.load(
        bundle: FileAssetBundle(),
      )).periodFor(2026, '2', university: 'uos')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 21));
      expect(period.contains(DateTime(2026, 12, 22)), isFalse);
    },
  );
}
