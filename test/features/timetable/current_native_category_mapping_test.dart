import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Official school hierarchies preserve native labels and distinct filters',
    () {
      final expected = {
        'daegu': {
          '공통': CourseCategory.generalEducation,
          '균형': CourseCategory.generalEducation,
          '자유': CourseCategory.general,
        },
        'cbnu': {
          '확대교양: 국제화': CourseCategory.generalEducation,
          '일반교양: 사회와역사': CourseCategory.generalEducation,
          '개신기초교양: 정보문해': CourseCategory.generalEducation,
          '개신기초교양: 의사소통': CourseCategory.generalEducation,
        },
        'jeju': {
          'JNU소양': CourseCategory.generalEducation,
          '글로벌자율전공': CourseCategory.generalEducation,
        },
        'hanbat': {'심선': CourseCategory.advancedMajor},
        'pknu': {'전공공통': CourseCategory.major, '교직필수': CourseCategory.teaching},
      };
      final paths =
          (jsonDecode(File('assets/timetable/catalog.json').readAsStringSync())
                  as List)
              .cast<String>();
      for (final school in expected.entries) {
        final seen = <String>{};
        for (final path in paths.where(
          (p) => p.startsWith('assets/timetable/${school.key}-'),
        )) {
          final raw = jsonDecode(File(path).readAsStringSync()) as Map;
          for (final row in raw['courses'] as List) {
            final course = UniversityCourse.fromJson(
              Map<String, dynamic>.from(row as Map),
            );
            expect(course.sourceClassification, row['classification']);
            final labels = course.departmentClassifications.isEmpty
                ? [course.sourceClassification]
                : course.departmentClassifications.values;
            for (final label in labels) {
              final category = school.value[label];
              if (category == null) continue;
              seen.add(label);
              expect(course.categoriesFor(), contains(category));
            }
            if (school.key == 'daegu' && course.sourceClassification == '자유') {
              expect(course.matchesQuery('일반'), true);
            }
          }
        }
        expect(seen, school.value.keys.toSet());
      }
      // Ambiguous short labels must not be assigned globally to unrelated schools.
      for (final label in ['공통', '균형', '자유', 'JNU소양', '글로벌자율전공', '심선']) {
        expect(courseCategory(label), CourseCategory.unknown);
      }
    },
  );
}
