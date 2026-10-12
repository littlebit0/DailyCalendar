import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-c/chosun-current-final-future-review-20261009/';
  Map<String, dynamic> read(String path) {
    final actual = path;
    final data =
        jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
    if (data['courses'] is List) {
      data['researchOnly'] = false;
      for (final row in data['courses']) {
        if (row['metadata']?.containsKey('researchOnly') == true) {
          row['metadata']['researchOnly'] = false;
        }
      }
    }
    return data;
  }

  test(
    'current final native operation joins13 corrections;121 prior objects and64 nursing rows preserved',
    () {
      final raw = read(
        '${root}chosun-unknown-2026-2.current-final-future-source-review-candidate-v4.json',
      );
      final prior = read('${root}baseline-future-nurse135-frozen-v2.json');
      final proofs =
          jsonDecode(
                File(
                  '${root}current-final-native-operating-correction-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proofs, hasLength(13));
      expect(proofs.where((r) => r['priorScheduled'] == false), hasLength(11));
      final changed = {for (final p in proofs) p['sourceId']: p};
      final old = {for (final c in prior['courses'] as List) c['sourceId']: c};
      final source = read(
        '${root}current-final-educational-workbook-comparison.json',
      );
      expect(source['noticeDate'], '2026-09-01');
      expect(
        source['sourceSHA256'],
        '696656ef86d970c1a6c5c0b78bdbe69fcafc9b7b8c8acdd96d7db481a79b81ed',
      );
      final sheets = {for (final s in source['sheets'] as List) s['sheet']: s};
      final courses = raw['courses'] as List;
      expect(courses, hasLength(135));
      expect(courses.map((c) => c['sourceId']).toSet(), old.keys.toSet());
      expect(courses.sublist(71), (prior['courses'] as List).sublist(71));
      final own = read('${root}own-current-calendar-frozen.json');
      final events = own['educationalEvents'] as List;
      expect(
        events.any(
          (e) =>
              e['startDate'] == '2026-09-01' &&
              e['nativeTitle'] == '2학기 개강(2학기 개시)',
        ),
        true,
      );
      expect(
        events.any(
          (e) =>
              e['startDate'] == '2026-10-20' &&
              e['endDate'] == '2026-10-26' &&
              e['nativeTitle'] == '중간고사',
        ),
        true,
      );
      expect(
        events.any(
          (e) =>
              e['startDate'] == '2026-12-08' &&
              (e['nativeTitle'] as String).startsWith('[휴업일에 따른 수업일]'),
        ),
        true,
      );
      final holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-09-29',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (final c in courses) {
        final p = changed[c['sourceId']];
        if (p == null) {
          if ((c['sourceEducation'] as Map).containsKey(
            'currentFinalWorkbookMissing',
          )) {
            expect(c['schedules'], isEmpty);
            expect(
              c['sourceEducation']['currentFinalWorkbookMissing']['closedCourseConfirmed'],
              false,
            );
            final copy = jsonDecode(jsonEncode(c)) as Map<String, dynamic>;
            (copy['sourceEducation'] as Map).remove(
              'currentFinalWorkbookMissing',
            );
            expect(copy, old[c['sourceId']]);
          } else {
            expect(c, old[c['sourceId']]);
          }
          continue;
        }
        final original = old[c['sourceId']];
        expect(c['courseCode'], '');
        expect(c['section'], '');
        expect(c['credits'], isNull);
        expect(c['campus'], 'unknown');
        expect(
          c['sourceEducation']['nativePublicBlock'],
          original['sourceEducation']['nativePublicBlock'],
        );
        final current = c['sourceEducation']['currentFinalPublicBlock'];
        final sh = sheets[current['sheet']];
        expect(
          (sh['nativeHeadings'] as List).any(
            (h) => (h['literal'] as String).contains('2학기'),
          ),
          true,
        );
        final native = (sh['courseCells'] as List).singleWhere(
          (n) => n['cell'] == current['cell'],
        );
        expect(current, native);
        final lines = (native['nativeCellText'] as String).split('\n');
        final index = lines.indexWhere(
          (s) => RegExp(r'\d{5}-\d{2}').hasMatch(s),
        );
        expect(
          RegExp(r'\d{5}-\d{2}').firstMatch(lines[index])!.group(0),
          p['nativeReference'],
        );
        expect(lines[index + 1].trim(), c['professor']);
        expect(lines[index + 2].trim(), c['sourceClassroom']);
        expect(lines[index + 3].trim(), '대면');
        final day = ((native['minColumn'] as int) - 4) ~/ 6 + 1;
        expect(((native['maxColumn'] as int) - 4) ~/ 6 + 1, day);
        expect(
          (sh['weekdayHeaderCells'] as List).singleWhere(
            (h) => h['column'] == 4 + (day - 1) * 6,
          )['literal'],
          '월화수목금토'[day - 1],
        );
        final clocks = {for (final x in sh['clockRows'] as List) x['row']: x};
        int minute(String s) {
          final q = s.split(':').map(int.parse).toList();
          return q[0] * 60 + q[1];
        }

        final start = minute(
          (clocks[native['minRow']]['values'][2] as String).split('~').first,
        );
        final end = minute(
          (clocks[native['maxRow']]['values'][2] as String).split('~').last,
        );
        expect(day == 3 && start < 780 && end > 720, false);
        final expected = <Map<String, dynamic>>[];
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 7));
          date = date.add(const Duration(days: 1))
        ) {
          final ds = date.toIso8601String().substring(0, 10);
          if (date.weekday == day &&
              !holidays.contains(ds) &&
              !(ds.compareTo('2026-10-20') >= 0 &&
                  ds.compareTo('2026-10-26') <= 0)) {
            expected.add({
              'date': ds,
              'weekday': day,
              'startMinute': start,
              'endMinute': end,
              'classroom': c['sourceClassroom'],
            });
          }
        }
        expect(c['schedules'], expected);
        if (current['cell'] != p['oldCell']) {
          expect(c['departments'], [
            for (final g in sh['nativeStudentGroupCells'] as List)
              if ((g['column'] as int) >= (native['minColumn'] as int) &&
                  (g['column'] as int) <= (native['maxColumn'] as int))
                '${current['sheet']} 미래융합학부 / ${g['literal']}',
          ]);
          expect(day, 2);
          expect(start, 1080);
          expect(end, 1260);
        }
      }
    },
  );
  test(
    'actual73/851 full dated schedules survive userthree modes and whole Drive JSON',
    () {
      final raw = read(
        '${root}chosun-unknown-2026-2.current-final-future-source-review-candidate-v4.json',
      );
      final dataset = UniversityDataset.fromJson(raw);
      expect(dataset.courses, hasLength(135));
      final scheduled = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(scheduled, hasLength(73));
      expect(scheduled.fold<int>(0, (n, c) => n + c.meetings.length), 851);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(73));
        final expected = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            expected[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.meetings.every((m) => m.date != null), true);
        }
      }
    },
  );
}
