import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SWU leaves only user-held labels without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load();
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'swu')) {
        for (final course in dataset.courses) {
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
      expect(raw, isEmpty);
      // Needs a user decision: the public course search lists 교환학과 as a
      // department, but no official page places it under a college or
      // program system.
      expect(orphans, {'main 교환학과'});
    },
  );
}
