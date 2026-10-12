import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'current published plans preserve restrictions, explicit exam rooms and unknown mode',
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
        hasLength(1307),
      );
      expect(data.courses.expand((c) => c.meetings), hasLength(20598));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        for (final id in ['AIE3051-02', 'AIE4056-01', 'AMC3080-01']) {
          final c = data.courses.singleWhere((c) => c.codeAndSection == id);
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          final restored = TimetableClass.fromJson(
            jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
          );
          expect(restored.toJson(), saved.toJson());
          expect(restored.note, contains('공시 수업 계획'));
          expect(restored.meetings, hasLength(id == 'AMC3080-01' ? 29 : 28));
          final exam = restored.meetings.singleWhere(
            (m) => m.date == (id == 'AIE3051-02' ? '2026-10-20' : '2026-10-22'),
          );
          expect(exam.originalEndMinute - exam.originalStartMinute, 75);
          expect(
            exam.classroom,
            id == 'AIE3051-02'
                ? 'K301'
                : id == 'AIE4056-01'
                ? 'AS414'
                : 'J102',
          );
          for (final m in restored.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            expect(
              restored.modeOn(m, m.teachingDate!),
              id == 'AMC3080-01' ? LectureMode.inPerson : mode,
            );
            if (id == 'AIE3051-02' && m != exam) expect(m.classroom, 'RA408');
          }
          if (id.startsWith('AIE')) expect(restored.note, contains('컴퓨터공학과'));
          expect(
            classOccurrences(
              [restored],
              [
                DateTime(2026, 9, 24),
                DateTime(2026, 12, 17),
                DateTime(2027, 1, 1),
              ],
            ),
            isEmpty,
          );
          if (id == 'AMC3080-01') {
            expect(
              classOccurrences([restored], [DateTime(2026, 10, 27)]),
              isEmpty,
            );
            expect(
              classOccurrences([restored], [DateTime(2026, 12, 15)]),
              hasLength(1),
            );
          }
        }
      }
    },
  );
}
