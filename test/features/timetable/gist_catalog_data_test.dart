import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/core/academic/academic_profile.dart';

void main() {
  test('GIST only exposes its actual school and campus', () {
    for (final id in [
      'institution:academyinfo:0000381',
      'academyinfo:0000381',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '광주과학기술원',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'gist');
      expect(profile.timetableCampus, 'main');
      expect(profile.academicSourceId, 'gist');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '광주과학기술원',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test(
    'GIST source notes and stable identities survive the actual dated Drive document',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/gist-main-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final courses = UniversityDataset.fromJson(
        raw,
      ).courses.where((c) => c.hasSchedulableMeetings).toList();
      expect(courses, hasLength(390));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
        }
        final document = TimetableSyncDocument.records(courses: values);
        expect(document.schemaVersion, 2);
        final restored = TimetableSyncDocument.fromJson(document.toJson());
        expect(restored.courses.keys.toSet(), values.keys.toSet());
        for (final key in values.keys) {
          expect(restored.courses[key]!.value, values[key]!.value);
        }
      }
    },
  );
  test(
    'actual GIST printed times retain source sections and closures through Drive restore',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/gist-main-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final model = UniversityDataset.fromJson(raw);
      const closed = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
        '2026-11-17',
      };
      expect(model.courses.length, 407);
      final calculus = model.courses.singleWhere((c) => c.code == 'GS1001');
      expect(calculus.professor, contains('최정옥'));
      expect(calculus.professor, contains('유현주'));
      expect(
        calculus.meetings.any((m) => m.originalStartMinute == 1140),
        isTrue,
      );
      var dates = 0;
      for (final c in model.courses) {
        dates += c.meetings.length;
        expect(c.departments, isEmpty);
        expect(c.departmentRemarks, isEmpty);
        expect(c.sourceRemarks, isNotEmpty);
        expect(
          c.codeAndSection,
          c.section.isEmpty ? c.code : '${c.code}-${c.section}',
        );
        if (c.section.isEmpty) {
          expect(c.remarks, contains('분반 번호 미게시'));
        }
        for (final m in c.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(closed, isNot(contains(m.date)));
          expect(m.teachingDate!.isBefore(DateTime(2026, 8, 31)), isFalse);
          expect(m.teachingDate!.isAfter(DateTime(2026, 12, 18)), isFalse);
        }
        if (!c.hasSchedulableMeetings) {
          continue;
        }
        for (final mode in [
          LectureMode.inPerson,
          LectureMode.liveOnline,
          LectureMode.video,
        ]) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          final restored = TimetableClass.fromJson(
            jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>,
          );
          expect(t.isValid, isTrue);
          expect(restored.toJson(), t.toJson());
          expect(restored.defaultMode, mode);
          expect(restored.note, contains(c.sourceRemarks));
        }
      }
      expect(dates, 11141);
      final saturday = model.courses.singleWhere((c) => c.code == 'AX5245');
      expect(saturday.meetings.every((m) => m.weekday == 6), isTrue);
      expect(
        model.courses
            .where((c) => c.code == 'HS2507' || c.code == 'LH2507')
            .every((c) => !c.hasSchedulableMeetings),
        isTrue,
      );
    },
  );
}
