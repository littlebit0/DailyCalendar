import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'DGIST identity exposes reviewed source but rejects unrelated campuses',
    () {
      for (final id in [
        'institution:academyinfo:0000382',
        'academyinfo:0000382',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '대구경북과학기술원',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'dgist');
        expect(profile.timetableCampus, 'unknown');
        expect(profile.academicSourceId, 'dgist');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '대구경북과학기술원',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          isFalse,
        );
      }
    },
  );
  test(
    'DGIST curriculum variants and real clocks survive Drive without exam or research recurrence',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/dgist-unknown-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final courses = UniversityDataset.fromJson(raw).courses;
      expect(courses, hasLength(569));
      final approved = courses.where((c) => c.hasSchedulableMeetings).toList();
      expect(approved, hasLength(196));
      expect(approved.expand((c) => c.meetings), hasLength(4071));
      final prior = approved
          .where(
            (c) => {
              'BE101a-01',
              'BE201-01',
              'BE204-01',
              'BE206-04',
              'BR202-01',
            }.contains(c.codeAndSection),
          )
          .toList();
      expect(prior.map((c) => c.codeAndSection).toSet(), {
        'BE101a-01',
        'BE201-01',
        'BE204-01',
        'BE206-04',
        'BR202-01',
      });
      expect(prior.expand((c) => c.meetings), hasLength(108));
      for (final c in courses.where(
        (c) => c.code.startsWith('RP') || c.code.startsWith('INT'),
      )) {
        expect(c.meetings, isEmpty);
        expect(c.sourceSchedule, isNotEmpty);
      }
      expect(
        approved.singleWhere((c) => c.code == 'BE101a').remarks,
        contains('공통필수'),
      );
      expect(
        approved.singleWhere((c) => c.code == 'BE201').remarks,
        contains('선형대수와 미적분'),
      );
      expect(
        approved.singleWhere((c) => c.code == 'BE204').remarks,
        contains('일부만 게시'),
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in approved) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, isTrue);
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
          for (final m in saved.meetings) {
            expect(m.date, isNotNull);
            expect(m.teachingDate!.weekday, m.weekday);
            expect(m.teachingDate!.isBefore(DateTime(2026, 8, 24)), isFalse);
            expect(m.teachingDate!.isAfter(DateTime(2026, 12, 6)), isFalse);
            expect(
              m.date!.compareTo('2026-10-12') >= 0 &&
                  m.date!.compareTo('2026-10-16') <= 0,
              isFalse,
            );
            expect(
              m.date,
              isNot('2026-10-05'),
              reason:
                  'ordinary course date must not include substitute holiday',
            );
          }
        }
        final restored = TimetableSyncDocument.fromJson(
          TimetableSyncDocument.records(courses: values).toJson(),
        );
        expect(restored.courses.keys.toSet(), values.keys.toSet());
        for (final key in values.keys) {
          final before = TimetableClass.fromJson(
            Map<String, dynamic>.from(values[key]!.value as Map),
          );
          final after = TimetableClass.fromJson(
            Map<String, dynamic>.from(restored.courses[key]!.value as Map),
          );
          expect(after.toJson(), before.toJson());
          for (final m in after.meetings) {
            expect(after.modeOn(m, m.teachingDate!), mode);
          }
        }
      }
    },
  );
}
