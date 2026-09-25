import 'timetable.dart';

/// Inclusive calendar dates, independent of time zones and time of day.
class TimetablePeriod {
  TimetablePeriod({required DateTime start, required DateTime end})
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (start.year < 1900 || end.year > 9999 || this.end.isBefore(this.start)) {
      throw ArgumentError('Invalid timetable period');
    }
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Map<String, String> toJson() => {
    'startDate': timetableDateKey(start),
    'endDate': timetableDateKey(end),
  };

  factory TimetablePeriod.fromJson(Map<String, dynamic> json) {
    DateTime read(String key) {
      final value = json[key];
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid timetable period date');
      }
      final date = DateTime.tryParse(value);
      if (date == null || date.year < 1900 || timetableDateKey(date) != value) {
        throw const FormatException('Invalid timetable period date');
      }
      return date;
    }

    final start = read('startDate');
    final end = read('endDate');
    if (end.isBefore(start)) {
      throw const FormatException('Reversed timetable period');
    }
    return TimetablePeriod(start: start, end: end);
  }

  @override
  bool operator ==(Object other) =>
      other is TimetablePeriod && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// A saved term may contain no courses yet, and older terms may have no range.
class TimetableTerm {
  const TimetableTerm({
    required this.year,
    required this.semester,
    required this.courseCount,
    this.name,
    this.period,
  });

  final int year;
  final String semester;
  final String? name;
  final int courseCount;
  final TimetablePeriod? period;
}
