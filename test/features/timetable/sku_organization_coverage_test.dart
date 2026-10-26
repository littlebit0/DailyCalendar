import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SKU convergence-major courses count as major for their department',
    () async {
      final catalog = await UniversityCatalog.load();
      var checked = 0;
      final byCode = <String, bool>{};
      for (final dataset in catalog.where((d) => d.universityId == 'sku')) {
        for (final course in dataset.courses) {
          if (course.sourceClassification != '융합') continue;
          checked++;
          // The raw classification stays as printed.
          expect(course.sourceClassification, '융합');
          for (final label in course.departments) {
            expect(label, contains('융합전공'), reason: course.sourceId);
            expect(
              course.isMajorForSourceDepartment(label),
              isTrue,
              reason: course.sourceId,
            );
          }
          byCode[course.code] = true;
        }
      }
      expect(checked, 31);
      expect(byCode.keys, containsAll(['SD1018', 'SD1305']));
    },
  );

  test(
    'SKU leaves only user-held labels without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load();
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'sku')) {
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
      // These need a user decision: foreign-student sections of regular
      // departments could belong to the department's college or to the
      // foreign-student college (글로벌융합대학), and no official source pairs
      // these exact labels with a college.
      expect(raw, {
        'main 경 영 학 부(외국인 유학생)',
        'unknown 경 영 학 부(외국인 유학생)',
        'unknown 공 연 예 술 학 부무 대 패 션 전 공 (외국인 유학생)',
        'unknown 공 연 예 술 학 부뮤 지 컬 전 공 (외국인 유학생)',
        'unknown 메 이 크 업 디 자 인 학 과(외국인 유학생)',
        'unknown 무 용 예 술 학 부(외국인 유학생)',
        'unknown 뷰 티 테 라 피 & 메 이 크 업 학 과(외국인 유학생)',
        'unknown 실 용 음 악 학 부(외국인 유학생)',
      });
      expect(orphans, isEmpty);
    },
  );
}
