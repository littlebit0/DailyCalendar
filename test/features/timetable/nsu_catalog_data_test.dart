import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory =
    'work/university-research/catalog-e/nsu-regular-partial-20261008';
Map<String, dynamic> read(String n) =>
    jsonDecode(
          fixtureFile(
            n == 'nsu-unknown-2026-2.regular-partial-20261008.json'
                ? 'work/university-research/catalog-e/nsu-two-images-semester-v2-20261009/baseline39-current-asset.json'
                : '$directory/$n',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
String normalized(String t) => t.replaceAll(RegExp(r'\s+'), '');
void main() {
  final audit = read('partial-audit.json');
  final raw = read(audit['candidate']['file']);
  final model = UniversityDataset.fromJson(raw);
  test(
    '39 native section metadata, independent PDF coordinates and 255 exact plans',
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
      expect(model.courses, hasLength(39));
      final sources =
          jsonDecode(
                fixtureFile(
                  '$directory/pdf-independent-coordinate-education.json',
                ).readAsStringSync(),
              )
              as List;
      final clock = read('nsu-clock-evidence.json')['periods'] as List;
      final guide = read('own-guide-clock-calendar-education.json');
      expect(guide['consortiumCalendarUsed'], false);
      expect(guide['pdfPageCount'], 47);
      expect(
        guide['educationalCalendarDirectExcerpts'],
        contains('16주13141516171819'),
      );
      for (final r in (guide['clockTable'] as List).skip(1)) {
        for (final offset in [0, 3]) {
          final period = int.parse(RegExp(r'\d+').firstMatch(r[offset])![0]!);
          final nums = RegExp(
            r'\d+',
          ).allMatches(r[offset + 1]).map((m) => int.parse(m[0]!)).toList();
          final published = clock.singleWhere((x) => x['period'] == period);
          expect(published['startMinutes'], nums[0] * 60 + nums[1]);
          expect(published['endMinutes'], nums[2] * 60 + nums[3]);
        }
      }
      final ids = <String>{};
      var count = 0;
      var held = 0;
      for (final c in raw['courses']) {
        expect(ids.add(c['sourceId']), true);
        expect(c['courseCode'], '');
        expect(c['section'], anyOf('01', '02'));
        expect(c['credits'], null);
        expect(c['classification'], '');
        expect(c['campus'], 'unknown');
        expect(c['closureExactTitleSectionTeacherMatches'], isEmpty);
        final department = (c['departments'][0] as String).split(' ').first;
        final source = sources.singleWhere(
          (x) => x['department'] == department,
        );
        final originalFile = fixtureFile(
          'work/university-research/catalog-e/nsu-current-20261008/${source['sourceFileName']}',
        );
        expect(
          sha256.convert(originalFile.readAsBytesSync()).toString(),
          source['sourceSHA256'],
        );
        for (final r in c['publicEducationCells']) {
          final e = (source['cells'] as List).singleWhere(
            (x) => x['row'] == r['row'] && x['column'] == r['column'],
          );
          expect(r, e);
          expect(normalized(r['text']), normalized(r['independentCropText']));
          expect(r['text'], source['tableRows'][r['row']][r['column']]);
          final m = RegExp(
            r'^(.+?)-(\d{2})\(([^()]+)\)\((\d+)\)$',
          ).firstMatch(normalized(r['text']))!;
          expect(c['courseName'], m[1]);
          expect(c['section'], m[2]);
          expect(normalized(c['professor']), m[3]);
          expect(r['room'], m[4]);
          final cy = (r['pdfBbox'][1] + r['pdfBbox'][3]) / 2;
          for (final label in ['gradeHeader', 'weekdayHeader']) {
            expect(r[label]['bbox'][1] < cy && cy < r[label]['bbox'][3], true);
          }
          expect(
            (c['departments'][0] as String).endsWith(
              '${normalized(r['gradeHeader']['text'])}학년',
            ),
            true,
          );
          expect(
            r['weekday'],
            ['월', '화', '수', '목', '금'].indexWhere(
                  (x) => normalized(r['weekdayHeader']['text']).contains(x),
                ) +
                1,
          );
          final nums = RegExp(r'\d+')
              .allMatches(r['sourceClockText'])
              .map((m) => int.parse(m[0]!))
              .toList();
          final central = clock.singleWhere((x) => x['period'] == r['period']);
          expect(central['startMinutes'], nums[0] * 60 + nums[1]);
          expect(central['endMinutes'], nums[2] * 60 + nums[3]);
        }
        if ((c['schedules'] as List).isEmpty) {
          held++;
          expect(c['scheduleHoldReason'], contains('현장·임상·동승실습'));
          continue;
        }
        final expected = <Map<String, dynamic>>[];
        for (
          var d = DateTime(2026, 9, 11);
          !d.isAfter(DateTime(2026, 10, 2));
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
            final cl = clock.singleWhere((x) => x['period'] == r['period']);
            expected.add({
              'date': date,
              'weekday': d.weekday,
              'startMinute': cl['startMinutes'],
              'endMinute': cl['endMinutes'],
              'classroom': r['room'],
              'sourceRow': r['row'],
              'sourceColumn': r['column'],
            });
          }
        }
        expect(c['schedules'], expected);
        count += expected.length;
      }
      expect(held, 4);
      expect(count, 255);
      expect(audit['completionClaim'], false);
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test('Actual 35 sections 255 original plans full Drive ${mode.name}', () {
      final values = <String, TimetableSyncValue>{};
      var count = 0;
      for (final c in model.courses.where((c) => c.meetings.isNotEmpty)) {
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
          expect(m.originalEndMinute - m.originalStartMinute, anyOf(45, 50));
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
      expect(count, 255);
      expect(values, hasLength(35));
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final json = jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
      final restored = TimetableSyncDocument.fromJson(json);
      expect(restored.materializeClasses(), hasLength(35));
      for (final c in restored.materializeClasses()) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        expect(c.isValid, true);
      }
    });
  }

  // 수강신청 편람 교시표: 1~9교시 09:00~ 50분+쉬는 시간 10분(60분 슬롯),
  // 10~14교시 18:00~ 45분+5분(50분 슬롯). 쉬는 시간을 포함한 슬롯으로 저장하고
  // 같은 날 같은 강의실의 연속 교시는 한 구간으로 합친다.
  test(
    'packaged asset uses break-inclusive slots with merged consecutive periods',
    () {
      final asset =
          jsonDecode(
                File(
                  'assets/timetable/nsu-unknown-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final starts = [
        for (var i = 0; i < 9; i++) 540 + 60 * i,
        for (var i = 0; i < 5; i++) 1080 + 50 * i,
      ];
      final ends = [...starts.skip(1), 1330];
      var segments = 0;
      var minutes = 0;
      for (final c in asset['courses'] as List) {
        final byKey = <String, List<Map<String, dynamic>>>{};
        for (final s in c['schedules'] as List) {
          segments++;
          minutes += (s['endMinute'] as int) - (s['startMinute'] as int);
          final si = starts.indexOf(s['startMinute'] as int);
          expect(si, isNonNegative, reason: '${c['sourceId']} ${s['date']}');
          // 구간 끝은 어떤 슬롯의 끝(다음 교시 시작)이어야 한다.
          expect(ends, contains(s['endMinute']), reason: '${c['sourceId']}');
          byKey
              .putIfAbsent('${s['date']}|${s['classroom']}', () => [])
              .add(Map<String, dynamic>.from(s));
        }
        for (final list in byKey.values) {
          list.sort(
            (a, b) => (a['startMinute'] as int) - (b['startMinute'] as int),
          );
          for (var i = 1; i < list.length; i++) {
            expect(
              (list[i]['startMinute'] as int) -
                  (list[i - 1]['endMinute'] as int),
              greaterThanOrEqualTo(60),
              reason: '${c['sourceId']} ${list[i]['date']}',
            );
          }
        }
      }
      expect(segments, 1596);
      expect(minutes, 3933 * 60);
    },
  );
}
