import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Eulji restores the partial catalog with every label affiliated',
    () async {
      final catalog = await UniversityCatalog.load();
      final datasets = catalog.where((d) => d.universityId == 'eulji').toList();
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'seongnam': 379, 'uijeongbu': 33},
      );

      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in datasets) {
        for (final course in dataset.courses) {
          expect(
            course.hasSchedulableMeetings,
            isTrue,
            reason: course.sourceId,
          );
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
      expect(orphans, isEmpty);
    },
  );
}
