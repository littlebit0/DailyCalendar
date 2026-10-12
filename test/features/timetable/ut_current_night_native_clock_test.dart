import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const folder =
    'work/university-research/catalog-c/ut-current-night-own-50-axis-v8-20261009';
dynamic read(String name) {
  final actual = name == 'ut-unknown-2026-2.current-night-own-50-v8.json'
      ? 'assets/timetable/ut-unknown-2026-2.json'
      : '$folder/$name';
  final data = jsonDecode(File(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  test(
    'UT prior61 whole761 deep; nine exact night50 native blocks and314 literal slots',
    () {
      final raw = read('ut-unknown-2026-2.current-night-own-50-v8.json');
      final prior = read('prior-v6-frozen-61-761-baseline.json');
      final proof = read(
        'independent-night-50-native-axis-and-literal-dates-proof.json',
      );
      final rows = raw['courses'] as List;
      expect(rows, hasLength(70));
      expect(rows.take(61).toList(), prior['courses']);
      expect(
        (prior['courses'] as List).fold<int>(
          0,
          (n, c) => n + (c['schedules'] as List).length,
        ),
        761,
      );
      for (final e in (proof['sourceInputsSHA256'] as Map).entries) {
        expect(
          sha256.convert(File(e.key as String).readAsBytesSync()).toString(),
          e.value,
        );
      }
      final axes = {
        for (final a in proof['night50Axis'] as List) a['nativeNightPeriod']: a,
      };
      expect(axes, hasLength(6));
      expect(axes[1]['exactClockText'], contains('18:30~19:20'));
      expect(axes[6]['exactClockText'], contains('23:05~23:55'));
      var added = 0;
      for (final p in proof['proofs'] as List) {
        final row = rows.singleWhere((r) => r['sourceId'] == p['sourceId']);
        final cell = row['sourceEducationCell'];
        final original = p['originalEducationalCells'] as List;
        expect(cell['originalEducationalCells'], original);
        expect(cell['educationalBlockText'], p['wholeOriginalBlockText']);
        expect(row['courseName'], p['literalTitle']);
        expect(row['professor'], p['literalProfessor']);
        expect(row['sourceClassroom'], p['literalClassroom']);
        expect(
          original.singleWhere((c) => c['row'] == p['professorRow'])['text'],
          row['professor'],
        );
        expect(
          original.singleWhere((c) => c['row'] == p['classroomRow'])['text'],
          row['sourceClassroom'],
        );
        expect(row['courseCode'], '');
        expect(row['section'], '');
        expect(row['campus'], 'unknown');
        expect(cell['modeInferredFromColor'], false);
        final periods = p['nativeNightPeriods'] as List;
        final column = p['nativeColumnIndex'] as int;
        final weekday = (column - 4) ~/ 5 + 1;
        expect(weekday, p['nativeWeekday']);
        expect((column - 4) % 5 + 1, p['nativeStudyGrade']);
        expect(p['nativeStudyGrade'], lessThanOrEqualTo(4));
        final literalDates = p['literalDates'] as List;
        final independentlyCalculatedDates = <String>[];
        const holidays = {
          '2026-09-24',
          '2026-09-25',
          '2026-09-26',
          '2026-10-05',
          '2026-10-09',
        };
        for (
          var d = DateTime(2026, 9, 1);
          !d.isAfter(DateTime(2026, 12, 7));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (d.weekday == weekday &&
              !holidays.contains(date) &&
              (d.isBefore(DateTime(2026, 10, 20)) ||
                  d.isAfter(DateTime(2026, 10, 26)))) {
            independentlyCalculatedDates.add(date);
          }
        }
        expect(literalDates, independentlyCalculatedDates);
        final expected = <Map<String, dynamic>>[];
        for (final date in literalDates) {
          for (final n in periods) {
            final axis = axes[n];
            final hh = RegExp(r'\d+')
                .allMatches((axis['exactClockText'] as String).split('\n').last)
                .map((m) => int.parse(m[0]!))
                .toList();
            final start = hh[0] * 60 + hh[1];
            final end = hh[2] * 60 + hh[3];
            expect(end - start, 50);
            expected.add({
              'date': date,
              'weekday': weekday,
              'startMinute': start,
              'endMinute': end,
              'classroom': p['literalClassroom'],
              'sourcePage': 1,
              'sourceColumn': column,
              'nativeNightPeriod': n,
              'reservationRangeOnly': true,
            });
          }
        }
        expect(row['schedules'], expected);
        expect(row['schedules'], p['expectedMeetings']);
        expect(
          (row['schedules'] as List).every(
            (s) => !s.containsKey('deliveryMode'),
          ),
          true,
        );
        added += expected.length;
      }
      expect(added, 314);
      final wedLower = rows.singleWhere(
        (r) => r['sourceId'] == 'ut-document290793-p1-night4-c16',
      );
      expect(wedLower['sourceEducationCell']['native50Periods'], [4, 5]);
      final capstone = rows.singleWhere(
        (r) => r['sourceId'] == 'ut-document290793-p1-night4-c27',
      );
      expect(capstone['courseName'], '캡스돈디자인II');
      expect(raw['completionClaim'], false);
    },
  );

  test(
    'UT full70/1075 allthree chosenmodes andcomplete Drive JSON restoration',
    () {
      final dataset = UniversityDataset.fromJson(
        read('ut-unknown-2026-2.current-night-own-50-v8.json'),
      );
      expect(dataset.courses, hasLength(70));
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        1075,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final course in dataset.courses) {
          final t = course.toTimetable(id: course.sourceId, mode: mode);
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
        expect(values, hasLength(70));
        final document = TimetableSyncDocument.records(courses: values);
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), document.toJson());
        for (final entry in values.entries) {
          expect(restored.courses[entry.key]!.value, entry.value.value);
        }
        final classes = restored.materializeClasses();
        expect(classes, hasLength(70));
        expect(classes.map((c) => c.sourceId).toSet(), hasLength(70));
        expect(classes.fold<int>(0, (n, c) => n + c.meetings.length), 1075);
        for (final c in classes) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
