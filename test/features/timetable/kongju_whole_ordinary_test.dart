// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-r/kongju/current-whole-lecture-list-followup-20261008/';
  dynamic read(String name) =>
      jsonDecode(fixtureFile('$root$name').readAsStringSync());
  final source =
      read('current-whole-undergraduate-lecture-education.json')
          as Map<String, dynamic>;
  final baseline =
      read('baseline-cheonan65-frozen.json') as Map<String, dynamic>;
  for (final course in baseline['courses'] as List) {
    if (course['metadata']?.containsKey('researchOnly') == true) {
      course['metadata']['researchOnly'] = false;
    }
  }
  final datasets = [
    for (final campus in ['singwan', 'cheonan', 'yesan', 'unknown'])
      jsonDecode(
            fixtureFile(
              'work/university-research/resume-batch-20261010/before-projection/kongju-$campus-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
  ];
  final courses = datasets.expand((d) => d['courses'] as List).toList();
  final old = {for (final c in baseline['courses'] as List) c['sourceId']: c};
  final tables = source['educationalTables'] as List;
  String cell(List cells, int row, int col) {
    final hits = cells
        .where(
          (c) =>
              c['row'] <= row &&
              row < c['row'] + c['rowSpan'] &&
              c['col'] <= col &&
              col < c['col'] + c['colSpan'],
        )
        .toList();
    return hits.isEmpty ? '' : hits.last['text'] as String;
  }

  test(
    'Full original current undergraduate source2674 native/2820 educational rows and immutable prior65 union have no duplicate',
    () {
      final native = <String>{};
      var count = 0;
      for (final table in tables) {
        for (final c in table['cells'] as List) {
          if (c['col'] == 1 &&
              c['row'] > 0 &&
              RegExp(r'^\d{9}$').hasMatch(c['text'] as String)) {
            native.add(c['text'] as String);
            count++;
          }
        }
      }
      expect(count, 2820);
      expect(native, hasLength(2674));
      expect(courses, hasLength(2675));
      expect(courses.map((c) => c['sourceId']).toSet(), hasLength(2675));
      final wholeNative = <String>{};
      for (final c in courses) {
        final id = old.containsKey(c['sourceId'])
            ? '${c['courseCode']}${c['section']}'
            : c['courseCode'] as String;
        expect(wholeNative.add(id), true);
        if (old.containsKey(c['sourceId'])) {
          expect(c, old[c['sourceId']]);
        } else {
          expect(native, contains(id));
          expect(c['section'], isEmpty);
          final variants =
              c['sourceEducationalMetadata']['originalPublishedRowVariants']
                  as List;
          for (final r in variants) {
            final table = tables.singleWhere(
              (t) => t['sourceTable'] == r['sourceTable'],
            );
            final cells = table['cells'] as List;
            expect(cell(cells, r['sourceRow'] as int, 1), id);
            expect(cell(cells, r['sourceRow'] as int, 2), r['courseTitle']);
            final clockHeader = cells
                .where(
                  (z) =>
                      z['row'] == 0 && (z['text'] as String).contains('강의시간'),
                )
                .toList();
            if (clockHeader.isNotEmpty) {
              final col = clockHeader.single['col'] as int;
              expect(cell(cells, r['sourceRow'] as int, col), r['periodRaw']);
              final room = cell(cells, r['sourceRow'] as int, col + 1);
              expect(room == r['periodRaw'] ? '' : room, r['roomRaw']);
            }
          }
        }
      }
      expect(
        old.keys.where((id) => courses.any((c) => c['sourceId'] == id)),
        hasLength(65),
      );
      expect(
        (read('current-native-closures-education.json')['rows'] as List),
        hasLength(109),
      );
      final closed = {
        for (final c
            in read('current-native-closures-education.json')['rows'] as List)
          '${c['nativeCourseCode']}${c['nativeSection']}',
      };
      expect(
        old.values.where(
          (c) => closed.contains('${c['courseCode']}${c['section']}'),
        ),
        isEmpty,
      );
      expect(
        courses.where(
          (c) =>
              closed.contains(c['courseCode']) &&
              (c['schedules'] as List).isNotEmpty,
        ),
        isEmpty,
      );
    },
  );

  test(
    '1982 new plans37933 dates independently follow own actual clock0–9/current boundaries/exceptions and actual room',
    () {
      final clockTable = (source['clockAndCampusTables'] as List).singleWhere(
        (t) => t['sourceTable'] == 212,
      );
      final clocks = <int, List<int>>{};
      int minute(String s) {
        final p = s.split(':').map(int.parse).toList();
        return p[0] * 60 + p[1];
      }

      for (var row = 1; row <= 10; row++) {
        final period = int.parse(cell(clockTable['cells'] as List, row, 0));
        final time = RegExp(
          r'(\d{2}:\d{2})\s*～\s*(\d{2}:\d{2})',
        ).firstMatch(cell(clockTable['cells'] as List, row, 1))!;
        clocks[period] = [minute(time[1]!), minute(time[2]!)];
      }
      expect(clocks.keys.toSet(), {0, 1, 2, 3, 4, 5, 6, 7, 8, 9});
      final calendar = read('own-current-calendar-and-makeup-education.json');
      expect(calendar['events'], contains('09-01 (Tue) 2학기 개강'));
      expect(calendar['events'], contains('12-18 (Fri) 2학기 종강'));
      expect(
        calendar['events'],
        contains('10-20 (Tue) ~ 10-26 (Mon) 2학기 중간고사 기간'),
      );
      const holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      final newUsable = courses
          .where(
            (c) =>
                !old.containsKey(c['sourceId']) &&
                (c['schedules'] as List).isNotEmpty,
          )
          .toList();
      expect(newUsable, hasLength(1982));
      var total = 0;
      for (final c in newUsable) {
        final meta = c['sourceEducationalMetadata'];
        expect(meta['holdReasons'], isEmpty);
        expect(c['sourceClassroom'], isNotEmpty);
        final expected = <Map<String, dynamic>>[];
        final blocks = <List<int>>[];
        for (final m in RegExp(r'([월화수목금토일])([^월화수목금토일]*)').allMatches(
          (c['sourceSchedule'] as String).replaceAll(RegExp(r'\s'), ''),
        )) {
          final values = <int>{};
          for (final part in m[2]!.replaceAll('/', '').split(',')) {
            if (part.isEmpty) {
              continue;
            }
            if (part.contains('~') || part.contains('-')) {
              final range = part.split(RegExp('[-~]')).map(int.parse).toList();
              for (var x = range[0]; x <= range[1]; x++) {
                values.add(x);
              }
            } else {
              values.add(int.parse(part));
            }
          }
          final sorted = values.toList()..sort();
          final runs = <List<int>>[];
          for (final v in sorted) {
            if (runs.isEmpty || v != runs.last.last + 1) {
              runs.add([v]);
            } else {
              runs.last.add(v);
            }
          }
          for (final run in runs) {
            blocks.add([
              '월화수목금토일'.indexOf(m[1]!) + 1,
              clocks[run.first]![0],
              clocks[run.last]![1],
            ]);
          }
        }
        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 7));
          day = day.add(const Duration(days: 1))
        ) {
          final date =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          if (holidays.contains(date) ||
              (!day.isBefore(DateTime(2026, 10, 20)) &&
                  !day.isAfter(DateTime(2026, 10, 26)))) {
            continue;
          }
          for (final b in blocks) {
            if (day.weekday == b[0]) {
              expected.add({
                'date': date,
                'weekday': b[0],
                'startMinute': b[1],
                'endMinute': b[2],
                'classroom': c['sourceClassroom'],
              });
            }
          }
        }
        expect(c['schedules'], expected, reason: c['sourceId'] as String);
        total += expected.length;
        expect(c['remarks'], contains('실제 개별 출석일 확정 자료가 아닙니다'));
      }
      expect(total, 37933);
    },
  );

  test(
    'Whole2675 models/2004schedulable/38175meetings all3user modes complete Drive JSON preserve all dates and fields',
    () {
      final models = datasets
          .expand((d) => UniversityDataset.fromJson(d).courses)
          .toList();
      expect(models, hasLength(2675));
      final scheduled = models.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(2004));
      expect(
        scheduled.fold<int>(0, (sum, c) => sum + c.meetings.length),
        38175,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final payload = jsonEncode(doc.toJson());
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(payload) as Map<String, dynamic>,
        ).materializeClasses();
        final originals = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(2004));
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            originals[c.sourceId]!.toJson()..remove('id'),
          );
        }
      }
    },
  );
}
