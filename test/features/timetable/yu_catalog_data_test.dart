import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'YU regular source date limits and 30 minute native slots survive three full Drive documents',
    () {
      const root = 'work/university-research/catalog-r/yu/';
      final proof =
          jsonDecode(
                fixtureFile(
                  '${root}yu-current-regular-roomchange-proof-v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final raw =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/yu-unknown-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final dataset = UniversityDataset.fromJson(raw);
      int minute(String s) {
        final p = s.split(':');
        return int.parse(p[0]) * 60 + int.parse(p[1]);
      }

      final clocks = {
        for (final m in RegExp(
          r'([1-9][AB])(\d\d:\d\d)\s*-\s*(\d\d:\d\d)',
        ).allMatches(proof['independentNativeClockText']))
          m[1]!: [minute(m[2]!), minute(m[3]!)],
      };
      expect(clocks, hasLength(18));
      expect(clocks['1A'], [540, 570]);
      expect(
        proof['nativeUndergraduateCalendar'],
        contains('10. 20.(화) ~ 10. 26.(월)'),
      );
      expect(
        proof['nativeUndergraduateCalendar'],
        contains('9. 24.(목) 추석연휴일 → 12. 8.(화)'),
      );
      expect(raw['researchOnly'], isFalse);
      expect(raw['completionClaim'], isFalse);
      expect(dataset.courses, hasLength(60));
      expect(proof['nativeRows'], hasLength(62));
      var total = 0;
      for (var i = 0; i < dataset.courses.length; i++) {
        final c = dataset.courses[i];
        final row = (raw['courses'] as List)[i] as Map;
        final originals = row['metadata']['originalEducationalRecords'] as List;
        for (final x in originals) {
          expect(
            x,
            (proof['nativeRows'] as List).singleWhere(
              (dynamic n) => n['excelRow'] == x['excelRow'],
            ),
          );
        }
        final native = originals.first['values'] as Map;
        expect(c.code, isEmpty);
        expect(c.section, isEmpty);
        expect(c.campus, 'unknown');
        expect(c.title, native['교과목명']);
        expect(c.professor, native['담당교수']);
        expect(c.sourceClassification, native['과정구분']);
        expect(c.sourceSchedule, native['강의시간']);
        expect(c.credits, isNull);
        expect(
          c.departments.toSet(),
          originals.map((dynamic x) => x['values']['학부(과)명']).toSet(),
        );
        final room = native['변경 후 강의실'] == '변경 없음'
            ? (native['변경 전 강의실'] as String).trim()
            : native['변경 후 강의실'];
        expect(c.sourceClassroom, room);
        final closed = (proof['closureProof']['nativeRows'] as List).any(
          (dynamic x) => x['values']['수강번호'] == native['수강번호'],
        );
        expect(row['metadata']['publishedClosureMatch'], closed);
        if (closed) {
          expect(native['수강번호'], '0263');
          expect(c.hasSchedulableMeetings, isFalse);
          continue;
        }
        final period = RegExp(
          r'^2026\.(\d\d)\.(\d\d)~(\d\d)\.(\d\d)$',
        ).firstMatch(native['변경 기간'])!;
        final start = DateTime(
          2026,
          int.parse(period[1]!),
          int.parse(period[2]!),
        );
        final expected = <String>{};
        for (
          var d = start;
          !d.isAfter(DateTime(2026, 12, 7));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (['2026-10-03', '2026-10-05', '2026-10-09'].contains(date) ||
              (!d.isBefore(DateTime(2026, 10, 20)) &&
                  !d.isAfter(DateTime(2026, 10, 26)))) {
            continue;
          }
          for (final segment in (native['강의시간'] as String).split(' ')) {
            final m = RegExp(
              r'^([월화수목금])((?:[1-9][AB],?)+)$',
            ).firstMatch(segment)!;
            if (d.weekday != '월화수목금'.indexOf(m[1]!) + 1) {
              continue;
            }
            for (final label in m[2]!.split(',')) {
              final clock = clocks[label]!;
              expected.add('$date/${d.weekday}/${clock[0]}/${clock[1]}/$room');
            }
          }
        }
        final actual = {
          for (final m in c.meetings)
            '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
        };
        expect(actual, expected);
        expect(actual, hasLength(c.meetings.length));
        total += c.meetings.length;
        expect(
          (row['schedules'] as List).every(
            (dynamic m) => !(m as Map).containsKey('deliveryMode'),
          ),
          isTrue,
        );
        expect(row['metadata']['actualAttendanceConfirmed'], isFalse);
      }
      expect(total, 1890);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = dataset.courses
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(after, hasLength(59));
        final originals = {for (final c in before) c.sourceId: c};
        for (final c in after) {
          final prior = originals[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, prior.note);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
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
