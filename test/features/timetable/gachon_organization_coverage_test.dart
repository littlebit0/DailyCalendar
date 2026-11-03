import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Gachon leaves only user-held labels without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load();
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
      // These need a user decision: the official timetable tree places the
      // course under a different college than the current college page, or the
      // label is a former department name listed beside the current one.
      expect(raw, {'global 관경/관경3', 'global 관경/관경4', 'global 국문/국문3/AI인문대학'});
      expect(orphans, {
        'global 수리과학과',
        'global 수학·금융정보학과',
        'global 신문방송학과',
        'global 아동복지학과',
        'global 언론영상광고학과',
      });
    },
  );
}
