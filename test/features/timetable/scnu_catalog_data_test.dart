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
  final regulation =
      jsonDecode(
            File(
              'test/fixtures/scnu_night_clock_regulation/kyohak-article52.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  test('Native subject code, section, declared merged cells and closures', () {
    expect(courses, hasLength(1626));
    expect(
      sha256
          .convert(fixtureFile('$directory/$file').readAsBytesSync())
          .toString(),
      audit['candidate']['sha256'],
    );
    expect(audit['closedStillPresent'], isEmpty);
    expect(
      courses.map((c) => '${c.code}/${c.section}').toSet(),
      hasLength(1626),
    );
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
      if (night6.contains(c.sourceId)) {
        expect(c.meetings, isNotEmpty, reason: c.sourceId);
      } else {
        expect(c.meetings, isEmpty, reason: c.sourceId);
      }
    }
    expect(courses.where((c) => c.meetings.isEmpty), hasLength(121));
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
        final native = (source['강의시간'] as String)
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll('/', '');
        expect(syntax.allMatches(native), isNotEmpty);
        expect(native.replaceAll(syntax, ''), isEmpty);
        expect(c.sourceClassroom, source['강의실']);
        final pieces = <List<Object>>[];
        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 7));
          day = day.add(const Duration(days: 1))
        ) {
          final date = timetableDateKey(day);
          if (excluded.contains(date)) {
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
              if (p == 16) {
                expect(match[2], isNotNull, reason: c.sourceId);
                expect(night6, contains(c.sourceId));
              }
              final clock = clocks[p]!;
              var room = source['강의실'];
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
      expect(count, 29211);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1505));
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
        expect(values, hasLength(1505));
        expect(count, 29211);
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(1505));
        for (final c in restored.materializeClasses()) {
          expect(c.isValid, true);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      },
    );
  }
}
