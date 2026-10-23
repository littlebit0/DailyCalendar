import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'Changwon own main academic profile keeps other campus catalogs unavailable',
    () {
      for (final id in [
        'institution:academyinfo:0000028',
        'academyinfo:0000028',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '국립창원대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'changwon');
        expect(profile.timetableCampus, 'unknown');
        for (final campus in [
          'academyinfo:0003297',
          'academyinfo:0003298',
          'academyinfo:0000117',
        ]) {
          expect(
            AcademicProfile(
              universityId: id,
              universityName: '국립창원대학교',
              schoolKind: 'fourYear',
              campusId: campus,
            ).timetableSupported,
            isFalse,
          );
        }
      }
      expect(courseCategory('균교'), CourseCategory.generalEducation);
      expect(courseCategory('확교'), CourseCategory.generalEducation);
      expect(courseCategory('자선'), CourseCategory.general);
    },
  );
  test(
    'Changwon native identity, source-specific dates and all modes survive Drive restoration',
    () {
      const root = 'work/university-research/catalog-v/';
      final raw =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/changwon-unknown-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final dataset = UniversityDataset.fromJson(raw);
      final source =
          jsonDecode(
                fixtureFile(
                  '${root}changwon-current-educational-rows-20261008.json',
                ).readAsStringSync(),
              )
              as List;
      final original = <String, List<dynamic>>{};
      for (final r in source) {
        original.putIfAbsent('${r['code']}-${r['section']}', () => []).add(r);
      }
      expect(dataset.courses, hasLength(1754));
      for (final r in raw['courses'] as List) {
        expect(
          r['sourceEducation']['originalPublicRows'],
          original['${r['courseCode']}-${r['section']}'],
        );
        expect(r['courseCode'], matches(RegExp(r'^[A-Z]{3}\d{4}$')));
        expect(r['section'], matches(RegExp(r'^\d{2}$')));
      }
      final priorRaw =
          jsonDecode(
                fixtureFile(
                  '${root}changwon-unknown-2026-2.eleven-dated-v2.json',
                ).readAsStringSync(),
              )
              as Map;
      final priorIds = (priorRaw['courses'] as List)
          .where((c) => (c['schedules'] as List).isNotEmpty)
          .map((c) => c['sourceId'])
          .toSet();
      expect(
        dataset.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(1432),
      );
      expect(dataset.courses.expand((c) => c.meetings), hasLength(28985));
      // 15A·15B use the official 학사안내 period table (22:30~23:20).
      final night = dataset.courses.singleWhere((c) => c.code == 'AHA0132');
      expect(night.meetings, hasLength(12));
      for (final m in night.meetings) {
        expect(
          [m.weekday, m.originalStartMinute, m.originalEndMinute],
          [5, 1250, 1400],
        );
      }
      final examNight = dataset.courses.singleWhere((c) => c.code == 'BMA3007');
      expect(
        examNight.meetings.where((m) => m.date == '2026-10-22').single,
        isA<ClassMeeting>()
            .having((m) => m.originalStartMinute, 'start', 1140)
            .having((m) => m.originalEndMinute, 'end', 1200),
      );
      expect(
        raw['courses'].where((c) => c['scheduleStatus'] == 'unrecognized'),
        hasLength(69),
      );
      final published = dataset.courses
          .where((c) => priorIds.contains(c.sourceId))
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      expect(published, hasLength(11));
      expect(published.expand((c) => c.meetings), hasLength(185));
      final byCode = {for (final c in published) c.code: c};
      final workshop = byCode['EDA0077']!;
      expect(workshop.meetings.map((m) => m.date), contains('2026-12-09'));
      expect(
        workshop.meetings.map((m) => m.date),
        isNot(contains('2026-10-28')),
      );
      expect(
        workshop.meetings.map((m) => m.date),
        isNot(contains('2026-11-03')),
      );
      final exam = workshop.meetings.singleWhere((m) => m.date == '2026-10-21');
      expect(exam.originalStartMinute, 600);
      expect(exam.originalEndMinute, 660);
      final early = byCode['EDA0108']!.meetings.singleWhere(
        (m) => m.date == '2026-09-16',
      );
      expect(early.originalEndMinute, 870);
      expect(
        byCode['EDA0108']!.meetings.map((m) => m.date),
        isNot(contains('2026-12-09')),
      );
      final shifted = byCode['EDA0112']!;
      expect(
        shifted.meetings.where((m) => m.date == '2026-10-08'),
        hasLength(1),
      );
      expect(
        shifted.meetings.map((m) => m.date),
        isNot(contains('2026-09-24')),
      );
      expect(shifted.meetings.map((m) => m.date), contains('2026-11-19'));
      expect(
        byCode['EDA0093']!.meetings.map((m) => m.date),
        isNot(contains('2026-11-24')),
      );
      final festival = byCode['GEA7537']!;
      final field = festival.meetings
          .where(
            (m) => ['2026-10-23', '2026-10-24', '2026-10-25'].contains(m.date),
          )
          .toList();
      expect(field, hasLength(9));
      expect(field.every((m) => m.classroom.isEmpty), isTrue);
      expect(field.map((m) => m.weekday).toSet(), {5, 6, 7});
      expect(
        festival.meetings.map((m) => m.date),
        isNot(contains('2026-09-15')),
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = published
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(11));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, before[c.sourceId]!.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            before[c.sourceId]!.meetings.map((m) => m.toJson()).toList(),
          );
          expect(c.period!.end, DateTime(2026, 12, 20));
          expect(c.note, contains('예약 블록'));
          for (final m in c.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            expect(c.period!.contains(m.teachingDate!), isTrue);
            expect(c.modeOn(m, m.teachingDate!), LectureMode.inPerson);
          }
        }
      }
    },
  );
}
