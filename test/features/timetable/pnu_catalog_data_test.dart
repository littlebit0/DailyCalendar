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
    'PNU complete public catalog preserves restriction and campus locations',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'pnu',
      );
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses, hasLength(4055));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(4055));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(3865));
      expect(datasets.map((d) => d.campus).toSet(), {
        'busan',
        'miryang',
        'yangsan',
        'shared',
        'multiple',
      });
      expect(courses.every((c) => c.meetings.every((m) => m.isValid)), isTrue);
      expect(courses.every((c) => c.remarks.isNotEmpty), isTrue);
      final course = courses.singleWhere(
        (c) => c.codeAndSection == 'OM3300664-001',
      );
      expect(course.campus, 'yangsan');
      expect(course.sourceSchedule, contains('13:00(100)'));
      // Existing display policy rounds the official 14:40 end to 15:00.
      expect(
        course.meetings.map((m) => (m.weekday, m.startMinute, m.endMinute)),
        [(5, 780, 900)],
      );
      final multi = courses.singleWhere(
        (c) => c.codeAndSection == 'FE3400102-001',
      );
      expect(multi.meetings, hasLength(1));
      expect(multi.meetings.single.classroom, '602-201 / 밀양M03-3262');
      final async = courses.singleWhere(
        (c) => c.codeAndSection == 'AS1500071-001',
      );
      expect(async.meetings, isEmpty);
      expect(async.remarks, contains('비실시간'));
      expect(
        TimetableClass.fromJson(
          Map<String, dynamic>.from(
            course.toTimetable(id: 'test', mode: LectureMode.inPerson).toJson(),
          ),
        ).isValid,
        isTrue,
      );
    },
  );
  test(
    'PNU consecutive same-room meetings under 60 minutes apart are merged',
    () async {
      final courses = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'pnu',
      )).expand((d) => d.courses).toList();
      final merged = courses.singleWhere(
        (c) => c.codeAndSection == 'ER2900491-076',
      );
      expect(
        merged.meetings.map((m) => (m.weekday, m.startMinute, m.endMinute)),
        [(1, 900, 1080)],
      );
      // Loader rounds the official 17:45 end to 18:00.
      // Courses whose source meetings overlap are held unmerged (#686).
      const held = {'ZF1100922-001', 'ZF1101137-104', 'AC1501344-001'};
      for (final c in courses.where((c) => !held.contains(c.codeAndSection))) {
        final byDay = <int, List<ClassMeeting>>{};
        for (final m in c.meetings) {
          byDay.putIfAbsent(m.weekday, () => []).add(m);
        }
        for (final list in byDay.values) {
          list.sort((a, b) => a.startMinute.compareTo(b.startMinute));
          for (var i = 1; i < list.length; i++) {
            final sameRoom = list[i].classroom == list[i - 1].classroom;
            final gap = list[i].startMinute - list[i - 1].endMinute;
            expect(
              sameRoom && gap < 60,
              isFalse,
              reason: '${c.codeAndSection} has unmerged consecutive meetings',
            );
          }
        }
      }
    },
  );
  test(
    'PNU profile and calendar occurrences respect actual term boundaries',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000014',
        universityName: '부산대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000014',
      );
      expect(profile.timetableUniversity, 'pnu');
      expect(profile.timetableCampus, 'busan');
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'pnu')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 21));
      final course =
          (await UniversityCatalog.load(bundle: _Files(), university: 'pnu'))
              .expand((d) => d.courses)
              .firstWhere((c) => c.hasSchedulableMeetings)
              .toTimetable(id: 'test', mode: LectureMode.inPerson);
      expect(
        classOccurrences(
          [course],
          [DateTime(2026, 12, 25)],
          periodFor: (_) => period,
        ),
        isEmpty,
      );
      expect(courseCategory('교직과목'), CourseCategory.teaching);
      for (final label in ['효원핵심교양', '효원균형교양', '효원창의교양']) {
        expect(courseCategory(label), CourseCategory.generalEducation);
      }
    },
  );
}
