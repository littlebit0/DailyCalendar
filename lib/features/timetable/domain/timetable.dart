import 'timetable_term.dart';

enum LectureMode { inPerson, liveOnline, video, cancelled }

String lectureModeLabel(LectureMode mode) => switch (mode) {
  LectureMode.inPerson => '대면 강의',
  LectureMode.liveOnline => '실시간 비대면 강의',
  LectureMode.video => '영상 강의',
  LectureMode.cancelled => '휴강',
};

String timetableDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Timetable blocks use half-hour boundaries, including the break after a class.
/// These are presentation/scheduling boundaries, not a rewrite of source times.
int timetableSlotStart(int minute) => minute ~/ 30 * 30;
int timetableSlotEnd(int minute) => (minute + 29) ~/ 30 * 30;

class ClassMeeting {
  const ClassMeeting({
    required this.id,
    required this.weekday,
    required int startMinute,
    required int endMinute,
    this.classroom = '',
  }) : originalStartMinute = startMinute,
       originalEndMinute = endMinute;
  final String id;
  final int weekday;
  final int originalStartMinute;
  final int originalEndMinute;
  int get startMinute => timetableSlotStart(originalStartMinute);
  int get endMinute => timetableSlotEnd(originalEndMinute);
  final String classroom;
  bool get isValid =>
      id.isNotEmpty &&
      weekday >= 1 &&
      weekday <= 7 &&
      originalStartMinute >= 0 &&
      originalEndMinute <= 1440 &&
      originalStartMinute < originalEndMinute;
  Map<String, Object?> toJson() => {
    'id': id,
    'weekday': weekday,
    'startMinute': originalStartMinute,
    'endMinute': originalEndMinute,
    'classroom': classroom,
  };
  factory ClassMeeting.fromJson(Map<String, dynamic> json) => ClassMeeting(
    id: json['id'] as String,
    weekday: json['weekday'] as int,
    startMinute: json['startMinute'] as int,
    endMinute: json['endMinute'] as int,
    classroom: json['classroom'] as String? ?? '',
  );
}

class TimetableClass {
  TimetableClass({
    required this.id,
    required this.title,
    required List<ClassMeeting> meetings,
    required this.academicYear,
    required this.semester,
    this.professor = '',
    this.note = '',
    this.colorValue = 0xff2563eb,
    this.defaultMode = LectureMode.inPerson,
    this.sourceId,
    this.sourceType = 'manual',
    Map<String, LectureMode> overrides = const {},
  }) : meetings = List.unmodifiable(meetings),
       overrides = Map.unmodifiable(overrides);
  final String id;
  final String title;
  final List<ClassMeeting> meetings;
  final int academicYear;
  final String semester;
  final String professor;
  final String note;
  final int colorValue;
  final LectureMode defaultMode;
  final String sourceType;
  final String? sourceId;
  // Meeting identity avoids applying one block's exception to another on the same day.
  final Map<String, LectureMode> overrides;
  bool get isValid =>
      id.isNotEmpty &&
      title.trim().isNotEmpty &&
      academicYear >= 1900 &&
      academicYear <= 9999 &&
      semester.isNotEmpty &&
      meetings.isNotEmpty &&
      meetings.every((m) => m.isValid) &&
      meetings.map((m) => m.id).toSet().length == meetings.length &&
      defaultMode != LectureMode.cancelled;
  String overrideKey(ClassMeeting meeting, DateTime date) =>
      '${meeting.id}/${timetableDateKey(date)}';
  LectureMode modeOn(ClassMeeting meeting, DateTime date) =>
      overrides[overrideKey(meeting, date)] ?? defaultMode;
  TimetableClass withOverride(
    ClassMeeting meeting,
    DateTime date,
    LectureMode? mode,
  ) {
    final next = {...overrides};
    final key = overrideKey(meeting, date);
    if (mode == null) {
      next.remove(key);
    } else {
      next[key] = mode;
    }
    return TimetableClass.fromJson({
      ...toJson(),
      'overrides': next.map((k, v) => MapEntry(k, v.name)),
    });
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'meetings': meetings.map((m) => m.toJson()).toList(),
    'academicYear': academicYear,
    'semester': semester,
    'professor': professor,
    'note': note,
    'colorValue': colorValue,
    'defaultMode': defaultMode.name,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'overrides': overrides.map((k, v) => MapEntry(k, v.name)),
  };
  factory TimetableClass.fromJson(Map<String, dynamic> json) => TimetableClass(
    id: json['id'] as String,
    title: json['title'] as String,
    meetings: (json['meetings'] as List)
        .map((m) => ClassMeeting.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList(),
    academicYear: json['academicYear'] as int,
    semester: json['semester'] as String,
    professor: json['professor'] as String? ?? '',
    note: json['note'] as String? ?? '',
    colorValue: json['colorValue'] as int,
    defaultMode: LectureMode.values.byName(json['defaultMode'] as String),
    sourceType: json['sourceType'] as String? ?? 'manual',
    sourceId: json['sourceId'] as String?,
    overrides: (json['overrides'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, LectureMode.values.byName(v as String)),
    ),
  );
}

class ClassOccurrence {
  const ClassOccurrence(this.course, this.meeting, this.date, this.mode);
  final TimetableClass course;
  final ClassMeeting meeting;
  final DateTime date;
  final LectureMode mode;
  String get id =>
      'timetable/${course.id}/${meeting.id}/${timetableDateKey(date)}';
  DateTime get start => DateTime(
    date.year,
    date.month,
    date.day,
    meeting.startMinute ~/ 60,
    meeting.startMinute % 60,
  );
  DateTime get end => DateTime(
    date.year,
    date.month,
    date.day,
    meeting.endMinute ~/ 60,
    meeting.endMinute % 60,
  );
}

List<ClassOccurrence> classOccurrences(
  Iterable<TimetableClass> classes,
  Iterable<DateTime> days, {
  bool includeUnscheduled = false,
  TimetablePeriod? Function(TimetableClass)? periodFor,
}) => [
  for (final date in days)
    for (final course in classes)
      for (final meeting in course.meetings)
        if ((periodFor == null || periodFor(course)?.contains(date) == true) &&
            meeting.weekday == date.weekday &&
            (includeUnscheduled ||
                (course.modeOn(meeting, date) != LectureMode.cancelled &&
                    course.modeOn(meeting, date) != LectureMode.video)))
          ClassOccurrence(course, meeting, date, course.modeOn(meeting, date)),
];
