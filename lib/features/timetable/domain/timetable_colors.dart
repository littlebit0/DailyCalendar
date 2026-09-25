import 'timetable.dart';

const timetableCourseColors = [
  0xff2563eb,
  0xffdc2626,
  0xff059669,
  0xffd97706,
  0xff9333ea,
  0xff0891b2,
];

/// Balances course colors while retaining a stable order when usage is tied.
int selectNewCourseColor(Iterable<TimetableClass> courses) {
  final counts = <int, int>{
    for (final color in timetableCourseColors) color: 0,
  };
  for (final course in courses) {
    if (counts.containsKey(course.colorValue)) {
      counts[course.colorValue] = counts[course.colorValue]! + 1;
    }
  }
  return timetableCourseColors.reduce(
    (first, next) => counts[first]! <= counts[next]! ? first : next,
  );
}
