import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const identities = {
  'inje': '0000164',
  'hongik': '0000212',
  'wsu': '0000240',
  'iccu': '0000168',
  'ewha': '0000163',
  'eulji': '0000161',
  'kentech': '0003139',
  'hansei': '0000201',
  'hyupsung': '0000207',
  'sungkyul': '0000131',
  'sunmoon': '0000129',
  'sangji': '0000119',
  'nambu': '0000216',
  'kangnam': '0000051',
  'konyang': '0000054',
  'dju': '0000095',
  'pcu': '0000113',
};

UniversityDataset dataset(String file) => UniversityDataset.fromJson(
  jsonDecode(File('assets/timetable/$file').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test(
    'New university catalogs keep native weekly data and term boundaries',
    () {
      final files =
          (jsonDecode(File('assets/timetable/catalog.json').readAsStringSync())
                  as List)
              .cast<String>();
      var count = 0;
      final courseIdentities = <String>{};
      final catalogs = <String>{};
      for (final file in files) {
        final university = file.split('/').last.split('-').first;
        if (!identities.containsKey(university)) continue;
        final raw =
            jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
        final loaded = UniversityDataset.fromJson(raw);
        catalogs.add(university);
        expect(loaded.university, university);
        expect(loaded.campusName, isNotEmpty);
        expect(Uri.parse(loaded.sourceUrl).scheme, 'https');
        for (final course in loaded.courses) {
          count++;
          expect(courseIdentities.add(course.sourceId), isTrue);
          expect(course.period, isNotNull, reason: course.sourceId);
          expect(course.period!.end.isBefore(course.period!.start), isFalse);
          // Ordinary offerings remain weekly. Hongik additionally publishes
          // exact dates for four intensive course sections in their plans.
          if (university != 'hongik') {
            expect(course.meetings.every((m) => m.date == null), isTrue);
          }
          for (final meeting in course.meetings.where((m) => m.date != null)) {
            expect(
              DateTime.parse(meeting.date!).isBefore(course.period!.start),
              isFalse,
            );
            expect(
              DateTime.parse(meeting.date!).isAfter(course.period!.end),
              isFalse,
            );
          }
          final saved = course.toTimetable(
            id: course.sourceId,
            mode: LectureMode.inPerson,
          );
          final restored = TimetableClass.fromJson(saved.toJson());
          expect(
            restored.meetings.map((m) => m.toJson()),
            saved.meetings.map((m) => m.toJson()),
          );
          expect(
            classOccurrences(
              [restored],
              [
                course.period!.start.subtract(const Duration(days: 1)),
                course.period!.end.add(const Duration(days: 1)),
              ],
            ),
            isEmpty,
          );
        }
      }
      expect(count, greaterThan(8000));
      for (final entry in identities.entries) {
        final profile = AcademicProfile(
          universityId: 'institution:academyinfo:${entry.value}',
          universityName: entry.key,
          schoolKind: 'fourYear',
        );
        expect(profile.academicSourceId, entry.key);
        expect(
          profile.timetableUniversity,
          catalogs.contains(entry.key) ? entry.key : isNull,
        );
        final foreignCampus = AcademicProfile(
          universityId: profile.universityId,
          universityName: entry.key,
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        );
        expect(foreignCampus.academicSourceId, isNull);
        expect(foreignCampus.timetableCampus, isNull);
      }
    },
  );

  test(
    'Ewha keeps school-returned clocks, rooms and explicitly untimed rows',
    () {
      final loaded = dataset('ewha-unknown-2026-2.json');
      final japanese = loaded.courses.singleWhere(
        (c) => c.code == '10132' && c.section == '01',
      );
      expect(japanese.title, '중급일본어');
      expect(
        japanese.meetings.map(
          (m) => (
            m.weekday,
            m.originalStartMinute,
            m.originalEndMinute,
            m.classroom,
          ),
        ),
        [(3, 480, 555, '학652'), (5, 570, 645, '학652')],
      );
      expect(
        loaded.courses
            .where((c) => c.meetings.isEmpty)
            .every((c) => c.scheduleStatus == 'unscheduled'),
        isTrue,
      );
    },
  );

  test('ICCU half-term weekly rows never recur in the other half', () {
    final loaded = dataset('iccu-songdo-2026-2.json');
    final course = loaded.courses.firstWhere(
      (c) => c.period!.end == DateTime(2026, 10, 26) && c.meetings.isNotEmpty,
    );
    final saved = course.toTimetable(
      id: 'half-term',
      mode: LectureMode.inPerson,
    );
    final last = course.period!.end;
    final inside = last.subtract(
      Duration(days: (last.weekday - course.meetings.first.weekday + 7) % 7),
    );
    expect(classOccurrences([saved], [inside]), isNotEmpty);
    expect(
      classOccurrences([saved], [inside.add(const Duration(days: 7))]),
      isEmpty,
    );
    const unsupported = AcademicProfile(
      universityId: 'institution:academyinfo:0000168',
      universityName: '인천가톨릭대학교',
      schoolKind: 'fourYear',
      campusId: 'academyinfo:0000168',
    );
    expect(unsupported.academicSourceId, 'iccu');
    expect(unsupported.timetableCampus, isNull);
  });

  test('Kangnam uses native literal clocks and course-specific footnotes', () {
    final loaded = dataset('kangnam-main-2026-2.json');
    final course = loaded.courses.singleWhere(
      (c) => c.code == 'NE11702' && c.section == '00',
    );
    expect(
      course.meetings.map(
        (m) => (
          m.weekday,
          m.originalStartMinute,
          m.originalEndMinute,
          m.classroom,
        ),
      ),
      [(1, 710, 870, '샬808')],
    );
    final restricted = loaded.courses.singleWhere(
      (c) => c.code == 'NH41925' && c.section == '00',
    );
    expect(restricted.remarks, contains('공학계열 수강 제한'));
    expect(loaded.courses.any((c) => c.title.contains('동계스포츠')), isFalse);
  });
  test(
    'Hansei uses official plan clock and keeps nonrecurring holds untimed',
    () {
      final loaded = dataset('hansei-main-2026-2.json');
      final course = loaded.courses.singleWhere(
        (c) => c.code == '15904' && c.section == '001',
      );
      expect(
        course.meetings.map(
          (m) => (
            m.weekday,
            m.originalStartMinute,
            m.originalEndMinute,
            m.classroom,
          ),
        ),
        [(1, 900, 1080, '이201')],
      );
      expect(course.period!.start, DateTime(2026, 9, 1));
      expect(course.period!.end, DateTime(2026, 12, 21));
      expect(
        loaded.courses
            .where((c) => c.title == '장기현장실습Ⅱ')
            .every((c) => c.meetings.isEmpty),
        isTrue,
      );
    },
  );

  test(
    'Hongik intensive section follows published dates, regular sections stay weekly',
    () {
      final loaded = dataset('hongik-seoul-2026-2.json');
      final intensive = loaded.courses.singleWhere(
        (c) => c.code == '106611' && c.section == '3',
      );
      expect(intensive.meetings.map((m) => DateTime.parse(m.date!)), [
        DateTime(2026, 9, 4),
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 18),
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 16),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 30),
        DateTime(2026, 11, 2),
      ]);
      expect(
        intensive.meetings.every(
          (m) => m.originalStartMinute == 840 && m.originalEndMinute == 1010,
        ),
        isTrue,
      );
      final regular = loaded.courses.singleWhere(
        (c) => c.code == '106611' && c.section == '1',
      );
      expect(regular.meetings.every((m) => m.date == null), isTrue);
    },
  );
}
