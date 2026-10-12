import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test(
    'SKU current native book, merged cells, clocks and all three Drive modes',
    () {
      const root = 'work/university-research/catalog-r/sku/';
      final proof =
          jsonDecode(
                File(
                  '${root}sku-current-native-education-proof-v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final native = {
        for (final row in proof['rows']) '${row['table']}/${row['row']}': row,
      };
      final originalTables = {
        for (final table in proof['originalCourseTables'])
          table['index']: table,
      };
      final clocks = proof['clocks'] as Map;
      final closed = {
        for (final row in proof['closureRows'])
          '${row['courseCode']}-${row['section']}',
      };
      expect(closed, hasLength(104));
      final scheduled = <UniversityCourse>[];
      final seen = <String>{};
      var rows = 0, slots = 0, closedRows = 0, seventyFive = 0, fifty = 0;
      for (final campus in ['main', 'unknown']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/sku-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        expect(dataset.universityId, 'sku');
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        for (var i = 0; i < dataset.courses.length; i++) {
          rows++;
          final course = dataset.courses[i];
          final row = (raw['courses'] as List)[i] as Map;
          final meta = row['metadata'] as Map;
          final original = meta['originalEducationalRow'] as Map;
          final key = '${original['table']}/${original['row']}';
          expect(original, native[key]);
          expect(seen.add(key), isTrue);
          final table = originalTables[original['table']] as Map;
          final cells = (table['cells'] as List)
              .where(
                (dynamic c) =>
                    c['row'] <= original['row'] &&
                    original['row'] < c['row'] + c['rowSpan'],
              )
              .toList();
          expect(meta['sourceMergedCells'], cells);
          final head = meta['nativeHeaders'] as Map;
          String source(String label) =>
              (original['cells'] as Map)[head.keys.firstWhere(
                    (dynamic k) => head[k] == label,
                  )]
                  as String;
          String compact(String text) => text.replaceAll(RegExp(r'\s+'), '');
          for (final entry in (original['cells'] as Map).entries) {
            final column = int.parse(entry.key as String);
            final sourceCell =
                cells.firstWhere(
                      (dynamic cell) =>
                          cell['col'] <= column &&
                          column < cell['col'] + cell['colSpan'],
                    )
                    as Map;
            expect(
              compact(entry.value as String),
              compact((sourceCell['paragraphs'] as List).join()),
            );
          }
          expect(course.code, compact(source('학수번호')));
          expect(course.section, compact(source('분반')));
          expect(course.title, source('교과목명').trim());
          expect(course.professor, source('담당교수').trim());
          expect(course.sourceClassification, meta['nativeClassification']);
          if (head.containsValue('이수구분')) {
            expect(course.sourceClassification, compact(source('이수구분')));
          } else if (original['table'] == 49) {
            expect(course.sourceClassification, isEmpty);
            expect(meta['nativeGrade'], isNotEmpty);
          }
          expect(course.sourceClassroom, source('강의실').trim());
          expect(meta['actualAttendanceConfirmed'], isFalse);
          expect(meta['currentWholePortalUpdatesVerified'], isFalse);
          expect(
            (row['schedules'] as List).every(
              (dynamic m) => !(m as Map).containsKey('deliveryMode'),
            ),
            isTrue,
          );
          if (closed.contains('${course.code}-${course.section}')) {
            closedRows++;
            expect(course.hasSchedulableMeetings, isFalse);
            expect(meta['closureMatched'], isTrue);
          }
          if (!course.hasSchedulableMeetings) continue;
          scheduled.add(course);
          expect(course.sourceRemarks, contains('공개 예약 계획, 실제 등교'));
          expect(course.sourceRemarks, contains('원문 교육 필드:'));
          if (campus == 'main') {
            expect(
              course.sourceClassroom.startsWith('혜-') ||
                  course.sourceClassroom.startsWith('혜인관'),
              isTrue,
            );
          } else {
            expect(course.sourceRemarks, contains('실제 캠퍼스는 미확인'));
          }
          final unique = <String>{};
          final expectedSpans = <String>{};
          for (final group in RegExp(
            r'([월화수목금토일]+)(\d+(?:\.\d+)*)',
          ).allMatches(compact(course.sourceSchedule))) {
            for (final day in group[1]!.split('')) {
              for (final period in group[2]!.split('.')) {
                final clock = clocks[period] as List;
                expectedSpans.add(
                  '${'월화수목금토일'.indexOf(day) + 1}/${clock[0]}/${clock[1]}',
                );
              }
            }
          }
          final actualSpans = <String>{};
          for (final meeting in course.meetings) {
            slots++;
            final day = DateTime.parse(meeting.date!);
            expect(day.weekday, meeting.weekday);
            expect(day.isBefore(DateTime(2026, 9, 1)), isFalse);
            expect(day.isAfter(DateTime(2026, 12, 7)), isFalse);
            expect(
              day.isBefore(DateTime(2026, 10, 20)) ||
                  day.isAfter(DateTime(2026, 10, 26)),
              isTrue,
            );
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
              '2026-10-23',
            ], isNot(contains(meeting.date)));
            expect(
              clocks.values.any(
                (dynamic clock) =>
                    clock[0] == meeting.originalStartMinute &&
                    clock[1] == meeting.originalEndMinute,
              ),
              isTrue,
            );
            final duration =
                meeting.originalEndMinute - meeting.originalStartMinute;
            if (duration == 75) seventyFive++;
            if (duration == 50) fifty++;
            expect(meeting.classroom, course.sourceClassroom);
            actualSpans.add(
              '${meeting.weekday}/${meeting.originalStartMinute}/${meeting.originalEndMinute}',
            );
            expect(
              unique.add(
                '${meeting.date}/${meeting.originalStartMinute}/${meeting.originalEndMinute}/${meeting.classroom}',
              ),
              isTrue,
            );
          }
          expect(actualSpans, expectedSpans);
        }
      }
      expect(rows, 1698);
      expect(seen, hasLength(1698));
      expect(closedRows, 104);
      expect(scheduled, hasLength(1369));
      expect(slots, 35816);
      expect(seventyFive, greaterThan(0));
      expect(fifty, greaterThan(0));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final before = {for (final c in classes) c.sourceId: c};
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(1369));
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, prior.note);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
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
