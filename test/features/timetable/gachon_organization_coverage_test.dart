import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Gachon has no label without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load(university: 'gachon');
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'gachon')) {
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
      // 관경3·4 sit under both the timetable tree's 사회과학대학 and the current
      // 경영대학 page (transitional), 국문3 under AI인문대학, and former
      // department names marked (폐기) in the timetable tree have no chip.
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
    },
  );
}
