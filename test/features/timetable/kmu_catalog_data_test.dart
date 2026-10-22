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
    'KMU current whole catalog retains actual campuses, clocks and exceptions',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'kmu',
      );
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'seongseo': 2829, 'daemyeong': 330, 'other': 7},
      );
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(3166));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2997));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(162),
      );
      final blocked = courses.where((c) => c.scheduleStatus == 'unrecognized');
      expect(blocked, hasLength(7));
      for (final c in blocked) {
        expect(c.meetings, isEmpty);
        expect(c.sourceSchedule, isNotEmpty);
        expect(c.remarks, contains('적용 기간 미확정'));
      }
      expect(courses.any((c) => c.codeAndSection == '32233-01'), isFalse);
      final changed = courses.singleWhere(
        (c) => c.codeAndSection == '46708-01',
      );
      expect(changed.sourceSchedule, '목15:00~17:50(음101)');
      expect(changed.sourceClassroom, '음101');
      expect(changed.meetings.single.originalEndMinute, 1070);
      for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
        expect(
          TimetableClass.fromJson(
            c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).toJson(),
          ).isValid,
          isTrue,
        );
      }
      expect(courseCategory('균형교양'), CourseCategory.generalEducation);
      expect(courseCategory('일반교양'), CourseCategory.generalEducation);
    },
  );

  test(
    'KMU unified profile uses current actual semester and campus filter',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000068',
        universityName: '계명대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000068',
      );
      expect(profile.timetableUniversity, 'kmu');
      expect(profile.timetableCampus, 'seongseo');
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'kmu');
      expect(period!.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 18));
      expect(period.contains(DateTime(2026, 12, 21)), isFalse);
    },
  );
}
