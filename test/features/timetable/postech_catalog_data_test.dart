import 'package:daily/core/academic/academic_profile.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';

void main() {
  test(
    'POSTECH profile exposes its own source and rejects foreign campuses',
    () {
      for (final id in [
        'institution:academyinfo:0000188',
        'academyinfo:0000188',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '포항공과대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'postech');
        expect(profile.timetableCampus, 'main');
        expect(profile.academicSourceId, 'postech');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '포항공과대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          isFalse,
        );
      }
    },
  );
  test(
    'POSTECH current public planned slots, actual exceptions and Drive restore',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/postech-main-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final model = UniversityDataset.fromJson(raw);
      expect(model.courses.length, 418);
      expect(model.courses.where((c) => c.hasSchedulableMeetings).length, 334);
      final closures = {
        '2026-09-18',
        '2026-09-19',
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
        '2026-12-03',
      };
      var dates = 0;
      final values = <String, TimetableSyncValue>{};
      for (final c in model.courses) {
        dates += c.meetings.length;
        for (final m in c.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(m.teachingDate!.isBefore(DateTime(2026, 9, 7)), isFalse);
          expect(m.teachingDate!.isAfter(DateTime(2026, 12, 24)), isFalse);
          expect(m.weekday, isNot(7));
          expect(closures, isNot(contains(m.date)));
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
          expect(restored.note, c.remarks);
          if (mode == LectureMode.inPerson) {
            final key = timetableCourseSyncKey(t);
            values[key] = TimetableSyncValue(
              {...t.toJson(), 'id': key},
              DateTime.utc(2026, 10, 8),
              'public-research',
            );
          }
        }
      }
      expect(dates, 10254);
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final docRestored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(docRestored.courses.length, 334);
      for (final e in docRestored.courses.entries) {
        expect(e.value.value, values[e.key]!.value);
      }
      expect(
        model.courses
            .where(
              (c) =>
                  c.code == 'GEDU101' && ['02', '04', '08'].contains(c.section),
            )
            .every((c) => !c.hasSchedulableMeetings),
        isTrue,
      );
      expect(
        model.courses
            .singleWhere((c) => c.code == 'MECH250' && c.section == '02')
            .hasSchedulableMeetings,
        isTrue,
      );
      final mixed = model.courses.singleWhere((c) => c.code == 'SEMI323');
      final importedMixed = mixed.toTimetable(
        id: mixed.sourceId,
        mode: LectureMode.inPerson,
      );
      expect(
        importedMixed.overrides.values
            .where((v) => v == LectureMode.liveOnline)
            .length,
        5,
      );
      expect(
        mixed.meetings.where((m) => m.date == '2026-11-10').single.classroom,
        isEmpty,
      );
      final paired = model.courses.singleWhere((c) => c.code == 'NGCN302');
      expect(
        paired.meetings
            .where((m) => m.originalStartMinute == 1140)
            .every((m) => m.classroom.isEmpty),
        isTrue,
      );
      final intro = model.courses.singleWhere((c) => c.code == 'MATH199');
      expect(intro.meetings.every((m) => m.date == '2026-09-10'), isTrue);
      final conditional = model.courses.singleWhere((c) => c.code == 'CHEB207');
      expect(
        conditional.meetings.any(
          (m) => m.weekday == 2 && m.originalStartMinute == 1020,
        ),
        isFalse,
      );
      for (final code in [
        'EECE490E',
        'DISU301',
        'CITE201',
        'GEDU162',
        'MECH470',
      ]) {
        expect(
          model.courses
              .where((c) => c.code == code)
              .every((c) => !c.hasSchedulableMeetings),
          isTrue,
        );
      }
    },
  );
}
