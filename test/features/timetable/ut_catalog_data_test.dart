import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-c/ut-current-20261008';
Map<String, dynamic> read(String n) =>
    jsonDecode(
          File(
            '$directory/$n',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
void main() {
  final audit = read('partial-audit.json');
  final raw = read(audit['candidate']['file']);
  final model = UniversityDataset.fromJson(raw);
  test(
    '29 exact literal merged cells, native labels and 184 published range plans',
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
      expect(model.courses, hasLength(29));
      final source = read('biotech-original-educational-grid.json');
      final ids = <String>{};
      var count = 0;
      final calendar =
          read('calendar-educational-dates.json')['events'] as List;
      expect(
        calendar.any(
          (e) =>
              e['startDate'] == '2026-09-01' &&
              e['subject'] == '제2학기 개강일(학기개시일)',
        ),
        true,
      );
      expect(
        calendar.any(
          (e) => e['startDate'] == '2026-10-20' && e['subject'] == '중간고사 권장기간',
        ),
        true,
      );
      for (final c in raw['courses']) {
        expect(ids.add(c['sourceId']), true);
        expect(c['courseCode'], '');
        expect(c['section'], '');
        expect(c['credits'], null);
        expect(c['classification'], '');
        expect(c['campus'], 'unknown');
        expect(c['remarks'], contains('휴게·실제 강의 종료 시각은 미확인'));
        expect(c['nativeCampusScope'], contains('개별 강의 건물명 미공개'));
        final r = c['sourceEducationCell'];
        final row = r['row'] as int;
        final col = r['column'] as int;
        final text = source['values'][row][col] as String;
        expect(r['text'], text);
        final lines = text.split('\n');
        expect(c['courseName'], lines[0]);
        expect(c['professor'], lines[1]);
        expect(c['sourceClassroom'], lines[2]);
        expect(
          r['merge'],
          (source['merges'] as List).singleWhere(
            (m) => m[0] == row && m[2] == col,
          ),
        );
        expect(r['merge'][1] - row, 3);
        expect(r['publishedClockText'], source['values'][row][28]);
        expect(r['nativeStudyColumn'], source['values'][3][col].toString());
        final header = (source['merges'] as List).singleWhere(
          (m) => m[0] == 2 && m[1] == 3 && m[2] <= col && col < m[3],
        );
        final weekday =
            ['월', '화', '수', '목', '금'].indexOf(source['values'][2][header[2]]) +
            1;
        expect(r['weekday'], weekday);
        final clock = RegExp(r'\d+')
            .allMatches(r['publishedClockText'])
            .map((m) => int.parse(m[0]!))
            .toList();
        final expected = <Map<String, dynamic>>[];
        for (
          var d = DateTime(2026, 9, 1);
          !d.isAfter(DateTime(2026, 10, 19));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (d.weekday != weekday ||
              (audit['excludedDates'] as Map).containsKey(date)) {
            continue;
          }
          expected.add({
            'date': date,
            'weekday': weekday,
            'startMinute': clock[0] * 60 + clock[1],
            'endMinute': clock[2] * 60 + clock[3],
            'classroom': lines[2],
            'sourceRow': row,
            'sourceColumn': col,
            'sourceClockColumn': 28,
            'reservationRangeOnly': true,
          });
        }
        expect(c['schedules'], expected);
        count += expected.length;
      }
      expect(count, 184);
      expect(audit['completionClaim'], false);
      expect(audit['actualLectureEndVerified'], false);
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test('Actual 29 published ranges 184 plans full Drive ${mode.name}', () {
      final values = <String, TimetableSyncValue>{};
      var count = 0;
      for (final c in model.courses) {
        final saved = c.toTimetable(id: c.sourceId, mode: mode);
        expect(saved.isValid, true);
        expect(saved.note, c.remarks);
        final published =
            (raw['courses'] as List).singleWhere(
                  (x) => x['sourceId'] == c.sourceId,
                )['schedules']
                as List;
        expect(saved.meetings, hasLength(published.length));
        for (var i = 0; i < saved.meetings.length; i++) {
          final m = saved.meetings[i];
          final p = published[i];
          count++;
          expect(m.date, p['date']);
          expect(m.weekday, p['weekday']);
          expect(m.originalStartMinute, p['startMinute']);
          expect(m.originalEndMinute, p['endMinute']);
          expect(m.classroom, p['classroom']);
          expect(m.originalEndMinute - m.originalStartMinute, 90);
          expect(saved.modeOn(m, m.teachingDate!), mode);
          expect(saved.period!.contains(m.teachingDate!), true);
        }
        final key = timetableCourseSyncKey(saved);
        expect(values.containsKey(key), false);
        values[key] = TimetableSyncValue(
          {...saved.toJson(), 'id': key},
          DateTime.utc(2026, 10, 8),
          'research',
        );
      }
      expect(count, 184);
      expect(values, hasLength(29));
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final json = jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
      final restored = TimetableSyncDocument.fromJson(json);
      expect(restored.materializeClasses(), hasLength(29));
      for (final c in restored.materializeClasses()) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        expect(c.isValid, true);
      }
    });
  }
}
