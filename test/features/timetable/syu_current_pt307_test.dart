import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root =
    'work/university-research/catalog-c/syu-pt-room-teacher-unpublished-own-clock-v4-20261009/';
Map<String, dynamic> read(String name) {
  final path = '$root$name';
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

// Independently transcribed printed source clock/own calendar, not candidate expectations.
const days =
    '2026-09-07 2026-09-14 2026-09-21 2026-09-28 2026-10-12 2026-10-19 2026-11-09 2026-11-16 2026-11-23 2026-11-30 2026-12-07';
void main() {
  test(
    'SYU PT native307 image roomteacherunpublished with owncurrentHH, other1390, three modes fullDrive',
    () {
      final raw = read('syu-main-2026-2.pt307-own-clock-planned-v4.json');
      final before = read('prior-full-1391-93-945-baseline.json');
      final rows = raw['courses'] as List;
      final old = before['courses'] as List;
      expect(rows, hasLength(1391));
      expect(raw['researchOnly'], true);
      expect(raw['completionClaim'], false);
      for (var i = 0; i < rows.length; i++) {
        if ((rows[i] as Map)['sourceId'] != 'syu/main/2026-2/307') {
          expect(rows[i], old[i]);
        }
      }
      final row =
          rows.singleWhere(
                (r) => (r as Map)['sourceId'] == 'syu/main/2026-2/307',
              )
              as Map;
      final previous =
          old.singleWhere(
                (r) => (r as Map)['sourceId'] == 'syu/main/2026-2/307',
              )
              as Map;
      for (final key in [
        'sourceId',
        'campus',
        'academicYear',
        'semester',
        'courseCode',
        'courseName',
        'section',
        'professor',
        'classification',
        'departmentClassifications',
        'credits',
        'departmentCredits',
        'departments',
        'sourceSchedule',
        'sourceClassroom',
      ]) {
        expect(row[key], previous[key]);
      }
      final proof = read('native-own-clock-whole-education-proof.json');
      expect(
        proof['sourceImageSHA256'],
        '6e529ff18e66fe114b17bbc2ece6f8f969d235f6ee00d83072f70cfd79030479',
      );
      expect(proof['nativeImageOwnCellRect'], [91, 799, 151, 995]);
      expect(proof['nativeImageProfessor'], '');
      expect(proof['nativeImageRoom'], '');
      expect(proof['printedOwnPeriodClock'], {
        '5': ['13:00', '13:50'],
        '6': ['14:00', '14:50'],
        '7': ['15:00', '15:50'],
        '8': ['16:00', '16:50'],
      });
      final source = row['sourceEducation'] as Map;
      expect(
        source['nativePublicCells'],
        (previous['sourceEducation'] as Map)['nativePublicCells'],
      );
      expect(source['ptImageTeacherExplicit'], false);
      expect(source['wholeUniversityClockConfirmed'], false);
      expect(source['actualOperatingVerified'], false);
      final dataset = UniversityDataset.fromJson(raw);
      final c = dataset.courses.singleWhere(
        (c) => c.sourceId == 'syu/main/2026-2/307',
      );
      expect(c.code, '1001045');
      expect(c.title, '근골격물리치료학 III');
      expect(c.section, '');
      expect(c.professor, '이민우');
      expect(c.campus, 'main');
      expect(c.meetings, hasLength(11));
      expect(
        c.meetings
            .map(
              (m) =>
                  '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
            )
            .toSet(),
        days.split(' ').map((d) => '$d|1|780|1010|요한관423호(中)강의실').toSet(),
      );
      expect(
        dataset.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(94),
      );
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        956,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = dataset.courses
            .where((c) => c.hasSchedulableMeetings)
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
        expect(restored, hasLength(94));
        final by = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final orig = by[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, orig.title);
          expect(c.professor, orig.professor);
          expect(c.note, orig.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            orig.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
