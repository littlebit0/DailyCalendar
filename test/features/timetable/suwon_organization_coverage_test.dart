import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Suwon places every opening label under an official unit', () async {
    final catalog = await UniversityCatalog.load();
    final raw = <String>{};
    final orphans = <String>{};
    final direct = <String>{};
    for (final dataset in catalog.where((d) => d.universityId == 'suwon')) {
      for (final course in dataset.courses) {
        for (final label in course.departments) {
          if (course.isMajorForSourceDepartment(label) &&
              !course.offeringOrganizations.any(
                (o) => o.sourceLabel == label,
              )) {
            raw.add(label);
          }
        }
        for (final o in course.offeringOrganizations) {
          if (o.department != null &&
              o.college == null &&
              o.group == null &&
              course.isMajorForOrganization(o)) {
            orphans.add(o.department!);
          }
          if (o.department == null) direct.add('${o.college}/${o.sourceLabel}');
        }
      }
    }
    expect(raw, isEmpty);
    expect(orphans, isEmpty);
    expect(direct, {
      '경영공학대학/경영공학대학>>경영공학대학',
      '인문사회융합대학/인문사회융합대학>>인문사회융합대학',
      '자유전공학부/자유전공학부>>자유전공학부',
    });
  });
}
