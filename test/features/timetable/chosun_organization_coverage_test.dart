import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Chosun places every major label under an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load();
      final raw = <String>{};
      final orphans = <String>{};
      var courses = 0;
      for (final dataset in catalog.where((d) => d.universityId == 'chosun')) {
        for (final course in dataset.courses) {
          courses++;
          for (final label in course.departments) {
            if (course.isMajorForSourceDepartment(label) &&
                !course.offeringOrganizations.any(
                  (o) => o.sourceLabel == label,
                )) {
              raw.add('${dataset.campus} $label');
            }
          }
          for (final o in course.offeringOrganizations) {
            if (o.department != null &&
                o.college == null &&
                o.group == null &&
                course.isMajorForOrganization(o)) {
              orphans.add('${dataset.campus} ${o.department}');
            }
          }
        }
      }
      expect(courses, 3063);
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
    },
  );

  test(
    'Chosun keeps the published clock and holds non-face-to-face rows',
    () async {
      final courses = [
        for (final d in await UniversityCatalog.load(university: 'chosun'))
          ...d.courses,
      ];
      expect(
        courses.where((c) => c.scheduleStatus == 'scheduled'),
        hasLength(2924),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(139),
      );
      final course = courses.singleWhere(
        (c) => c.sourceId == 'chosun/unknown/2026/2/00030/01',
      );
      expect(course.sourceSchedule, '화 5A~7B(13:00~16:00)');
      expect(course.meetings.single.weekday, 2);
      expect(course.meetings.single.startMinute, 780);
      expect(course.meetings.single.endMinute, 960);
      expect(course.meetings.single.classroom, '대학 본관5148 강의실');
    },
  );
}
