import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter_test/flutter_test.dart';

TimetablePeriod period(String start, String end) =>
    TimetablePeriod(start: DateTime.parse(start), end: DateTime.parse(end));

TimetableClass saved({TimetablePeriod? period}) => TimetableClass(
  id: 'saved',
  title: '저장한 강좌',
  meetings: [
    ClassMeeting(
      id: 'm',
      weekday: DateTime.monday,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
    ),
  ],
  academicYear: 2026,
  semester: '2',
  sourceId: 'saved-source',
  period: period,
);

UniversityCourse candidate({TimetablePeriod? period}) =>
    UniversityCourse.fromJson({
      'sourceId': 'candidate-source',
      'campus': 'main',
      'academicYear': 2026,
      'semester': '2',
      'courseCode': 'C1',
      'courseName': '후보 강좌',
      'section': '01',
      'professor': '교수',
      'credits': 3,
      'departmentCredits': {'학과': 3},
      'departments': ['학과'],
      'period': period?.toJson(),
      'schedules': [
        {
          'weekday': DateTime.monday,
          'startMinute': 9 * 60,
          'endMinute': 10 * 60,
        },
      ],
    });

void main() {
  final firstHalf = period('2026-09-01', '2026-10-18');

  test('weekly lessons in separate teaching periods never conflict', () {
    final later = candidate(period: period('2026-10-19', '2026-12-20'));
    expect(conflictingClasses(later, [saved(period: firstHalf)]), isEmpty);
  });

  test('weekly lessons whose periods overlap on that weekday conflict', () {
    final overlapping = candidate(period: period('2026-10-01', '2026-11-30'));
    expect(
      conflictingClasses(overlapping, [saved(period: firstHalf)]),
      hasLength(1),
    );
  });

  test('a missing period means the whole term and still conflicts', () {
    expect(
      conflictingClasses(candidate(), [saved(period: firstHalf)]),
      hasLength(1),
    );
    expect(
      conflictingClasses(candidate(period: firstHalf), [saved()]),
      hasLength(1),
    );
  });

  test('periods that overlap only on other weekdays do not conflict', () {
    // Tuesday to Sunday of one week: no Monday in the shared days.
    final tuesdayWeek = period('2026-10-20', '2026-10-25');
    final firstHalfEndsTuesday = period('2026-09-01', '2026-10-27');
    expect(
      conflictingClasses(candidate(period: tuesdayWeek), [
        saved(period: firstHalfEndsTuesday),
      ]),
      isEmpty,
    );
  });
}
