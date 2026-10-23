import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'explicit classroom plans and partial unknown closures stay distinct',
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
        hasLength(1307),
      );
      expect(data.courses.expand((c) => c.meetings), hasLength(20598));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        for (final id in ['AIE4014-01', 'AIE3053-02', 'AMC4100-01']) {
          final c = data.courses.singleWhere((c) => c.codeAndSection == id);
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          final restored = TimetableClass.fromJson(saved.toJson());
          expect(restored.toJson(), saved.toJson());
          expect(restored.note, contains('공시'));
          expect(
            restored.meetings,
            hasLength(
              id == 'AIE4014-01'
                  ? 26
                  : id == 'AIE3053-02'
                  ? 27
                  : 22,
            ),
          );
          for (final m in restored.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            expect(m.originalEndMinute - m.originalStartMinute, 75);
            expect(
              restored.modeOn(m, m.teachingDate!),
              id == 'AIE3053-02' ? mode : LectureMode.inPerson,
            );
          }
          expect(
            classOccurrences(
              [restored],
              [
                DateTime(2026, 9, 25),
                DateTime(2026, 10, 5),
                DateTime(2026, 10, 9),
                DateTime(2026, 12, 16),
                DateTime(2027, 1, 1),
              ],
            ),
            isEmpty,
          );
          if (id == 'AMC4100-01') {
            expect(
              classOccurrences(
                [restored],
                [
                  DateTime(2026, 9, 16),
                  DateTime(2026, 9, 18),
                  DateTime(2026, 10, 21),
                  DateTime(2026, 11, 18),
                  DateTime(2026, 11, 20),
                ],
              ),
              isEmpty,
            );
            expect(
              classOccurrences(
                [restored],
                [DateTime(2026, 12, 2), DateTime(2026, 12, 4)],
              ),
              hasLength(2),
            );
          }
          if (id == 'AIE4014-01') {
            expect(
              classOccurrences(
                [restored],
                [DateTime(2026, 12, 8), DateTime(2026, 12, 10)],
              ),
              isEmpty,
            );
            expect(
              classOccurrences([restored], [DateTime(2026, 10, 22)]),
              hasLength(1),
            );
          }
        }
      }
    },
  );
}
