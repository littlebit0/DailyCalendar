import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Hoseo bundled 2026-2 datasets keep every official row affiliated',
    () async {
      final catalog = await UniversityCatalog.load();
      final datasets = catalog.where((d) => d.universityId == 'hoseo').toList();
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'asan': 43, 'cheonan': 39, 'unknown': 2417},
      );
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2499));
      final raw = <String>{};
      final orphans = <String>{};
      for (final course in courses) {
        for (final label in course.departments) {
          if (course.isMajorForSourceDepartment(label) &&
              !course.offeringOrganizations.any(
                (o) => o.sourceLabel == label,
              )) {
            raw.add('${course.campus} $label');
          }
        }
        for (final o in course.offeringOrganizations) {
          if (o.department != null &&
              o.college == null &&
              o.group == null &&
              course.isMajorForOrganization(o)) {
            orphans.add('${course.campus} ${o.department}');
          }
        }
      }
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
      // 0- and 9-14th periods use the booklet p.152 table (hourly starts, 50
      // minutes); consecutive periods form one block (0교시~3교시 = 09:00-12:50).
      final zeroToThree = courses.firstWhere((c) => c.sourceSchedule == '월0~3');
      expect(zeroToThree.scheduleStatus, 'scheduled');
      expect(zeroToThree.meetings.first.originalStartMinute, 540);
      expect(zeroToThree.meetings.first.originalEndMinute, 770);
      // Still held (remote/hybrid delivery, Saturday, evening-division,
      // conflicting rows); search stays suspended.
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(756),
      );
    },
  );
}
