import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TUK places every offering label in an official organization', () async {
    final catalog = await UniversityCatalog.load();
    final raw = <String>{};
    final orphans = <String>{};
    for (final dataset in catalog.where((d) => d.universityId == 'tuk')) {
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
    expect(orphans, isEmpty);
  });
}
