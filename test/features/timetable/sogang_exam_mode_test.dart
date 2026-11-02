import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'known physical midterm stays physical while lecture mode is user selected',
    () {
      final data = UniversityDataset.fromJson(
        jsonDecode(
              File(
                'assets/timetable/sogang-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      expect(
        data.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(1309),
      );
      expect(data.courses.expand((c) => c.meetings), hasLength(21141));
      final c = data.courses.singleWhere(
        (c) => c.codeAndSection == 'AIE4011-01',
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final saved = c.toTimetable(id: c.sourceId, mode: mode);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.toJson(), saved.toJson());
        expect(restored.meetings, hasLength(28));
        expect(restored.note, contains('Python 프로그래밍 능력이 필요'));
        expect(restored.note, contains('컴퓨터공학과'));
        for (final m in restored.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(m.originalStartMinute, 810);
          expect(m.originalEndMinute, 885);
          // 2026-10-23 공식 조회에서 10/22 시험 강의실이 K401로 바뀌었다.
          expect(m.classroom, m.date == '2026-10-22' ? 'K401' : 'AS510');
          expect(
            restored.modeOn(m, m.teachingDate!),
            m.date == '2026-10-22' ? LectureMode.inPerson : mode,
          );
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 9, 24),
              DateTime(2026, 10, 20),
              DateTime(2026, 12, 17),
            ],
          ),
          isEmpty,
        );
        expect(
          classOccurrences([restored], [DateTime(2026, 10, 22)]),
          hasLength(1),
        );
        expect(
          classOccurrences([restored], [DateTime(2026, 9, 1)]),
          hasLength(mode == LectureMode.video ? 0 : 1),
        );
      }
    },
  );
}
