import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('published no-class instructions override reserved midterm slots', () {
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
      for (final id in ['AAS2016-01', 'AAT2003-01']) {
        final c = data.courses.singleWhere((c) => c.codeAndSection == id);
        final saved = c.toTimetable(id: c.sourceId, mode: mode);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.toJson(), saved.toJson());
        expect(restored.note, contains('공시'));
        expect(restored.meetings, hasLength(id == 'AAS2016-01' ? 26 : 13));
        for (final m in restored.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(
            m.originalEndMinute - m.originalStartMinute,
            id == 'AAS2016-01' ? 75 : 165,
          );
          expect(m.classroom, id == 'AAS2016-01' ? 'D303A' : 'X513');
          expect(
            restored.modeOn(m, m.teachingDate!),
            id == 'AAS2016-01' ? mode : LectureMode.inPerson,
          );
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 26),
              DateTime(2026, 12, 21),
            ],
          ),
          isEmpty,
        );
        if (id == 'AAS2016-01') {
          expect(
            classOccurrences(
              [restored],
              [DateTime(2026, 10, 21), DateTime(2026, 12, 14)],
            ),
            isEmpty,
          );
        }
      }
    }
  });
}
