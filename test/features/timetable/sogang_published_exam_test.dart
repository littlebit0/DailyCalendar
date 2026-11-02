import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public exam durations and rooms remain distinct from regular lesson plans',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/sogang-unknown-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final data = UniversityDataset.fromJson(raw);
      expect(data.courses, hasLength(1541));
      expect(
        data.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(1309),
      );
      expect(data.courses.expand((c) => c.meetings), hasLength(21141));
      for (final id in ['GME4007-01', 'GME3001-01', 'EDU3033-01']) {
        final course = data.courses.singleWhere((c) => c.codeAndSection == id);
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.video,
        );
        final doc = TimetableSyncDocument.legacy(
          courses: [saved],
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses().single;
        final expected = saved.toJson();
        expected['id'] = 'source/${jsonEncode([2026, '2', course.sourceId])}';
        expect(restored.toJson(), expected);
        expect(restored.note, contains('공시 수업 계획'));
        final exam = restored.meetings.singleWhere(
          (m) => m.date == (id == 'GME3001-01' ? '2026-10-21' : '2026-10-26'),
        );
        expect(exam.originalStartMinute, 810);
        // EDU3033-01 시험은 2026-10-23 공식 조회에서 13:30~15:00으로 바뀌었다.
        expect(exam.originalEndMinute, id == 'EDU3033-01' ? 900 : 885);
        expect(
          exam.classroom,
          id == 'GME3001-01'
              ? 'K502'
              : id == 'EDU3033-01'
              ? 'J104'
              : 'MA402',
        );
        for (final m in restored.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(restored.modeOn(m, m.teachingDate!), LectureMode.inPerson);
          if (m != exam) {
            expect(
              m.originalEndMinute - m.originalStartMinute,
              id == 'EDU3033-01' ? 110 : 165,
            );
            expect(
              m.classroom,
              id == 'GME3001-01'
                  ? 'GA401'
                  : id == 'EDU3033-01'
                  ? 'J104'
                  : 'MA402',
            );
          }
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 10, 5),
              DateTime(2026, 12, 14),
              DateTime(2026, 12, 21),
              DateTime(2027, 1, 1),
            ],
          ),
          isEmpty,
        );
        if (id == 'GME3001-01') {
          expect(restored.meetings, hasLength(14));
          expect(
            classOccurrences([restored], [DateTime(2026, 12, 9)]),
            isEmpty,
          );
        } else {
          expect(restored.meetings, hasLength(13));
        }
      }
    },
  );
}
