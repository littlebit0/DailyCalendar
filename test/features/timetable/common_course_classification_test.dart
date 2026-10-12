import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

// Published Kunsan general course has no opening department, rather than a
// fictitious department called 'general education'. Its literal category and
// enrollment restrictions must survive search and timetable conversion.
Map<String, dynamic> _generalCourse() => {
  'sourceId': 'kunsan/unknown/2026/2/112919/01',
  'campus': 'unknown',
  'academicYear': 2026,
  'semester': '2',
  'courseCode': '112919',
  'section': '01',
  'courseName': '기초글쓰기',
  'professor': '오영록',
  'credits': 3,
  'departments': <String>[],
  'departmentCredits': <String, num>{},
  'departmentClassifications': <String, String>{},
  'classification': '기초교양',
  'departmentRemarks': {'': '대상학년,학과(부): ★ 1학년'},
  'scheduleStatus': 'unscheduled',
  'schedules': <dynamic>[],
};

void main() {
  test(
    'explicit required and elective education classifications retain original text',
    () {
      for (final raw in [
        '교필',
        '교필영어',
        '기초교양필수',
        '교양필수',
        '교양\n필수',
        '공통교양필수',
        '교양필수: 개신기초교양(정보문해)',
      ]) {
        final course = UniversityCourse.fromJson(
          _generalCourse()..['classification'] = raw,
        );
        expect(course.categoriesFor(), [
          CourseCategory.requiredGeneralEducation,
        ]);
        expect(course.classificationLabelsFor(), ['교필']);
        expect(course.sourceClassification, raw);
      }
      for (final raw in [
        '교선',
        '교선 핵심역량',
        '교양선택',
        '기초학문교양선택',
        '자유선택교양',
        '교양선택(6영역)',
        '교양선택\n(AI)',
      ]) {
        expect(courseCategory(raw), CourseCategory.electiveGeneralEducation);
      }
      expect(courseCategory('교양'), CourseCategory.generalEducation);
      expect(
        UniversityCourse.fromJson(
          _generalCourse()..['classification'] = '',
        ).classificationLabelsFor(),
        isEmpty,
      );
    },
  );

  test(
    'CNU source categories preserve major and general education divisions',
    () {
      const categories = {
        '전공(기초)': CourseCategory.foundation,
        '전공(핵심)': CourseCategory.major,
        '전공(심화)': CourseCategory.advancedMajor,
        '교양(소양)': CourseCategory.generalEducation,
        '교양(균형)': CourseCategory.generalEducation,
        '교양(기초)': CourseCategory.generalEducation,
        '교양(소양필수)': CourseCategory.requiredGeneralEducation,
        '일반선택': CourseCategory.general,
        '교직': CourseCategory.teaching,
      };
      for (final entry in categories.entries) {
        final raw = _generalCourse()..['classification'] = entry.key;
        final course = UniversityCourse.fromJson(raw);
        expect(course.sourceClassification, entry.key);
        expect(course.categoriesFor(), [entry.value]);
      }
      expect(courseCategory('전공(핵심)'), isNot(CourseCategory.requiredMajor));
      expect(courseCategory('미확인분류'), CourseCategory.unknown);
    },
  );
  test(
    'literal common category permits no department without inventing affiliation',
    () {
      final course = UniversityCourse.fromJson(_generalCourse());
      expect(course.departments, isEmpty);
      expect(course.sourceClassification, '기초교양');
      expect(course.categoriesFor(), contains(courseCategory('기초교양')));
      expect(course.matchesQuery('기초교양'), isTrue);
      expect(course.matchesQuery('ㄱㅊㄱㅇ'), isTrue);
      expect(course.credits, 3);
      expect(course.remarks, contains('★ 1학년'));
      final saved = course.toTimetable(
        id: 'common',
        mode: LectureMode.inPerson,
      );
      expect(saved.note, course.remarks);
      expect(saved.meetings, isEmpty);
    },
  );
  test(
    'real course identity permits unpublished educational fields without inventing them',
    () {
      final raw = _generalCourse()
        ..remove('classification')
        ..['departmentRemarks'] = <String, String>{}
        ..['remarks'] = '공개 자료에 학과와 이수 구분이 게시되지 않았습니다.';
      final course = UniversityCourse.fromJson(raw);
      expect(course.code, '112919');
      expect(course.departments, isEmpty);
      expect(course.sourceClassification, isEmpty);
      expect(course.categoriesFor(), [CourseCategory.unknown]);
      expect(course.remarks, raw['remarks']);
      raw['courseCode'] = '  ';
      expect(() => UniversityCourse.fromJson(raw), throwsFormatException);
      raw['classification'] = '  ';
      expect(() => UniversityCourse.fromJson(raw), throwsFormatException);
    },
  );
  test('cross-listing categories keep their department-specific meaning', () {
    final raw = _generalCourse()
      ..['departments'] = ['국어국문학과', '자유전공학과']
      ..['departmentClassifications'] = {'국어국문학과': '전공선택', '자유전공학과': '교양선택'};
    final course = UniversityCourse.fromJson(raw);
    expect(course.categoriesFor('국어국문학과'), [CourseCategory.electiveMajor]);
    expect(course.categoriesFor('자유전공학과'), [
      CourseCategory.electiveGeneralEducation,
    ]);
    expect(course.categoriesFor('미등록학과'), [CourseCategory.unknown]);
  });
}
