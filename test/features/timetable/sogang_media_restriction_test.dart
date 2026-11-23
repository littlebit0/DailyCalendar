import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GIS source media restriction and unscheduled exam clocks survive restore',
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
        hasLength(1497),
      );
      expect(data.courses.expand((c) => c.meetings), hasLength(33325));
      final c = data.courses.singleWhere(
        (c) => c.codeAndSection == 'GIS1007-01',
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final saved = c.toTimetable(id: c.sourceId, mode: mode);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.toJson(), saved.toJson());
        expect(restored.note, contains('미디어 전공 대상'));
        expect(restored.note, contains('학교 공시 수업 계획'));
        expect(restored.meetings, hasLength(28));
        for (final m in restored.meetings) {
          expect(m.teachingDate!.weekday, m.weekday);
          expect(m.originalStartMinute, 810);
          expect(m.originalEndMinute, 885);
          expect(m.classroom, 'K306');
          expect(restored.modeOn(m, m.teachingDate!), mode);
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 9, 24),
              DateTime(2026, 10, 20),
              DateTime(2026, 10, 26),
              DateTime(2026, 12, 17),
              DateTime(2026, 12, 21),
            ],
          ),
          isEmpty,
        );
        expect(
          classOccurrences(
            [restored],
            [DateTime(2026, 9, 22), DateTime(2026, 10, 22)],
          ),
          hasLength(mode == LectureMode.video ? 0 : 2),
        );
      }
      final gme = data.courses.singleWhere(
        (c) => c.codeAndSection == 'GME3000-01',
      );
      expect(gme.hasSchedulableMeetings, isTrue);
      final planned = gme.toTimetable(
        id: gme.sourceId,
        mode: LectureMode.inPerson,
      );
      expect(classOccurrences([planned], [DateTime(2026, 9, 1)]), hasLength(1));
      expect(
        classOccurrences(
          [planned],
          [
            DateTime(2026, 10, 20),
            DateTime(2026, 10, 22),
            DateTime(2026, 12, 7),
            DateTime(2026, 12, 8),
            DateTime(2026, 12, 9),
            DateTime(2026, 12, 10),
            DateTime(2026, 12, 15),
            DateTime(2026, 12, 17),
          ],
        ),
        isEmpty,
      );
      final jas = data.courses.singleWhere(
        (c) => c.codeAndSection == 'JAS4006-01',
      );
      expect(jas.meetings, hasLength(27));
      expect(jas.meetings.every((m) => m.classroom == 'GA403'), isTrue);
      final jasSaved = jas.toTimetable(
        id: jas.sourceId,
        mode: LectureMode.inPerson,
      );
      expect(
        classOccurrences([jasSaved], [DateTime(2026, 9, 1)]),
        hasLength(1),
      );
      expect(classOccurrences([jasSaved], [DateTime(2026, 10, 20)]), isEmpty);
      final examOnly = data.courses.singleWhere(
        (c) => c.codeAndSection == 'EEE4185-01',
      );
      // The published exam stays; the official weekday and clock are now a
      // weekly reservation too (2026-11-23 user decision).
      final exam = examOnly.meetings.where((m) => m.date == '2026-10-25');
      expect(exam, hasLength(1));
      expect(exam.single.originalStartMinute, 1080);
      expect(exam.single.originalEndMinute, 1155);
      expect(exam.single.classroom, isEmpty);
      expect(examOnly.meetings.length, greaterThan(1));
      // Held before; its official weekday and clock are reserved weekly
      // since the 2026-11-23 user decision.
      for (final id in ['HISG104-01']) {
        expect(
          data.courses
              .singleWhere((c) => c.codeAndSection == id)
              .hasSchedulableMeetings,
          isTrue,
        );
      }
    },
  );
}
