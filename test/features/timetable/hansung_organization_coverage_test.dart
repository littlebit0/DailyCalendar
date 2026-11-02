import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Hansung leaves only user-held labels without an official affiliation',
    () async {
      final catalog = await UniversityCatalog.load();
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'hansung')) {
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
          }
        }
      }
      // These need a user decision: former pre-track units, older tracks and
      // program labels whose college is only implied by page order, labels
      // that differ from the official Micro Degree name, and units whose only
      // source is the robots-restricted timetable tree.
      expect(raw, {
        'IPP',
        '단과대학구분없음',
        '디지털 사진 영상촬영 아카데미',
        '사물인터넷트랙',
        '사이버보안트랙',
        '시스템경영공학트랙',
        '인공지능(AI) 전문과정',
        '인터랙티브엔터테인먼트',
        '일학습병행',
        '제품·서비스디자인트랙',
        '학점인정',
        '회화과',
      });
      expect(orphans, {
        'IT응용시스템공학과',
        '경영학부',
        '경제학과',
        '기계시스템공학과',
        '무역학과',
        '무용학과',
        '부동산세무경영학과',
        '부동산학과',
        '산업경영공학과',
        '역사문화학부',
        '영어영문학부',
        '융복합디자인학부',
        '인테리어디자인학과',
        '전자정보공학과',
        '패션학부',
        '행정학과',
      });
    },
  );
}
