import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-c/kmou-current-20261008';
Map<String, dynamic> read(String n) =>
    jsonDecode(fixtureFile('$directory/$n').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  final audit = read('partial-audit.json');
  final raw = read(audit['candidate']['file']);
  final model = UniversityDataset.fromJson(raw);
  test(
    '13 exact educational source cells and 179 current clock/date/room reservations',
    () {
      expect(
        sha256
            .convert(
              fixtureFile(
                '$directory/${audit['candidate']['file']}',
              ).readAsBytesSync(),
            )
            .toString(),
        audit['candidate']['sha256'],
      );
      expect(model.courses, hasLength(13));
      final source = read('source-educational-tables.json');
      final closure = read('closure-education.json');
      expect(closure['courses'], hasLength(59));
      expect(
        read('calendar-operating-education.json')['freshByteEqualPrior'],
        true,
      );
      final ids = <String>{};
      var total = 0;
      for (final c in raw['courses']) {
        expect(ids.add(c['sourceId']), true);
        expect(c['courseCode'], '');
        expect(c['section'], '');
        expect(c['credits'], null);
        expect(c['classification'], '');
        expect(c['campus'], 'unknown');
        expect(c['closureTitleMatches'], isEmpty);
        final expected = <Map<String, dynamic>>[];
        for (final cell in c['publicEducationCells']) {
          final table = source['tables'][cell['table']];
          final text = table[cell['row']][cell['column']] as String;
          expect(cell['text'], text);
          expect(cell['clockText'], table[cell['row']][0]);
          expect(cell['weekday'], cell['column']);
          expect(cell['period'], cell['row']);
          final lines = text.split('\n');
          final continuation = lines[lines.length - 2] == '로미정';
          expect(
            c['courseName'],
            '${lines.take(lines.length - 2).join()}${continuation ? '로' : ''}',
          );
          expect(
            c['professor'],
            continuation ? '미정' : lines[lines.length - 2].trim(),
          );
          expect(cell['room'], lines.last);
        }
        for (
          var d = DateTime(2026, 9, 15);
          !d.isAfter(DateTime(2026, 10, 19));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if ((audit['excludedDates'] as Map).containsKey(date)) {
            continue;
          }
          for (final cell in c['publicEducationCells']) {
            if (d.weekday != cell['weekday']) {
              continue;
            }
            final n = RegExp(r'\d+')
                .allMatches(cell['clockText'])
                .skip(1)
                .map((m) => int.parse(m[0]!))
                .toList();
            final afternoon = cell['period'] >= 5 ? 720 : 0;
            expected.add({
              'date': date,
              'weekday': d.weekday,
              'startMinute': n[0] * 60 + n[1] + afternoon,
              'endMinute': n[2] * 60 + n[3] + afternoon,
              'classroom': cell['room'],
              'sourceTable': cell['table'],
              'sourceRow': cell['row'],
              'sourceColumn': cell['column'],
            });
          }
        }
        expect(c['schedules'], expected);
        expect(c['remarks'], contains('최종 시간·장소'));
        total += expected.length;
      }
      expect(total, 179);
      expect(audit['completionClaim'], false);
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test('Actual 13 classes 179 plans full Drive ${mode.name}', () {
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
        for (var index = 0; index < saved.meetings.length; index++) {
          final m = saved.meetings[index];
          final plan = published[index];
          expect(m.date, plan['date']);
          expect(m.weekday, plan['weekday']);
          expect(m.originalStartMinute, plan['startMinute']);
          expect(m.originalEndMinute, plan['endMinute']);
          expect(m.classroom, plan['classroom']);
          count++;
          expect(saved.modeOn(m, m.teachingDate!), mode);
          expect(saved.period!.contains(m.teachingDate!), true);
          expect(m.originalEndMinute - m.originalStartMinute, 50);
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
      expect(count, 179);
      expect(values, hasLength(13));
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final json = jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
      final restored = TimetableSyncDocument.fromJson(json);
      expect(restored.materializeClasses(), hasLength(13));
      for (final c in restored.materializeClasses()) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        expect(c.isValid, true);
      }
    });
  }
}
