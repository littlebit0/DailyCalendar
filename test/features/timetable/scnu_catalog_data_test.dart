import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-c/scnu-current-20261008';
Map<String, dynamic> read(String file) =>
    jsonDecode(fixtureFile('$directory/$file').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  final audit = read('candidate-audit.json');
  final file = audit['candidate']['file'] as String;
  final raw =
      jsonDecode(
            fixtureFile(
              'assets/timetable/scnu-unknown-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final courses = UniversityDataset.fromJson(raw).courses;
  final records = {for (final row in raw['courses']) row['sourceId']: row};
  final currentProof =
      jsonDecode(
            fixtureFile(
              'work/university-research/fifteen-school-native-room-bulk-v2-20261010/proof.json',
            ).readAsStringSync(),
          )
          as Map;
  final resolvedRooms = <String, Map>{
    for (final row in currentProof['newCourses'] as List)
      if (row['school'] == 'scnu') row['sourceId'] as String: row as Map,
  };
  // 원문이 '요일 야간 N' 상대 교시로 6교시를 직접 적은 강좌만 교학규정 제52조 6교시를 쓴다.
  final relativeNight = RegExp(r'^[월화수목금]야간\d(?:,\d)*$');
  final night6 = <String>{
    for (final h in audit['holds'] as List)
      if ((h['reasons'] as List).join('|') ==
              'published period clock absent: 16' &&
          relativeNight.hasMatch(
            (records['scnu-2026-2-${h['nativeSubjectCode']}-${h['nativeSection']}']['publicEducationRows'][0]['education']['강의시간']
                    as String)
                .replaceAll(RegExp(r'\s+'), ''),
          ))
        'scnu-2026-2-${h['nativeSubjectCode']}-${h['nativeSection']}',
  };
  // 2026-11-23 결정: 공식 요일·교시가 있는 보류 강좌를 확정(tool/timetable/apply_scnu_held_periods.py).
  final heldPeriods = <String, Map>{
    for (final row in raw['courses'] as List)
      if (row['heldPeriodReview'] != null)
        row['sourceId'] as String: row['heldPeriodReview'] as Map,
  };
  final regulation =
      jsonDecode(
            File(
              'test/fixtures/scnu_night_clock_regulation/kyohak-article52.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  test('Native subject code, section, declared merged cells and closures', () {
    expect(courses, hasLength(1721));
    expect(
      sha256
          .convert(fixtureFile('$directory/$file').readAsBytesSync())
          .toString(),
      audit['candidate']['sha256'],
    );
    expect(audit['closedStillPresent'], isEmpty);
    expect(
      courses.map((c) => '${c.code}/${c.section}').toSet(),
      hasLength(1720),
    );
    // 0824판 XG1174-00 두 행(고전의 재발견·그린스마트팜)은 원문 위치로 나눈 두 강좌다.
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(1721));
    final green = courses.singleWhere(
      (c) => c.sourceId == 'scnu-2026-2-XG1174-00-T35R42',
    );
    expect(green.title, '그린스마트팜과 농촌융복합산업');
    expect(green.meetings.first.originalStartMinute, 840);
    expect(green.meetings.first.originalEndMinute, 960);
    for (final c in courses) {
      final record = records[c.sourceId];
      expect(record['referenceKind'], '교과목코드');
      expect(record['canonicalSubjectCodePublished'], true);
      expect(c.section, isNotEmpty);
      for (final row in record['publicEducationRows']) {
        final e = row['education'];
        expect(c.code, e['코드'] ?? e['교과목코드']);
        expect(c.section, e['분반']);
        expect(row['declaredMergedCells'], isNotEmpty);
      }
      expect(c.remarks, contains('실시간 시스템 변경 전체는 확인되지 않았습니다'));
      expect(record['campus'], 'unknown');
    }
    final held = (audit['holds'] as List)
        .map((h) => '${h['nativeSubjectCode']}/${h['nativeSection']}')
        .toSet();
    expect(held, hasLength(288));
    expect(resolvedRooms, hasLength(155));
    expect(
      courses.where(
        (c) =>
            held.contains('${c.code}/${c.section}') &&
            !resolvedRooms.containsKey(c.sourceId),
      ),
      hasLength(133),
    );
    expect(night6, hasLength(12));
    for (final c in courses.where(
      (c) =>
          held.contains('${c.code}/${c.section}') &&
          !resolvedRooms.containsKey(c.sourceId),
    )) {
      if (night6.contains(c.sourceId) || heldPeriods.containsKey(c.sourceId)) {
        expect(c.meetings, isNotEmpty, reason: c.sourceId);
      } else {
        expect(c.meetings, isEmpty, reason: c.sourceId);
      }
    }
    expect(heldPeriods, hasLength(83));
    // 공식 수업시간표에 있는 폐강 분반도 원문 그대로 넣는다(2026-11-23 결정).
    final closed = courses.where((c) => c.remarks.contains('공식 수업시간표에 게시'));
    expect(closed, hasLength(95));
    expect(
      closed.where((c) => c.remarks.contains('폐강 목록에도 있음')),
      hasLength(63),
    );
    expect(closed.where((c) => c.meetings.isNotEmpty), hasLength(92));
    // 표에 없는 16교시는 교학규정 제52조 야간 6교시(22:10~22:55) 슬롯으로 잇는다.
    final night16 = courses.singleWhere(
      (c) => c.sourceId == 'scnu-2026-2-GC0656-F0',
    );
    expect(night16.meetings, hasLength(13));
    expect(night16.meetings.first.date, '2026-09-02');
    expect(night16.meetings.first.originalStartMinute, 1230);
    expect(night16.meetings.first.originalEndMinute, 1380);
    // '(1주-5주)'는 개강 주부터 5주 동안의 날짜만 둔다.
    final firstWeeks = courses.singleWhere(
      (c) => c.sourceId == 'scnu-2026-2-XG1128-00',
    );
    expect(firstWeeks.meetings.map((m) => m.date).last, '2026-09-30');
    expect(courses.where((c) => c.meetings.isEmpty), hasLength(62));
    // 원문 강의시간이 빈 강좌(미개설 21건)는 원문 그대로 두고 시간 미정으로 둔다.
    final untimed = courses.where(
      (c) => c.meetings.isEmpty && c.sourceSchedule.isEmpty,
    );
    expect(untimed, hasLength(21));
    for (final c in untimed) {
      expect(c.scheduleStatus, 'unscheduled', reason: c.sourceId);
    }
    // '토11,12'는 토요일 야간1·2교시(교학규정 제52조 토요일 표): 13:00~14:40.
    final saturday = courses.singleWhere(
      (c) => c.sourceId == 'scnu-2026-2-ED0043-00',
    );
    expect(saturday.scheduleStatus, 'scheduled');
    expect(saturday.meetings.first.date, '2026-09-05');
    expect(saturday.meetings.first.originalStartMinute, 780);
    expect(saturday.meetings.first.originalEndMinute, 880);
    // 학점교류(콘텐츠 원격수업) 41강좌는 실시간 수업 시각이 없어 시간 미정이다.
    final exchange = courses.where(
      (c) => c.departments.contains('광주전남권역 대학 간 학점교류(원격)'),
    );
    expect(exchange, hasLength(41));
    for (final c in exchange) {
      expect(c.scheduleStatus, 'unscheduled', reason: c.sourceId);
      expect(c.meetings, isEmpty);
    }
    expect(courses.where((c) => c.scheduleStatus == 'unrecognized'), isEmpty);
    // XH1028-00 0824판 두 행(월1,2수6·월3,4수7)을 모두 모임으로 넣는다.
    final ksl = courses.singleWhere((c) => c.sourceId == 'scnu-2026-2-XH1028-00');
    expect(
      ksl.meetings.where((m) => m.weekday == 1).first.originalEndMinute,
      780,
    );
  });
  test(
    'All dates independently match native weekdays, day/night clock cells and room',
    () {
      final proof = read('native-clock-proof.json');
      final clocks = <int, List<int>>{};
      for (final cells in [
        proof['sourceDayClockCells'],
        proof['sourceNightClockCells'],
      ]) {
        for (final cell in cells as List) {
          if (cell['row'] == 0 || cell['column'] != 0) {
            continue;
          }
          final row = cell['row'];
          final pcell = cells.singleWhere(
            (c) => c['row'] == row && c['column'] == 1,
          );
          final ptext = (pcell['paragraphs'] as List).join(' ');
          final p = ptext.startsWith('야간')
              ? int.parse(RegExp(r'\((\d+)\)').firstMatch(ptext)![1]!)
              : int.parse(ptext);
          final time = RegExp(
            r'(\d{2}):(\d{2})',
          ).allMatches((cell['paragraphs'] as List).join(' ')).toList();
          expect(time, hasLength(2));
          clocks[p] = time
              .map((m) => int.parse(m[1]!) * 60 + int.parse(m[2]!))
              .toList();
        }
      }
      expect(clocks, hasLength(15));
      expect(clocks.containsKey(16), false);
      final image = regulation['tableImage'] as Map;
      expect(
        sha256
            .convert(
              File(
                'test/fixtures/scnu_night_clock_regulation/${image['file']}',
              ).readAsBytesSync(),
            )
            .toString(),
        image['sha256'],
      );
      final weekdayNight = [
        for (final range
            in (regulation['transcribedTable'] as Map)['평일'] as List)
          RegExp(r'(\d{2}):(\d{2})')
              .allMatches(range as String)
              .map((m) => int.parse(m[1]!) * 60 + int.parse(m[2]!))
              .toList(),
      ];
      expect(weekdayNight, hasLength(6));
      // 교학규정 표 1~5교시가 수업시간표 야간1(11)~야간5(15)와 같아야 6교시를 이어 쓴다.
      for (var i = 0; i < 5; i++) {
        expect(weekdayNight[i], clocks[11 + i]);
      }
      clocks[16] = weekdayNight[5];
      // 토요일 야간 교시(11=야간1~)는 교학규정 제52조 토요일 표(13:00~)를 쓴다.
      final saturdayNight = [
        for (final range
            in (regulation['transcribedTable'] as Map)['토요일'] as List)
          RegExp(r'(\d{2}):(\d{2})')
              .allMatches(range as String)
              .map((m) => int.parse(m[1]!) * 60 + int.parse(m[2]!))
              .toList(),
      ];
      expect(saturdayNight.first, [780, 825]);
      final excluded = {
        ...(audit['excludedHolidays'] as List),
        ...(audit['excludedMidtermDates'] as List),
      };
      // 교시 슬롯 = 수업 + 쉬는 시간: 주간 50분+10분, 야간 45분+5분(교학규정 제52조).
      // 같은 날 같은 강의실에서 앞 구간 끝과 뒤 구간 시작의 간격이 60분 미만이면 합친다.
      int slotEnd(List<int> clock) =>
          clock[0] + (clock[1] - clock[0] == 50 ? 60 : 50);
      final syntax = RegExp(r'([월화수목금토일])(야간)?(\d+(?:,\d+)*)');
      var count = 0;
      for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
        final record = records[c.sourceId];
        final source = record['publicEducationRows'][0]['education'];
        final review = heldPeriods[c.sourceId];
        final native =
            (review?['interpretedSchedule'] ?? source['강의시간'] as String)
                .replaceAll(RegExp(r'\s+'), '')
                .replaceAll('/', '');
        final weeks = review?['weeks'] as List?;
        expect(syntax.allMatches(native), isNotEmpty);
        expect(native.replaceAll(syntax, ''), isEmpty);
        // 강의실 칸이 없는 원문 행은 빈 강의실로 둔다.
        expect(c.sourceClassroom, source['강의실'] ?? '');
        final pieces = <List<Object>>[];
        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 7));
          day = DateTime(day.year, day.month, day.day + 1)
        ) {
          final date = timetableDateKey(day);
          if (excluded.contains(date)) {
            continue;
          }
          // 1주 = 2026-09-01 개강 주(월요일 8/31 시작), 중간시험 10/19~23은 8주.
          final week = day.difference(DateTime(2026, 8, 31)).inDays ~/ 7 + 1;
          if (weeks != null && (week < weeks[0] || week > weeks[1])) {
            continue;
          }
          for (final match in syntax.allMatches(native)) {
            final weekday = '월화수목금토일'.indexOf(match[1]!) + 1;
            if (day.weekday != weekday) {
              continue;
            }
            var periods = match[3]!.split(',').map(int.parse).toList();
            if (match[2] != null && periods.any((p) => p < 11)) {
              periods = periods.map((p) => p + 10).toList();
            }
            for (final p in periods) {
              if (p == 16 && review == null) {
                expect(match[2], isNotNull, reason: c.sourceId);
                expect(night6, contains(c.sourceId));
              }
              final clock = weekday == 6 && p > 10
                  ? saturdayNight[p - 11]
                  : clocks[p]!;
              var room = review?['classroom'] ?? source['강의실'];
              final proof = resolvedRooms[c.sourceId];
              if (proof != null) {
                final slot = (proof['literalSlots'] as List).singleWhere(
                  (r) =>
                      r['weekday'] == weekday &&
                      r['startMinute'] == clock[0] &&
                      r['endMinute'] == clock[1],
                );
                room = slot['classroom'];
                // An unresolved composite room is not assigned to a specific session.
                if (room == '') expect(c.sourceClassroom, source['강의실']);
              }
              pieces.add([date, weekday, clock[0], slotEnd(clock), room]);
            }
          }
        }
        pieces.sort((a, b) {
          final byDate = (a[0] as String).compareTo(b[0] as String);
          return byDate != 0 ? byDate : (a[2] as int).compareTo(b[2] as int);
        });
        final merged = <List<Object>>[];
        for (final p in pieces) {
          final last = merged.isEmpty ? null : merged.last;
          if (last != null &&
              last[0] == p[0] &&
              last[4] == p[4] &&
              (p[2] as int) - (last[3] as int) < 60) {
            last[3] = p[3];
          } else {
            merged.add([...p]);
          }
        }
        final expected = {
          for (final p in merged) '${p[0]}/${p[1]}/${p[2]}/${p[3]}/${p[4]}',
        };
        final actual = <String>{};
        for (final m in c.meetings) {
          count++;
          expect(m.weekday, m.teachingDate!.weekday);
          expect(excluded.contains(m.date), false);
          expect(
            actual.add(
              '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            true,
          );
        }
        expect(actual, expected, reason: 'native ${c.code}/${c.section}');
      }
      expect(count, 32096);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1659));
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'Actual 1338 model classes 49857 dates full Drive JSON roundtrip ${mode.name}',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.defaultMode, mode);
          expect(saved.note, c.remarks);
          expect(saved.period!.start, DateTime(2026, 9, 1));
          expect(
            saved.period!.end,
            resolvedRooms.containsKey(c.sourceId)
                ? DateTime(2026, 12, 7)
                : DateTime(2026, 12, 18),
          );
          for (final m in saved.meetings) {
            count++;
            expect(m.isValid, true);
            expect(saved.period!.contains(m.teachingDate!), true);
            expect(saved.modeOn(m, m.teachingDate!), mode);
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(1659));
        expect(count, 32096);
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(1659));
        for (final c in restored.materializeClasses()) {
          expect(c.isValid, true);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      },
    );
  }
}
