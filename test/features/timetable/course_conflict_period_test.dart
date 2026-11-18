import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter_test/flutter_test.dart';

TimetablePeriod period(String start, String end) =>
    TimetablePeriod(start: DateTime.parse(start), end: DateTime.parse(end));

TimetableClass saved({
  TimetablePeriod? period,
  int start = 9 * 60,
  int end = 10 * 60,
}) => TimetableClass(
  id: 'saved',
  title: '저장한 강좌',
  meetings: [
    ClassMeeting(
      id: 'm',
      weekday: DateTime.monday,
      startMinute: start,
      endMinute: end,
    ),
  ],
  academicYear: 2026,
  semester: '2',
  sourceId: 'saved-source',
  period: period,
);

UniversityCourse candidate({
  TimetablePeriod? period,
  int start = 9 * 60,
  int end = 10 * 60,
}) => UniversityCourse.fromJson({
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
    {'weekday': DateTime.monday, 'startMinute': start, 'endMinute': end},
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

  test('lessons that only share a half-hour grid row do not conflict', () {
    // 13:00-14:15 and 14:20-15:35 round to 13:00-14:30 and 14:00-16:00.
    final first = saved(start: 13 * 60, end: 14 * 60 + 15);
    final next = candidate(start: 14 * 60 + 20, end: 15 * 60 + 35);
    expect(conflictingClasses(next, [first]), isEmpty);
    // Back to back at the same minute is not an overlap either.
    expect(
      conflictingClasses(candidate(start: 14 * 60 + 15, end: 15 * 60 + 30), [
        first,
      ]),
      isEmpty,
    );
  });

  test('off-grid lessons that really overlap still conflict', () {
    final first = saved(start: 13 * 60, end: 14 * 60 + 15);
    expect(
      conflictingClasses(candidate(start: 14 * 60 + 10, end: 15 * 60 + 25), [
        first,
      ]),
      hasLength(1),
    );
  });
}
