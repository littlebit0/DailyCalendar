import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/suspended_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SKKU leaves only user-held labels without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load(
        bundle: SuspendedAssetBundle(),
      );
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'skku')) {
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
      // These need a user decision: '공통교양' is the collector's label for the
      // official '학사-교양/기타/DS과목' query, not an official unit name; the
      // other labels sit under more than one official timetable college tree
      // or are a former program name.
      expect(raw, {
        'humanities 공통교양',
        'humanities 융합소프트웨어연계전공-SCSC',
        'humanities 융합소프트웨어연계전공-SW융합',
        'humanities 인포매틱스융합전공',
        'icampus 인포매틱스융합전공',
        'naturalScience 공통교양',
        'naturalScience 융합소프트웨어연계전공-SCSC',
        'naturalScience 융합소프트웨어연계전공-SW융합',
        'naturalScience 인포매틱스융합전공',
      });
      expect(orphans, isEmpty);
    },
  );
}
