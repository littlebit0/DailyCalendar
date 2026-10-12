import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-c/jnue-current-20261008';
Map<String, dynamic> read(String f) =>
    jsonDecode(File('$directory/$f').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  final audit = read('reservation-audit.json');
  final raw = read(audit['candidate']['file']);
  final courses = UniversityDataset.fromJson(raw).courses;
  final source = read('source-educational-grid.json');
  test(
    'Original public grid, empty official codes, native study classes and reservation-only clocks',
    () {
      expect(
        sha256
            .convert(
              File(
                '$directory/${audit['candidate']['file']}',
              ).readAsBytesSync(),
            )
            .toString(),
        audit['candidate']['sha256'],
      );
      expect(courses, hasLength(380));
      final ids = <String>{};
      final byGrade = {for (final s in source['sheets']) s['grade']: s};
      var total = 0;
      for (final c in raw['courses']) {
        expect(ids.add(c['sourceId']), true);
        expect(c['courseCode'], '');
        expect(c['section'], '');
        expect(c['creditsPublished'], false);
        expect(c['classification'], '');
        expect(c['campus'], 'unknown');
        final grade = (c['departments'][0] as String).split(' ').first;
        final sheet = byGrade[grade];
        for (final r in c['publicEducationCells']) {
          final originals = (sheet['educationCells'] as List)
              .where((e) => e['cell'] == r['cell'])
              .toList();
          expect(originals, hasLength(1));
          final e = originals.single;
          expect(r['text'], e['text']);
          expect(c['courseName'], e['text']);
          expect(r['teacherRoomText'], e['teacherRoomText']);
          expect(r['merge'], '');
          expect(r['nativeStudyClass'], e['nativeStudyClass']);
          expect(c['nativeStudyClass'], e['nativeStudyClass']);
          final teacherRoom = RegExp(
            r'^(.+?)\[([^\[\]]+)\]$',
          ).firstMatch(r['teacherRoomText']);
          if (teacherRoom != null) {
            expect(r['professor'], teacherRoom[1]!.trim());
            expect(r['room'], teacherRoom[2]!.trim());
          } else {
            expect(r['room'], '');
            expect(r['professor'], r['teacherRoomText']);
          }
          expect(
            r['weekday'],
            (int.parse(RegExp(r'\d+').firstMatch(r['cell'])![0]!) - 5) ~/ 22 +
                1,
          );
        }
        if ((c['schedules'] as List).isEmpty) {
          continue;
        }
        expect(grade, '1학년');
        expect(c['remarks'], contains('휴게·실제 강의 종료 시각은 미확인'));
        final expected = <Map<String, dynamic>>[];
        for (
          var d = DateTime(2026, 9, 22);
          !d.isAfter(DateTime(2026, 12, 4));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if ((audit['excludedDates'] as Map).containsKey(date)) {
            continue;
          }
          for (final r in c['publicEducationCells']) {
            if (r['weekday'] != d.weekday) {
              continue;
            }
            final clockCell = 'P${5 + 2 * ((r['period'] as int) - 1)}';
            final label =
                byGrade['1학년']['publishedClockLabels'][clockCell] as String;
            final numbers = RegExp(
              r'\d+',
            ).allMatches(label).map((m) => int.parse(m[0]!) * 60).toList();
            expected.add({
              'date': date,
              'weekday': d.weekday,
              'startMinute': numbers[0],
              'endMinute': numbers[1],
              'classroom': r['room'],
              'sourceCell': r['cell'],
              'sourceClockCell': clockCell,
              'reservationRangeOnly': true,
            });
          }
        }
        expect(c['schedules'], expected);
        total += expected.length;
      }
      expect(total, 1833);
      expect(raw['sourceReservationRangeOnly'], true);
      final events = read('calendar-educational-dates.json')['events'] as List;
      expect(
        events.any(
          (e) => e['start'] == '2026-12-07' && e['title'] == '2학기 보강주간',
        ),
        true,
      );
      expect(
        events.any((e) => e['start'] == '2026-12-14' && e['title'] == '학기말시험'),
        true,
      );
      expect(
        events.any(
          (e) => e['start'] == '2026-10-12' && e['title'] == '2학년 참관실습',
        ),
        true,
      );
      expect(audit['wholeCompletionClaim'], false);
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'Actual model and 1833 complete reservation plans full Drive ${mode.name}',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.note, c.remarks);
          for (final m in saved.meetings) {
            count++;
            expect(saved.modeOn(m, m.teachingDate!), mode);
            expect(saved.period!.contains(m.teachingDate!), true);
            expect(m.endMinute - m.startMinute, 60);
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(96));
        expect(count, 1833);
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(96));
        for (final c in restored.materializeClasses()) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      },
    );
  }
}
