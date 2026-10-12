import 'dart:convert';

import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _published() => {
  'sourceId': 'school/main/2026/2/example/1',
  'campus': 'main',
  'academicYear': 2026,
  'semester': '2',
  'courseCode': 'example',
  'courseName': '날짜별 수업',
  'section': '1',
  'professor': '',
  'departmentCredits': {'학과': 3},
  'departments': ['학과'],
  'schedules': [
    {
      'date': '2026-09-05',
      'weekday': 6,
      'startMinute': 780,
      'endMinute': 960,
      'classroom': '217',
      'deliveryMode': 'inPerson',
    },
    {
      'date': '2026-09-21',
      'weekday': 1,
      'startMinute': 1140,
      'endMinute': 1320,
      'classroom': '화상강의',
      'deliveryMode': 'liveOnline',
    },
    {
      'date': '2026-10-24',
      'weekday': 6,
      'startMinute': 780,
      'endMinute': 960,
      'classroom': '추후지정',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'published dated modes survive storage and a new-device merge',
    () async {
      SharedPreferences.setMockInitialValues({});
      final course = UniversityCourse.fromJson(
        _published(),
      ).toTimetable(id: 'course', mode: LectureMode.liveOnline);
      final source = TimetableStore(await SharedPreferences.getInstance());
      await source.save(course);
      SharedPreferences.setMockInitialValues({});
      final target = TimetableStore(await SharedPreferences.getInstance());
      await target.mergeSyncDocument(
        TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(source.syncDocument().toJson())),
        ),
      );
      final restored = target.classes.single;
      expect(
        restored.modeOn(restored.meetings[0], DateTime(2026, 9, 5)),
        LectureMode.inPerson,
      );
      expect(
        restored.modeOn(restored.meetings[1], DateTime(2026, 9, 21)),
        LectureMode.liveOnline,
      );
      expect(
        restored.modeOn(restored.meetings[2], DateTime(2026, 10, 24)),
        LectureMode.liveOnline,
      );
      final edited = restored.withOverride(
        restored.meetings[0],
        DateTime(2026, 9, 5),
        LectureMode.cancelled,
      );
      expect(
        edited.modeOn(edited.meetings[0], DateTime(2026, 9, 5)),
        LectureMode.cancelled,
      );
    },
  );

  test('a source mode cannot silently apply to every recurring week', () {
    final raw = _published();
    (raw['schedules'] as List)[0].remove('date');
    expect(() => UniversityCourse.fromJson(raw), throwsFormatException);
  });

  test('untimed video cannot become a source timed meeting', () {
    final raw = _published();
    (raw['schedules'] as List)[0]['deliveryMode'] = 'video';
    expect(() => UniversityCourse.fromJson(raw), throwsFormatException);
  });

  test('published foundation curriculum abbreviations remain categorized', () {
    expect(courseCategory('기필'), CourseCategory.foundation);
    expect(courseCategory('기선'), CourseCategory.foundation);
  });
}
