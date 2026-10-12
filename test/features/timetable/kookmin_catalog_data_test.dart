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
      expect(courses, hasLength(2941));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2941));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2900));
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
