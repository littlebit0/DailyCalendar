import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Jeju places every major label under an official affiliation', () async {
    final catalog = await UniversityCatalog.load();
    final raw = <String>{};
    final orphans = <String>{};
    var guideGeneralEducation = 0;
    for (final dataset in catalog.where((d) => d.universityId == 'jeju')) {
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
        // The course guide lists 글로벌자율전공 081111~081191 as 교양교과목.
        if (course.departmentClassifications.values.contains('글로벌자율전공')) {
          guideGeneralEducation++;
          expect(course.isMajorForSourceDepartment('제주대학교 교양'), isFalse);
        }
      }
    }
    expect(raw, isEmpty);
    expect(orphans, isEmpty);
    expect(guideGeneralEducation, 9);
  });
}
