import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root =
    'work/university-research/catalog-r/kaist/nqe-current-ug-v2-20261009/';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
int minute(String text) {
  final parts = text.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

const expectedGrid = <String, List<(String, String, int)>>{
  'NQE10001': [('B17', 'B17:B19', 1), ('M17', 'M17:M19', 3)],
  'NQE20003': [('B11', 'B11:B13', 1), ('M11', 'M11:M13', 3)],
  'NQE20004': [('F14', 'F14:F16', 1), ('Q14', 'Q14:Q16', 3)],
  'NQE20011': [('I7', 'I7:I9', 2), ('T7', 'T7:T9', 4)],
  'NQE20072': [('H14', 'H14:H16', 2), ('S14', 'S14:S16', 4)],
  'NQE30001': [('D17', 'D17:D19', 1), ('O17', 'O17:O19', 3)],
  'NQE30022': [('E11', 'E11:E13', 1), ('P11', 'P11:P13', 3)],
  'NQE30073': [('H11', 'H11:H13', 2), ('S11', 'S11:S13', 4)],
  'NQE.30084': [('E7', 'E7:E9', 1), ('P7', 'P7:P9', 3)],
  'NQE40002': [('E5', 'E5:E6', 1), ('V17', 'V17:V23', 4)],
  'NQE40084': [('C14', 'C14:C16', 1), ('N14', 'N14:N16', 3)],
};
void main() {
  test(
    'KAIST NQE current UG grid and 296 ordinary dates, existing AIC10 and full three-mode Drive',
    () {
      final sourceRows =
          jsonDecode(
                fixtureFile(
                  'work/university-research/root-kaist-public-followup-20261009/sheet1-cells.json',
                ).readAsStringSync(),
              )
              as List;
      final cells = <String, dynamic>{
        for (final row in sourceRows) ...Map<String, dynamic>.from(row as Map),
      };
      expect(cells['A1'], '2026년 가을학기 강의시간표_20260826');
      final old = read(
        'work/university-research/catalog-r/kaist/kaist-main-2026-2.aic-dated-planned-v1.json',
      );
      final raw = read('${root}kaist-main-2026-2.nqe-ug-planned-v2.json');
      final rows = raw['courses'] as List;
      final dataset = UniversityDataset.fromJson(raw);
      expect(raw['completionClaim'], false);
      expect(raw['researchOnly'], true);
      expect(rows.first, (old['courses'] as List).first);
      expect(rows, hasLength(12));
      var dates = 0, newDates = 0;
      final codes = <String>{};
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i] as Map;
        final course = dataset.courses[i];
        dates += course.meetings.length;
        expect(course.hasSchedulableMeetings, true);
        expect(course.campus, 'main');
        if (i == 0) {
          expect(course.code, 'AIC.20000');
          expect(course.meetings, hasLength(10));
          continue;
        }
        newDates += course.meetings.length;
        final meta = row['metadata'] as Map;
        final original = meta['originalEducationalFields'] as Map;
        final sourceRow = original['sourceRow'];
        expect(sourceRow, inInclusiveRange(27, 37));
        expect(original['nativeCode'], cells['B$sourceRow']);
        expect(original['nativeClassification'], cells['A$sourceRow']);
        expect(original['nativeTitle'], cells['D$sourceRow']);
        expect(original['nativeProfessor'], cells['K$sourceRow']);
        expect(original['nativeRemarks'], cells['L$sourceRow']);
        expect(course.code, original['nativeCode']);
        expect(course.sourceClassification, original['nativeClassification']);
        expect(
          course.professor,
          (original['nativeProfessor'] as String)
              .split('\n')
              .where((s) => s.trim().isNotEmpty)
              .map((s) => s.trim())
              .join(' / '),
        );
        expect(course.section, isEmpty);
        expect(row['credits'], isNull);
        expect(meta['currentActiveStatusVerified'], false);
        expect(meta['actualAttendanceConfirmed'], false);
        expect(meta['nativeSection'], isNull);
        expect(meta['publishedEnrollmentNumber'], isNull);
        codes.add(course.code);
        final grid = meta['sourceGridEvidence'] as List;
        final expected = expectedGrid[course.code]!;
        expect(grid, hasLength(2));
        final spans = <(int, int, int, String)>[];
        for (var k = 0; k < grid.length; k++) {
          final g = grid[k] as Map;
          final pair = expected[k];
          expect(g['topLeftCell'], pair.$1);
          expect(g['mergedRange'], pair.$2);
          expect(g['nativeText'], cells[pair.$1]);
          final range = pair.$2.split(':');
          final startRow = RegExp(r'\d+$').firstMatch(range.first)![0]!;
          final endRow = RegExp(r'\d+$').firstMatch(range.last)![0]!;
          final column = RegExp(r'^[A-Z]+').firstMatch(pair.$1)![0]!;
          final startClock = cells['A$startRow'] as String;
          final endClock = cells['A$endRow'] as String;
          final room = cells['${column}3'] as String;
          expect(g['nativeStartClock'], startClock);
          expect(g['nativeEndClock'], endClock);
          expect(g['nativeRoom'], room);
          final start = minute(startClock.split('-').first);
          final end = minute(endClock.split('-').last);
          spans.add((pair.$3, start, end, room.replaceAll('\n', ' ')));
        }
        final expectedDates = <String>{};
        for (
          var d = DateTime(2026, 8, 31);
          !d.isAfter(DateTime(2026, 12, 18));
          d = d.add(const Duration(days: 1))
        ) {
          final date =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          if ((!d.isBefore(DateTime(2026, 10, 19)) &&
                  !d.isAfter(DateTime(2026, 10, 23))) ||
              !d.isBefore(DateTime(2026, 12, 14)) ||
              [
                '2026-09-24',
                '2026-09-25',
                '2026-09-26',
                '2026-10-03',
                '2026-10-05',
                '2026-10-09',
              ].contains(date)) {
            continue;
          }
          for (final span in spans) {
            if (span.$1 == d.weekday) {
              expectedDates.add(
                '$date|${span.$1}|${span.$2}|${span.$3}|${span.$4}',
              );
            }
          }
        }
        final actual = course.meetings
            .map(
              (m) =>
                  '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
            )
            .toSet();
        expect(actual, expectedDates, reason: course.code);
        expect(actual.length, course.meetings.length);
        expect(
          (row['schedules'] as List).every(
            (dynamic m) => !(m as Map).containsKey('deliveryMode'),
          ),
          true,
        );
        if (course.code == 'NQE40002') {
          expect(spans, contains((4, 960, 1320, 'Doosan (4401)')));
          expect(cells['A23'], '19:00-22:00');
          expect(
            course.meetings
                .where((m) => m.weekday == 4)
                .every(
                  (m) => m.originalEndMinute - m.originalStartMinute == 360,
                ),
            true,
          );
        }
      }
      expect(codes, expectedGrid.keys.toSet());
      expect(newDates, 296);
      expect(dates, 306);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = dataset.courses
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
        expect(restored, hasLength(12));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, prior.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            prior.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
