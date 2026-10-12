import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'CJE current and legacy profiles reach only the documented catalog',
    () async {
      for (final id in [
        'institution:academyinfo:0000261',
        'academyinfo:0000261',
      ]) {
        final profile = AcademicProfile.fromJson({
          'universityId': id,
          'universityName': '청주교육대학교',
          'schoolKind': 'fourYear',
        });
        expect(profile.academicSourceId, 'cje');
        expect(profile.timetableUniversity, 'cje');
        expect(profile.timetableCampus, 'unknown');
        expect(AcademicProfile.fromJson(profile.toJson()), profile);
        final datasets = await UniversityCatalog.load(
          university: profile.timetableUniversity,
        );
        expect(datasets, hasLength(1));
        expect(datasets.single.courses, hasLength(372));
        final scheduled = datasets.single.courses.where(
          (course) => course.meetings.isNotEmpty,
        );
        expect(scheduled, hasLength(1));
        final course = scheduled.single.toTimetable(
          id: scheduled.single.sourceId,
          mode: LectureMode.inPerson,
        );
        expect(course.meetings.single.date, '2026-09-08');
        expect(course.period!.contains(DateTime(2026, 9, 9)), false);
        expect(course.period!.contains(DateTime(2026, 10, 6)), false);
        expect(
          datasets.single.courses.where((c) => c.meetings.isEmpty),
          hasLength(371),
        );
      }
    },
  );

  test(
    'An unrelated campus cannot activate CJE timetable or academic source',
    () {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000261',
        universityName: '청주교육대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000117',
      );
      expect(profile.timetableCampus, isNull);
      expect(profile.timetableSupported, false);
      expect(profile.academicSourceId, isNull);
    },
  );
}
