import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('school-specific short labels are not assigned globally', () {
    for (final label in ['공통', '균형', '자유', 'JNU소양', '글로벌자율전공', '심선']) {
      expect(courseCategory(label), CourseCategory.unknown);
    }
  });
}
