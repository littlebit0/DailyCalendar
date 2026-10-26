import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/suspended_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Hanyang leaves only user-held labels without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load(
        bundle: SuspendedAssetBundle(),
      );
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'hanyang')) {
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
      // No official page lists this ERICA major, so its college is held for
      // a user decision instead of guessed.
      expect(raw, {'erica 지속가능건축융합전공'});
      expect(orphans, isEmpty);
    },
  );
}
