import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Yonsei leaves only user-held labels without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load();
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'yonsei')) {
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
      // These need a user decision: pre-2010 curriculum areas, a graduate
      // label, the first-year medical tree node, and transitional
      // affiliations whose official college differs by entering cohort.
      expect(raw, {
        for (final campus in ['sinchon', 'international']) ...{
          for (final area in [
            '건강과스포츠',
            '문학과예술',
            '사회와가치',
            '외국어와세계이해',
            '인간이해와역사',
            if (campus == 'sinchon') '과학과기술',
          ])
            '$campus 학부선택(~2009학번) $area',
          for (final area in ['문화의이해', '사회의이해', '세계의이해', '인간의이해', '자연의이해'])
            '$campus 학부필수(~2009학번) $area',
        },
        'international 의·치·간(1학년) 간호(1학년)',
        'international 의·치·간(1학년) 의예과(1학년)',
        'international 의·치·간(1학년) 치의예과(1학년)',
        'mirae 동아시아국제학부 EAST ASIAN ECONOMY AND BUSINESS',
        'mirae 동아시아국제학부 EAST ASIAN POLITICS AND CULTURE',
        'mirae 동아시아국제학부 공통',
        'mirae 보건과학부(야간) 보건과학부(야간)(2022학년도 편입생~)',
        'sinchon Study Abroad Course Graduate',
        'sinchon 공통 창업,현장실습',
      });
      expect(orphans, isEmpty);
    },
  );
}
