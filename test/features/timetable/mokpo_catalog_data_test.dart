import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Mokpo whole educational scope restores verified ordinary dates and rooms',
    () async {
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'mokpo',
      );
      expect(
        {for (final d in data) d.campus: d.courses.length},
        {'dorim': 718, 'damyang': 18, 'unknown': 571},
      );
      final courses = data.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(1307));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(893));
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(408),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(6),
      );
      expect(courses.where((c) => c.code == 'ZAA006'), isEmpty);
      final history = courses
          .singleWhere((c) => c.codeAndSection == 'HIS041-00')
          .toTimetable(id: 'history', mode: LectureMode.inPerson);
      expect(classOccurrences([history], [DateTime(2026, 9, 7)]), isEmpty);
      final intensive = courses.singleWhere(
        (c) => c.codeAndSection == 'ABC003-04',
      );
      expect(intensive.meetings, hasLength(15));
      expect(
        intensive.meetings.every(
          (m) =>
              m.originalStartMinute == 1080 &&
              m.originalEndMinute == 1260 &&
              m.classroom == '공과대학4호관 305',
        ),
        isTrue,
      );
      expect(
        intensive.meetings.map((m) => m.date).toSet(),
        containsAll(['2026-10-07', '2026-10-08', '2026-11-26']),
      );

      for (final course in courses) {
        for (final raw in course.departmentClassifications.values) {
          expect(
            courseCategory(raw),
            isNot(CourseCategory.unknown),
            reason: raw,
          );
          if (raw == '전문교양') {
            expect(courseCategory(raw), CourseCategory.generalEducation);
          }
        }
        if (!course.hasSchedulableMeetings) {
          expect(course.meetings, isEmpty, reason: course.sourceId);
          continue;
        }
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.inPerson,
        );
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: course.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
        expect(restored.note, saved.note);
        if (course.codeAndSection == 'ABC003-04') {
          expect(restored.period?.start, DateTime(2026, 10, 7));
          expect(restored.period?.end, DateTime(2026, 11, 26));
        } else {
          expect(restored.period?.start, DateTime(2026, 9, 1));
          expect(restored.period?.end, DateTime(2026, 12, 7));
        }
        expect(
          restored.meetings.every(
            (m) => m.date != null && m.teachingDate!.weekday == m.weekday,
          ),
          isTrue,
        );
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 8, 31),
              DateTime(2026, 9, 24),
              DateTime(2026, 9, 25),
              DateTime(2026, 9, 26),
              DateTime(2026, 10, 3),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 9),
              DateTime(2026, 10, 31),
              DateTime(2026, 12, 8),
              DateTime(2026, 12, 14),
              DateTime(2027, 9, 1),
            ],
          ),
          isEmpty,
          reason: course.sourceId,
        );
        expect(
          classOccurrences([restored], [restored.meetings.first.teachingDate!]),
          isNotEmpty,
        );
      }
    },
  );
  test(
    'Mokpo unified and legacy campus profiles resolve actual campus and term boundaries',
    () async {
      for (final id in [
        'institution:academyinfo:0000011',
        'academyinfo:0000011',
        'academyinfo:0003312',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '국립목포대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'mokpo');
        expect(p.timetableCampus, id.endsWith('3312') ? 'damyang' : 'dorim');
      }
      const p = AcademicProfile(
        universityId: 'institution:academyinfo:0000011',
        universityName: '국립목포대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0003312',
      );
      expect(p.timetableCampus, 'damyang');
      const wrong = AcademicProfile(
        universityId: 'institution:academyinfo:0000011',
        universityName: '국립목포대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000036',
      );
      expect(wrong.timetableCampus, isNull);
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'mokpo');
      expect(period?.start, DateTime(2026, 9, 1));
      expect(period?.end, DateTime(2026, 12, 18));
    },
  );
}
