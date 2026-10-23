import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'math plans preserve exact exams, lecture rooms, prerequisite and mode in Drive',
    () {
      final data = UniversityDataset.fromJson(
        jsonDecode(
              File(
                'assets/timetable/sogang-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      const cases = [
        ('MAT1060-01', 14, 810, 100, '2026-10-26', 'RA205', 'RA205'),
        ('MAT1060-02', 14, 930, 100, '2026-10-26', 'RA205', 'RA205'),
        ('MAT1060-03', 14, 810, 100, '2026-10-21', 'RA205', 'RA205'),
        ('MAT2110-01', 28, 720, 75, '2026-10-20', 'RA410', 'RA410'),
        ('MAT2110-02', 28, 630, 75, '2026-10-26', 'RA408', 'RA408'),
        ('MAT2110-03', 28, 810, 75, '2026-10-22', 'RA310', 'R404'),
        ('MAT2110-04', 27, 900, 75, '2026-10-23', 'RA310', 'RA310'),
      ];
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final v in cases) {
          final c = data.courses.singleWhere((c) => c.codeAndSection == v.$1);
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.meetings, hasLength(v.$2));
          for (final m in saved.meetings) {
            final exam = m.date == v.$5;
            expect(m.originalStartMinute, v.$3);
            expect(
              m.originalEndMinute - m.originalStartMinute,
              exam ? 75 : v.$4,
            );
            expect(m.classroom, exam ? v.$7 : v.$6);
            expect(
              saved.modeOn(m, m.teachingDate!),
              v.$1 == 'MAT2110-03' ? LectureMode.inPerson : mode,
            );
          }
          expect(
            classOccurrences(
              [saved],
              [
                DateTime(2026, 9, 24),
                DateTime(2026, 9, 25),
                DateTime(2026, 10, 5),
                DateTime(2026, 10, 9),
                DateTime(2026, 12, 15),
                DateTime(2026, 12, 16),
                DateTime(2026, 12, 21),
              ],
            ),
            isEmpty,
          );
          if (v.$1 == 'MAT2110-02') {
            expect(saved.note, contains('한국어 수업·영어 판서 및 영어 시험'));
            expect(saved.note, contains('수강허가서는 승인되지'));
          }
          if (v.$1 == 'MAT2110-04') expect(saved.note, contains('수업규정 동의 확인서'));
          if (v.$1 == 'MAT1060-03') {
            expect(
              saved.meetings.map((m) => m.date),
              isNot(contains('2026-10-28')),
            );
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
        }
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(
                jsonEncode(
                  TimetableSyncDocument.records(
                    courses: values,
                    schemaVersion: 2,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>,
        );
        expect(restored.courses.keys.toSet(), values.keys.toSet());
        for (final e in restored.courses.entries) {
          expect(e.value.value, values[e.key]!.value);
        }
      }
    },
  );
}
