import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Kunsan integrated profile exposes own catalog and rejects foreign campuses',
    () {
      for (final id in [
        'academyinfo:0000009',
        'institution:academyinfo:0000009',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '국립군산대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'kunsan');
        expect(p.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '국립군산대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          isFalse,
        );
      }
    },
  );
  test(
    'Kunsan published planned reservations preserve partial support and official semester on Drive',
    () {
      final courses = [
        for (final campus in ['unknown', 'saemangeum'])
          ...UniversityDataset.fromJson(
            jsonDecode(
                  File(
                    'assets/timetable/kunsan-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>,
          ).courses,
      ];
      expect(courses.length, 1718);
      expect(courses.map((c) => c.sourceId).toSet().length, 1718);
      expect(courses.where((c) => c.hasSchedulableMeetings).length, 1125);
      expect(courses.expand((c) => c.meetings).length, 22984);
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized').length,
        495,
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled').length,
        98,
      );
      final partial = courses.singleWhere(
        (c) => c.codeAndSection == '115911-01',
      );
      expect(partial.sourceSchedule, contains('①'));
      expect(
        partial.meetings.every(
          (m) => m.originalStartMinute == 670 && m.originalEndMinute == 730,
        ),
        isTrue,
      );
      expect(partial.remarks, contains('부분'));
      expect(partial.remarks, contains('월'));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses) {
          expect(c.remarks, contains('9월 4일·9월 9일'));
          expect(c.remarks, contains('통합정보시스템'));
          if (!c.hasSchedulableMeetings) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, isTrue);
          // 교시표 1~10교시: 09:10 시작, 50분 수업+10분 쉬는 시간 = 60분 슬롯.
          for (final m in c.meetings) {
            expect(m.originalStartMinute % 60, 10, reason: c.codeAndSection);
            expect(m.originalStartMinute, inInclusiveRange(550, 1090));
            expect(
              (m.originalEndMinute - m.originalStartMinute) % 60,
              0,
              reason: c.codeAndSection,
            );
          }
          expect(saved.period!.start, DateTime(2026, 8, 31));
          expect(saved.period!.end, DateTime(2026, 12, 17));
          expect(saved.note, contains('학기'));
          for (final m in saved.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            expect(m.teachingDate!.isBefore(DateTime(2026, 8, 31)), isFalse);
            expect(m.teachingDate!.isAfter(DateTime(2026, 12, 10)), isFalse);
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-09-26',
              '2026-10-03',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
          }
          final restored = TimetableClass.fromJson(
            jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
          );
          expect(restored.toJson(), saved.toJson());
          expect(restored.defaultMode, mode);
          expect(restored.note, c.remarks);
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
        }
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        expect(restored.courses.length, 1125);
        for (final e in restored.courses.entries) {
          expect(e.value.value, values[e.key]!.value);
        }
      }
    },
  );
}
