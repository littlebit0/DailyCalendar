import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Kookmin whole current catalog retains dated teaching and unknown operation',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'kookmin',
      )).single;
      final courses = data.courses;
      expect(data.campusName, '북악');
      expect(courses, hasLength(2985));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2985));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2944));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(22),
      );
      final blocked = courses.where((c) => c.scheduleStatus == 'unrecognized');
      expect(blocked, hasLength(19));
      for (final c in blocked) {
        expect(c.meetings, isEmpty);
        expect(c.sourceSchedule, isNotEmpty);
      }
      expect(courses.any((c) => c.codeAndSection == '0504202-01'), isFalse);
      final department = courses.singleWhere(
        (c) => c.codeAndSection == '1147400-01',
      );
      expect(department.departments, ['공학교육혁신센터']);
      // The official catalog publishes 학과미배정 as a top-level offering unit.
      final unassigned = courses.where((c) => c.departments.contains('학과미배정'));
      expect(unassigned, hasLength(23));
      for (final c in unassigned) {
        expect(
          c.offeringOrganizations.any(
            (o) => o.college == '학과미배정' && o.department == null,
          ),
          isTrue,
        );
      }
      // 학칙 제26조 제3항·학·석사 연계과정 운영요강 제10조에 따른 공식 'GraduateLinked'
      // 강좌 51개(폐강 표시 1개 제외)는 대학원 단위 소속으로 들어간다.
      final graduate = courses.where(
        (c) => c.departmentRemarks.values.any(
          (r) => r.contains('학칙 제26조 제3항, 학·석사 연계과정 운영요강 제10조'),
        ),
      );
      expect(graduate, hasLength(51));
      expect(courses.any((c) => c.codeAndSection == '662450b-01'), isFalse);
      const graduateSchools = {
        '일반대학원',
        '테크노디자인전문대학원',
        'AIㆍSW대학원',
        '자동차모빌리티대학원',
      };
      for (final c in graduate) {
        expect(c.hasSchedulableMeetings, isTrue);
        expect(
          c.offeringOrganizations.any(
            (o) => graduateSchools.contains(o.college),
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
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'kookmin')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 14));
      expect(period.contains(DateTime(2026, 12, 15)), isFalse);
    },
  );
}
