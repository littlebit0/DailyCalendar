import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test('Kyonggi integrated profile exposes published Suwon scope only', () {
    for (final id in [
      'academyinfo:0000056',
      'institution:academyinfo:0000056',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '경기대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'kyonggi');
      expect(profile.timetableCampus, 'suwon');
      expect(profile.academicSourceId, 'kyonggi');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경기대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000058',
        ).timetableSupported,
        isFalse,
      );
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경기대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test(
    'actual Kyonggi subject codes and stable registration IDs preserve plans through Drive',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/kyonggi-suwon-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final model = UniversityDataset.fromJson(raw);
      expect(model.courses.length, 1640);
      expect(model.courses.where((c) => c.hasSchedulableMeetings).length, 1594);
      const closed = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
        '2026-11-08',
      };
      final values = <String, TimetableSyncValue>{};
      var count = 0;
      for (final c in model.courses) {
        expect(c.code, matches(RegExp(r'^[A-Z]{2,4}\d{3,4}$')));
        expect(c.section, isEmpty);
        expect(c.codeAndSection, c.code);
        final metadata =
            (raw['courses'] as List).singleWhere(
                  (r) => r['sourceId'] == c.sourceId,
                )['metadata']
                as Map;
        if (metadata['actualOpeningDepartmentFromPageHeader']
            case final String header) {
          expect(c.departments, [header]);
          expect(c.departmentCredits[header], c.credits);
          expect(c.remarkForDepartment(header), c.sourceRemarks);
        } else {
          expect(c.departments, isEmpty);
        }
        if (metadata['sourcePDF'] == '2026-2_교양.pdf') {
          expect(c.categoriesFor(), [CourseCategory.generalEducation]);
          expect(c.sourceRemarks, contains(metadata['nativeClassification']));
        }
        expect(c.sourceRemarks, contains('분반 번호 미게시'));
        count += c.meetings.length;
        for (final m in c.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(m.teachingDate!.isBefore(DateTime(2026, 9, 1)), isFalse);
          expect(m.teachingDate!.isAfter(DateTime(2026, 12, 14)), isFalse);
          expect(closed, isNot(contains(m.date)));
        }
        if (!c.hasSchedulableMeetings) {
          continue;
        }
        for (final mode in [
          LectureMode.inPerson,
          LectureMode.liveOnline,
          LectureMode.video,
        ]) {
          final imported = c.toTimetable(id: c.sourceId, mode: mode);
          expect(imported.isValid, isTrue);
          final restored = TimetableClass.fromJson(
            jsonDecode(jsonEncode(imported.toJson())) as Map<String, dynamic>,
          );
          expect(restored.toJson(), imported.toJson());
          expect(restored.defaultMode, mode);
          expect(restored.note, c.remarks);
          if (mode == LectureMode.inPerson) {
            final key = timetableCourseSyncKey(imported);
            values[key] = TimetableSyncValue(
              {...imported.toJson(), 'id': key},
              DateTime.utc(2026, 10, 8),
              'research',
            );
          }
        }
      }
      for (final registration in ['0577', '0580']) {
        final changed = model.courses.singleWhere(
          (c) => c.sourceId.endsWith(registration),
        );
        final thursdays = changed.meetings.where((m) => m.weekday == 4);
        expect(thursdays.length, 14);
        expect(
          thursdays.every(
            (m) =>
                m.originalStartMinute == 540 &&
                m.originalEndMinute == 590 &&
                m.classroom.isEmpty,
          ),
          isTrue,
        );
      }
      expect(count, 23540);
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final restoredDoc = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(restoredDoc.courses.length, 1594);
      for (final e in restoredDoc.courses.entries) {
        expect(e.value.value, values[e.key]!.value);
      }
      final split = model.courses.singleWhere(
        (c) => c.sourceId.endsWith('0415'),
      );
      expect(split.code, 'AS830');
      expect(
        split.meetings
            .where((m) => m.originalStartMinute == 540)
            .every((m) => m.classroom.contains('6303')),
        isTrue,
      );
      expect(
        split.meetings
            .where((m) => m.originalStartMinute == 600)
            .every((m) => m.classroom.contains('종합201')),
        isTrue,
      );
      for (final id in ['1633', '1634', '1635', '1638', '1639', '1640']) {
        final partial = model.courses.singleWhere(
          (c) => c.sourceId.endsWith(id),
        );
        expect(partial.meetings.map((m) => m.date), [
          '2026-09-02',
          '2026-09-09',
          '2026-09-16',
          '2026-09-23',
          '2026-10-14',
          '2026-10-21',
        ]);
        expect(partial.remarks, contains('종료일 확정 주장이 아니며'));
      }
      for (final course in model.courses.where((c) => c.code == 'IA002')) {
        expect(
          course.meetings.any(
            (m) =>
                m.date!.compareTo('2026-09-29') >= 0 &&
                m.date!.compareTo('2026-10-12') <= 0,
          ),
          isFalse,
        );
        expect(course.remarks, contains('현직자 2명 이상'));
      }
      for (final id in ['1492', '1493', '1494']) {
        expect(
          model.courses
              .singleWhere((c) => c.sourceId.endsWith(id))
              .hasSchedulableMeetings,
          isFalse,
        );
      }
      final ninth = model.courses.singleWhere(
        (c) => c.sourceId.endsWith('1340'),
      );
      expect(
        ninth.meetings.every(
          (m) => m.originalStartMinute == 1020 && m.originalEndMinute == 1070,
        ),
        isTrue,
      );
      for (final id in ['0058', '0159', '1545']) {
        expect(
          model.courses
              .singleWhere((c) => c.sourceId.endsWith(id))
              .hasSchedulableMeetings,
          isFalse,
        );
      }
    },
  );
}
