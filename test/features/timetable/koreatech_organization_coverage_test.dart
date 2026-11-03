import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Koreatech places every major label under an official top-level unit',
    () async {
      final catalog = await UniversityCatalog.load();
      final raw = <String>{};
      final orphans = <String>{};
      final colleges = <String>{};
      final groups = <String>{};
      var courses = 0;
      for (final dataset in catalog.where(
        (d) => d.universityId == 'koreatech',
      )) {
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
            if (o.college != null) colleges.add(o.college!);
            if (o.group != null) groups.add(o.group!);
            if (o.department != null &&
                o.college == null &&
                o.group == null &&
                course.isMajorForOrganization(o)) {
              orphans.add('${dataset.campus} ${o.department}');
            }
          }
        }
      }
      // The whole 2026-2 coursebook published on 2026-07-28 lists 791 rows.
      expect(courses, 791);
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
      // The school publishes faculties directly under the university, with no
      // college layer, so each faculty is its own top-level offering unit.
      expect(colleges, hasLength(13));
      expect(groups, {'융합전공'});
    },
  );
}
