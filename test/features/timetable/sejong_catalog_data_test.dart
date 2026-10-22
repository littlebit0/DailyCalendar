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
    'Sejong complete catalog preserves department section identities, clocks and restrictions',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'sejong',
      )).single;
      final courses = data.courses;
      expect(courses, hasLength(2645));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2645));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2426));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(219),
      );
      expect(courses.every((c) => c.meetings.every((m) => m.isValid)), isTrue);
      final distinct = courses
          .where((c) => c.codeAndSection == '011839-001')
          .toList();
      expect(distinct.length, greaterThan(1));
      final humanities = distinct.singleWhere(
        (c) => c.departments.contains('인문사회계열'),
      );
      expect(humanities.meetings.single.weekday, 2);
      expect(humanities.meetings.single.startMinute, 1080);
      expect(
        humanities.categoriesFor(),
        contains(CourseCategory.requiredGeneralEducation),
      );
      expect(courses.any((c) => c.remarks.contains('외국인대상')), isTrue);
      expect(courses.any((c) => c.code.startsWith('DGC')), isTrue);
      final physics = courses.singleWhere(
        (c) => c.codeAndSection == '002638-001',
      );
      expect(
        physics.meetings.map(
          (m) => (m.weekday, m.startMinute, m.endMinute, m.classroom),
        ),
        [(1, 540, 660, '호302'), (2, 540, 630, '센B205'), (4, 540, 630, '센B205')],
      );
      expect(
        TimetableClass.fromJson(
          Map<String, dynamic>.from(
            physics
                .toTimetable(id: 'test', mode: LectureMode.inPerson)
                .toJson(),
          ),
        ).isValid,
        isTrue,
      );
    },
  );
  test(
    'Sejong timetable integrates with school profile and only its actual semester dates',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000138',
        universityName: '세종대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000138',
      );
      expect(profile.timetableUniversity, 'sejong');
      expect(profile.timetableCampus, 'main');
      final period = (await TimetablePeriodDefaults.load(
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'sejong')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 21));
      expect(period.contains(DateTime(2026, 8, 31)), isFalse);
      expect(period.contains(DateTime(2026, 12, 22)), isFalse);
    },
  );
}
