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
    'Kookmin whole current catalog retains dated teaching and unknown operation',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'kookmin',
      )).single;
      final courses = data.courses;
      expect(data.campusName, '북악');
      expect(courses, hasLength(3014));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(3014));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2988));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(26),
      );
      expect(courses.where((c) => c.scheduleStatus == 'unrecognized'), isEmpty);
      // 다른 자료와 달라도 공식 강의시간표 시각(수 18:00~20:40)으로 확정한다.
      final law = courses.singleWhere((c) => c.codeAndSection == '1659202-51');
      expect(law.scheduleStatus, 'scheduled');
      expect(law.meetings.first.originalStartMinute, 1080);
      expect(law.meetings.last.originalEndMinute, 1240);
      // 혼합수업이어도 공개 요일·시각을 그대로 확정한다.
      final blended = courses.singleWhere(
        (c) => c.codeAndSection == '1652001-01',
      );
      expect(blended.scheduleStatus, 'scheduled');
      expect(blended.meetings, hasLength(1));
      expect(blended.meetings.single.weekday, 2);
      expect(blended.meetings.single.originalStartMinute, 900);
      expect(blended.meetings.single.originalEndMinute, 1080);
      expect(blended.meetings.single.classroom, '과학관3층23호실');
      // 공식 조회에 폐강(closed) 표기로 남은 분반도 원문 그대로 넣는다(2026-11-23 결정).
      final closed = courses.where((c) => c.remarks.contains('폐강(closed)'));
      expect(closed, hasLength(80));
      final closedSection = courses.singleWhere(
        (c) => c.codeAndSection == '1655101-01',
      );
      expect(closedSection.meetings.single.weekday, 4);
      expect(closedSection.meetings.single.originalStartMinute, 900);
      expect(closedSection.meetings.single.originalEndMinute, 1080);
      // 2026-11-23 공식 조회 목록에 없는 전공실기 7분반은 넣지 않는다.
      for (final key in [
        '0308107-02',
        '0308107-13',
        '0308107-22',
        '0308203-09',
        '0308203-17',
        '0338902-04',
        '0308403-15',
      ]) {
        expect(courses.any((c) => c.codeAndSection == key), isFalse);
      }
      final department = courses.singleWhere(
        (c) => c.codeAndSection == '1147400-01',
      );
      expect(department.departments, ['공학교육혁신센터']);
      // The official catalog publishes 학과미배정 as a top-level offering unit.
      final unassigned = courses.where((c) => c.departments.contains('학과미배정'));
      expect(unassigned, hasLength(25));
      for (final c in unassigned) {
        expect(
          c.offeringOrganizations.any(
            (o) => o.college == '학과미배정' && o.department == null,
          ),
          isTrue,
        );
      }
      final thursday = courses.singleWhere(
        (c) => c.codeAndSection == '0368203-01',
      );
      expect(thursday.meetings, hasLength(12));
      expect(thursday.meetings.every((m) => m.date != null), isTrue);
      expect(
        thursday.meetings.map((m) => m.date),
        isNot(contains('2026-09-24')),
      );
      final strategy = courses.singleWhere(
        (c) => c.codeAndSection == '0716902-02',
      );
      expect(
        strategy.meetings.map((m) => m.date),
        isNot(contains('2026-09-25')),
      );
      expect(
        strategy.meetings.map((m) => m.date),
        isNot(contains('2026-10-09')),
      );
      final saved = strategy.toTimetable(
        id: strategy.sourceId,
        mode: LectureMode.inPerson,
      );
      final restored = TimetableClass.fromJson(saved.toJson());
      final zoom = restored.meetings.singleWhere((m) => m.date == '2026-12-04');
      expect(
        restored.modeOn(zoom, DateTime(2026, 12, 4)),
        LectureMode.liveOnline,
      );
      expect(zoom.classroom, isEmpty);
      final literature = courses.singleWhere(
        (c) => c.codeAndSection == '1651901-01',
      );
      expect(literature.meetings, hasLength(24));
      for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
        expect(
          TimetableClass.fromJson(
            c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).toJson(),
          ).isValid,
          isTrue,
        );
      }
      for (final label in ['기초교양', '핵심교양', '자유교양']) {
        expect(courseCategory(label), CourseCategory.generalEducation);
      }
    },
  );

  test(
    'Kookmin normal teaching range excludes conditional makeup recurrence',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000078',
        universityName: '국민대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000078',
      );
      expect(profile.timetableUniversity, 'kookmin');
      expect(profile.timetableCampus, 'main');
      final period = (await TimetablePeriodDefaults.load(
        bundle: FileAssetBundle(),
      )).periodFor(2026, '2', university: 'kookmin')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 14));
      expect(period.contains(DateTime(2026, 12, 15)), isFalse);
    },
  );
}
