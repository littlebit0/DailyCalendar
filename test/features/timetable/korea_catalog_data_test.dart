import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test(
    'KU current Sejong source clocks and dates preserve user modes through full Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/ku/';
      final proof =
          jsonDecode(
                fixtureFile(
                  '${root}ku-sejong-current-educational-proof-v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final cells = (proof['tables'] as List).single['cells'] as List;
      final sourceCells = {for (final c in cells) '${c['row']}/${c['col']}': c};
      final clockCells =
          proof['currentSejongClockGuide']['nativeTable']['cells'] as List;
      final clocks = <int, List<int>>{};
      expect(
        clockCells.where((dynamic c) => c['row'] == 3).single['paragraphs'],
        ['강의시간 (세종캠퍼스)'],
      );
      for (final c in clockCells.where(
        (dynamic c) => c['row'] >= 4 && c['col'] % 2 == 0,
      )) {
        final labels = c['paragraphs'] as List;
        if (labels.isEmpty) {
          continue;
        }
        final m = RegExp(r'^(\d+)교시$').firstMatch(labels.single as String);
        if (m == null) {
          continue;
        }
        final clock = clockCells
            .where(
              (dynamic x) => x['row'] == c['row'] && x['col'] == c['col'] + 1,
            )
            .single;
        final text = (clock['paragraphs'] as List).single as String;
        clocks[int.parse(m[1]!)] = text.split('-').map((s) {
          final parts = s.split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }).toList();
      }
      expect(clocks, hasLength(10));
      final calendar = (proof['calendars'] as List)
          .map((dynamic c) => c['nativeEducationalCalendarText'])
          .join(' ');
      expect(calendar, contains('09.01 2026학년도 제2학기 개강'));
      expect(calendar, contains('12.14 ~ 12.18 제2학기 기말고사'));
      expect(calendar, contains('12.18 제2학기 종강'));
      expect(calendar, contains('10.20 ~ 10.26 제2학기 중간고사'));
      expect(proof['midtermNotice']['nativeText'], contains('별도의 휴강 없이'));
      final raw =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-r/ku/current-public-sejong-followup-v8-20261009/baseline-sejong22-18-701.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      raw['researchOnly'] = false;
      final dataset = UniversityDataset.fromJson(raw);
      expect(raw['researchOnly'], isFalse);
      expect(raw['completionClaim'], isFalse);
      final scheduled = <UniversityCourse>[];
      var count = 0;
      for (var i = 0; i < dataset.courses.length; i++) {
        final c = dataset.courses[i];
        final r = (raw['courses'] as List)[i] as Map;
        final meta = r['metadata'] as Map;
        expect(c.code, isEmpty);
        expect(c.section, meta['nativeSection']);
        expect(c.sourceClassification, isEmpty);
        expect(c.campus, 'sejong');
        expect(meta['sourceCodePublished'], isFalse);
        expect(meta['actualAttendanceConfirmed'], isFalse);
        expect(meta['currentWholeClosureVerified'], isFalse);
        final native = meta['originalEducationalCells'] as List;
        for (final x in native) {
          final cell = x['nativeCell'] as Map;
          expect(cell, sourceCells['${cell['row']}/${cell['col']}']);
          expect(x['weekday'], cell['col']);
          expect(x['period'], cell['row']);
          expect(
            (cell['paragraphs'] as List).join(' '),
            contains(x['professor']),
          );
          expect(
            (cell['paragraphs'] as List).join(' '),
            contains(x['classroom']),
          );
        }
        if (!c.hasSchedulableMeetings) {
          expect(c.title, '창업과진로');
          expect(meta['heldReason'], contains('통합운영'));
          continue;
        }
        scheduled.add(c);
        final expected = <String>{};
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 13));
          date = date.add(const Duration(days: 1))
        ) {
          final day = date.toIso8601String().substring(0, 10);
          if ([
            '2026-09-24',
            '2026-09-25',
            '2026-09-26',
            '2026-10-03',
            '2026-10-05',
            '2026-10-09',
          ].contains(day)) {
            continue;
          }
          if (!date.isBefore(DateTime(2026, 10, 20)) &&
              !date.isAfter(DateTime(2026, 10, 26))) {
            continue;
          }
          for (final x in native.where(
            (dynamic x) => x['weekday'] == date.weekday,
          )) {
            final clock = clocks[x['period']]!;
            expected.add('$day/${clock[0]}/${clock[1]}/${x['classroom']}');
          }
        }
        final actual = <String>{};
        for (final m in c.meetings) {
          count++;
          final date = DateTime.parse(m.date!);
          expect(date.weekday, m.weekday);
          actual.add(
            '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
          );
          expect(
            (r['schedules'] as List).every(
              (dynamic x) => !(x as Map).containsKey('deliveryMode'),
            ),
            isTrue,
          );
        }
        expect(actual, expected);
        expect(actual, hasLength(c.meetings.length));
      }
      expect(dataset.courses, hasLength(22));
      expect(scheduled, hasLength(18));
      expect(count, 701);
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
        expect(restored, hasLength(18));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, prior.note);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
          expect(c.note, contains('과목코드·학점·개설분반 이수구분은 미공개'));
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

  // 쉬는 시간 포함 슬롯(#564): 서울 1~6교시 75분+15분(90분), 7~10교시 50분+10분(60분),
  // 세종 50분+10분(60분). 근거 문서 미확인이라 현재 자료의 연속 교시 시작 간격을 쓴다.
  test('KU 교시 구간은 쉬는 시간을 포함한 슬롯이고 연속 교시는 합쳐져 있다', () {
    const slots = {
      'seoul': (
        [540, 630, 720, 810, 900, 990, 1080, 1140, 1200, 1260],
        [615, 705, 795, 885, 975, 1065, 1130, 1190, 1250, 1310],
        62148,
      ),
      'sejong': (
        [540, 600, 660, 720, 780, 840, 900, 960, 1020, 1080, 1140, 1200, 1260],
        [590, 650, 710, 770, 830, 890, 950, 1010, 1070, 1130, 1190, 1250, 1310],
        28024,
      ),
    };
    for (final entry in slots.entries) {
      final (starts, periodEnds, total) = entry.value;
      final data =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/korea-${entry.key}-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      var count = 0;
      for (final course in data['courses'] as List) {
        final groups = <String, List<Map>>{};
        for (final s in course['schedules'] as List) {
          count++;
          final start = s['startMinute'] as int;
          final end = s['endMinute'] as int;
          if (start == 480) continue; // 서울 교직 0교시는 보류(그대로 둠)
          expect(
            starts.contains(start) && periodEnds.contains(end),
            isFalse,
            reason: '${course['sourceId']} ${s['date']} 쉬는 시간이 빠진 교시 구간',
          );
          groups.putIfAbsent('${s['date']}|${s['classroom']}', () => []).add(s);
        }
        for (final list in groups.values) {
          list.sort(
            (a, b) =>
                (a['startMinute'] as int).compareTo(b['startMinute'] as int),
          );
          for (var i = 1; i < list.length; i++) {
            expect(
              (list[i]['startMinute'] as int) -
                  (list[i - 1]['endMinute'] as int),
              greaterThanOrEqualTo(60),
              reason: '${course['sourceId']} ${list[i]['date']} 합치지 않은 연속 구간',
            );
          }
        }
      }
      expect(count, total, reason: entry.key);
    }
  });
}
