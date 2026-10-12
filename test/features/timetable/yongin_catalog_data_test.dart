import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/university_directory.dart';
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
    'Yongin current complete publication keeps closures and real exceptions',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'yongin',
      )).single;
      expect(data.campus, 'main');
      expect(data.campusName, '용인');
      expect(data.courses, hasLength(957));
      expect(data.courses.map((c) => c.sourceId).toSet(), hasLength(957));
      expect(
        data.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(889),
      );
      expect(
        data.courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(59),
      );
      final unresolved = data.courses.where(
        (c) => c.scheduleStatus == 'unrecognized',
      );
      expect(unresolved, hasLength(9));
      for (final course in unresolved) {
        expect(course.meetings, isEmpty);
        expect(course.remarks, contains('실제 수업일자 미공개'));
      }
      expect(data.courses.any((c) => c.codeAndSection == '120237-11'), isFalse);
      final judo = data.courses.singleWhere(
        (c) => c.codeAndSection == '100011-01',
      );
      expect(
        judo.meetings.map(
          (m) => (m.weekday, m.startMinute, m.endMinute, m.classroom),
        ),
        [(1, 780, 900, '무-12421(유도실기장2)')],
      );
      expect(judo.meetings.single.originalStartMinute, 785);
      expect(judo.remarks, contains('유도전공 학생은 수강신청 불가'));
      final updated = data.courses.singleWhere(
        (c) => c.codeAndSection == '550169-73',
      );
      expect(updated.sourceClassroom, contains('용오름-7217(WEB실습실)'));
      for (final course in data.courses.where(
        (c) => c.hasSchedulableMeetings,
      )) {
        expect(
          TimetableClass.fromJson(
            Map<String, dynamic>.from(
              course
                  .toTimetable(id: course.sourceId, mode: LectureMode.inPerson)
                  .toJson(),
            ),
          ).isValid,
          isTrue,
        );
      }
      expect(
        data.courses.where(
          (c) => c.code.startsWith('W') || c.code.startsWith('K'),
        ),
        hasLength(22),
      );
      expect(
        courseCategory('교양선택(4영역)'),
        CourseCategory.electiveGeneralEducation,
      );
      expect(
        courseCategory('교양선택(6영역)'),
        CourseCategory.electiveGeneralEducation,
      );
      expect(courseCategory('기전'), CourseCategory.foundation);
      expect(courseCategory('군필'), CourseCategory.general);
    },
  );
  test(
    'Yongin registration uses its institution and actual semester bounds',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000156',
        universityName: '용인대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000156',
      );
      expect(profile.timetableUniversity, 'yongin');
      expect(profile.timetableCampus, 'main');
      expect(profile.academicSourceId, 'yongin');
      final directory = await UniversityDirectory.load(bundle: _Files());
      expect(
        directory.byId('academyinfo:0000156')!.supportsAcademicFeatures,
        isFalse,
      );
      final period = (await TimetablePeriodDefaults.load(
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'yongin')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 21));
      expect(period.contains(DateTime(2026, 8, 31)), isFalse);
      expect(period.contains(DateTime(2026, 12, 22)), isFalse);
      const mismatch = AcademicProfile(
        universityId: 'institution:academyinfo:0000156',
        universityName: '용인대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000138',
      );
      expect(mismatch.timetableCampus, isNull);
    },
  );
}
