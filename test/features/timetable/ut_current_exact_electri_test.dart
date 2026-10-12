import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const folder =
    'work/university-research/catalog-c/ut-current-electri-exact-75-block-v2-20261009';
Map<String, dynamic> read(String name) {
  final actual = '$folder/$name';
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  test(
    'UT current28 exact undergraduate75 blocks and184 literal dates; old29whole',
    () {
      final raw = read('ut-unknown-2026-2.electri75-v2.json');
      final prior = read('prior-current-29-184-baseline.json');
      final proof = read(
        'independent-exact-grid-clock-literal-date-proof.json',
      );
      expect(
        sha256
            .convert(
              File(
                '$folder/current-2026-2-electri-original.pdf',
              ).readAsBytesSync(),
            )
            .toString(),
        '1609eae5a48fa784614ab188a12cfc35336f9903dacf59ee4d00d62fc4d28f9a',
      );
      expect(proof['sourceCurrentTitle'], '2026학년도 제2학기 강의시간표');
      expect(raw['completionClaim'], false);
      expect(raw['researchOnly'], true);
      final headers = read(
        'independent-source-clock-column-and-grade-headers.json',
      );
      final rows = raw['courses'] as List;
      expect(rows, hasLength(57));
      expect(rows.take(29).toList(), prior['courses']);
      final pp = {
        for (final p in proof['proofs'] as List) (p as Map)['sourceId']: p,
      };
      expect(pp, hasLength(28));
      const clocks = {
        'A1': [540, 615],
        'A2': [630, 705],
        'A4': [810, 885],
        'A5': [900, 975],
        'A6': [990, 1065],
      };
      var newDates = 0;
      for (final item in rows.skip(29)) {
        final row = item as Map;
        final p = pp[row['sourceId']] as Map;
        final cell = row['sourceEducationCell'] as Map;
        expect(cell, p['nativeEducation']);
        expect(row['courseCode'], '');
        expect(row['section'], '');
        expect(row['credits'], null);
        expect(row['classification'], '');
        expect(row['campus'], 'unknown');
        final lines = (cell['educationalBlockText'] as String).split('\n');
        expect(row['courseName'], lines.take(lines.length - 2).join());
        expect(row['professor'], lines[lines.length - 2]);
        expect(row['sourceClassroom'], lines.last);
        expect(cell['nativeCodePublished'], false);
        expect(cell['nativeSectionPublished'], false);
        expect(cell['modeInferredFromColor'], false);
        final col = cell['nativeColumnIndex'] as int;
        expect([8, 13, 18, 23, 28].contains(col), false);
        final weekday = (col - 4) ~/ 5 + 1;
        expect(cell['nativeWeekday'], weekday);
        expect(cell['nativeStudyColumn'], '${(col - 4) % 5 + 1}');
        final clock = clocks[cell['native75Period']]!;
        final originalClock =
            (headers['native75ClockColumn'][cell['native75Period']]['exactOriginalClockColumnText']
                    as String)
                .split('\n');
        expect(originalClock.first, cell['native75Period']);
        final digits = RegExp(
          r'\d+',
        ).allMatches(originalClock.last).map((m) => int.parse(m[0]!)).toList();
        expect(clock, [digits[0] * 60 + digits[1], digits[2] * 60 + digits[3]]);
        expect(
          headers['nativeStudyColumnHeader'][col],
          cell['nativeStudyColumn'],
        );
        expect(p['expectedStartMinute'], clock.first);
        expect(p['expectedEndMinute'], clock.last);
        final meetings = row['schedules'] as List;
        expect(meetings.map((m) => m['date']).toList(), p['literalDates']);
        for (final m in meetings) {
          expect(DateTime.parse(m['date']).weekday, weekday);
          expect(m['weekday'], weekday);
          expect(m['startMinute'], clock.first);
          expect(m['endMinute'], clock.last);
          expect(m['classroom'], lines.last);
          expect(m.containsKey('deliveryMode'), false);
          expect(m['date'].compareTo('2026-09-01') >= 0, true);
          expect(m['date'].compareTo('2026-10-19') <= 0, true);
          expect(
            [
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
            ].contains(m['date']),
            false,
          );
          newDates++;
        }
      }
      expect(newDates, 184);
      final dataset = UniversityDataset.fromJson(raw);
      expect(
        dataset.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(57),
      );
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        368,
      );
    },
  );
  test(
    'UT full57/368 allthree user modes and entire Drive JSON restoration',
    () {
      final dataset = UniversityDataset.fromJson(
        read('ut-unknown-2026-2.electri75-v2.json'),
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in dataset.courses) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true);
          expect(t.defaultMode, mode);
          for (final m in t.meetings) {
            expect(t.modeOn(m, DateTime.parse(m.date!)), mode);
          }
          final key = timetableCourseSyncKey(t);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        expect(values, hasLength(57));
        final doc = TimetableSyncDocument.records(courses: values);
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), doc.toJson());
        for (final e in values.entries) {
          expect(restored.courses[e.key]!.value, e.value.value);
        }
        final classes = restored.materializeClasses();
        expect(classes, hasLength(57));
        expect(classes.map((c) => c.sourceId).toSet(), hasLength(57));
        expect(classes.fold<int>(0, (n, c) => n + c.meetings.length), 368);
        for (final c in classes) {
          expect(c.isValid, true);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
