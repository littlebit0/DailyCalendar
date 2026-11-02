import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UOS opening labels all belong to an official organization', () async {
    final catalog = await UniversityCatalog.load();
    final raw = <String>{};
    final orphans = <String>{};
    final colleges = <String>{};
    for (final dataset in catalog.where((d) => d.universityId == 'uos')) {
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
          if (o.college != null) colleges.add(o.college!);
          if (o.department != null &&
              o.college == null &&
              o.group == null &&
              course.isMajorForOrganization(o)) {
            orphans.add(o.department!);
          }
        }
      }
    }
    // Labels that name a college join that college's own chip on screen.
    expect(raw, {
      '경영대학',
      '공과대학',
      '도시과학대학',
      '예술체육대학',
      '인공지능융합대학',
      '인문대학',
      '자연과학대학',
      '정경대학',
    });
    expect(colleges, containsAll(raw));
    expect(orphans, isEmpty);
  });
}
