import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-r/ku/current-public-broad-followup-v5-20261009/';
  dynamic read(String name) =>
      jsonDecode(fixtureFile('$root$name').readAsStringSync());

  final source = read('source-nursing53-education.json') as Map;
  final dataset =
      read('korea-seoul-2026-2.current-native-reviewed-v5-20261009.json')
          as Map<String, dynamic>;
  final rows = source['rows'] as List;
  final courses = dataset['courses'] as List;
  final byId = {
    for (final c in courses) '${c['courseCode']}-${c['section']}': c,
  };
  final calendar = read('current-2026-2-calendar-education.json') as Map;

  test(
    'Direct own current calendar and regular campus clock, badge definitions and incomplete closure boundary are distinct',
    () {
      final events = {
        for (final r in calendar['nativeEducationalRows'] as List)
          '${r['month']}/${r['sourceEvent']}': r['sourceDayText'],
      };
      expect(events['9월/2026학년도 제2학기 개강'], '1(화)');
      expect(events['12월/제2학기 종강(16주차)'], '18(금)');
      expect(events['10월/제2학기 중간고사'], '20(화)~26(월)');
      expect(events['12월/제2학기 기말고사'], '14(월)~18(금)');
      expect(events['9월/추석(공휴일)'], '24(목)~26(토)');
      expect(events['10월/대체휴일'], '5(월)');
      expect(events['10월/한글날(공휴일)'], '9(금)');
      expect(calendar['ordinaryReservationEndDerived'], '2026-12-13');
      expect(
        sha256
            .convert(
              fixtureFile(
                '${root}source-current-ui-regular-campus-clock-education.json',
              ).readAsBytesSync(),
            )
            .toString(),
        'd003c9660ea7afe617a582e06cef6cd30363843724516e5e0351cd064ec9047e',
      );
      final table =
          read(
                'source-current-ui-regular-campus-clock-education.json',
              )['nativeTables'][0]
              as List;
      expect(table[0][1], '정규학기 (Regular Semester)');
      expect(table[11], ['9', '20:00~20:50', '17:00~17:50', '']);
      expect(table[12], ['10', '21:00~21:50', '18:00~18:50', '']);
      final clock = read('current-2026-2-campus-clock-education.json') as Map;
      expect(clock['seoulTeachingPeriod0']['startMinute'], 520);
      expect(clock['seoulTeachingPeriod0']['endMinute'], isNull);
      final legend = read(
        'source-current-course-badge-legend-education.json',
      )['educationLegend'].join();
      expect(legend, contains('DL: DROP LIMIT(수강포기제한)'));
      expect(legend, contains('FC: Flipped Class'));
      expect(legend, contains('NM: NeMo Class'));
      expect(dataset['completionClaim'], false);
      expect(
        read('closure-cumulative-scope-audit.json')['knownSeoulClosedUnion'],
        hasLength(132),
      );
    },
  );

  test(
    'All 53 current native education fields remain exact, closed132 join independent',
    () {
      expect(source['selectedCampus'], '서울');
      expect(source['selectedYear'], 2026);
      expect(source['selectedSemester'], '2R');
      expect(source['displayedTotal'], 53);
      expect(rows, hasLength(53));
      expect(byId, hasLength(1690));
      expect(
        sha256
            .convert(
              fixtureFile(
                '${root}source-nursing53-education.json',
              ).readAsBytesSync(),
            )
            .toString(),
        read('source-nursing53-receipt.json')['sha256'],
      );
      final closed = <String>{};
      for (final name in [
        'first-closure-native-educational-receipt.json',
        'second-closure-native-educational-receipt.json',
      ]) {
        final receipt = read(name) as Map;
        for (final row in receipt['rows'] as List) {
          expect(
            row['identity'],
            '${row['nativeCode']}-${row['nativeSection']}',
          );
          closed.add('${row['nativeCode']}-${row['nativeSection']}');
        }
      }
      expect(closed, hasLength(132));
      expect(closed, contains('NRSG458-00'));
      expect(byId.keys.toSet().intersection(closed), isEmpty);
      for (final row in rows) {
        final c = byId['${row['COUR_CD']}-${row['COUR_CLS']}'];
        expect(c['sourceEducationalMetadata'], row);
        expect(row['YEAR'], '2026');
        expect(row['TERM'], '2R');
        expect(row['CAMPUS'], '서울');
        expect(c['campus'], 'seoul');
        expect(c['professor'], row['PROF_NM']);
        expect(
          c['courseName'],
          (row['COUR_NM'] as String).split('\n').first.trim(),
        );
        expect(c['sourceSchedule'], row['TIME_ROOM']);
        expect(c['credits'], double.parse(row['CREDIT'] as String));
        expect(c['classification'], row['ISU_NM']);
        expect(c['reservationOnly'], true);
        expect(c['actualAttendanceConfirmed'], false);
      }
    },
  );

  test(
    'Current raw direct HH and numeric day-room allocations independently determine364 reservations',
    () {
      var scheduled = 0;
      var count = 0;
      final holidays = (calendar['holidays'] as List).toSet();
      for (final raw in rows) {
        final c = byId['${raw['COUR_CD']}-${raw['COUR_CLS']}'];
        if ((raw['TIME_ROOM'] as String).isEmpty) {
          expect(c['schedules'], isEmpty);
          continue;
        }
        final allocation = <String, String>{};
        for (final line in (raw['TIME_ROOM'] as String).split('\n')) {
          final match = RegExp(
            r'^([월화수목금토일])\(([^)]+)\)\s+(.+)$',
          ).firstMatch(line.trim())!;
          for (final part in match[2]!.split(',')) {
            final range = part.split(RegExp('[-~]')).map(int.parse).toList();
            for (var p = range.first; p <= range.last; p++) {
              final key = '${match[1]}/$p';
              if (allocation.containsKey(key)) {
                expect(allocation[key], match[3]);
              }
              allocation[key] = match[3]!;
            }
          }
        }
        final segments = <Map<String, dynamic>>[];
        final covered = <String>{};
        String? lastDay;
        for (final match in RegExp(
          r'(?:([월화수목금토일])\s*)?(\d+(?:\s*[~-]\s*\d+)?)교시\((\d{1,2}):(\d{2})[~-](\d{1,2}):(\d{2})\)',
        ).allMatches(raw['APPLY_DEPT'] as String)) {
          final day = match[1] ?? lastDay;
          expect(day, isNotNull);
          final range = match[2]!
              .replaceAll(' ', '')
              .split(RegExp('[~-]'))
              .map(int.parse)
              .toList();
          final rooms = <String?>{};
          for (var p = range.first; p <= range.last; p++) {
            final key = '$day/$p';
            rooms.add(allocation[key]);
            covered.add(key);
          }
          expect(rooms, hasLength(1));
          expect(rooms.single, isNotNull);
          final start = int.parse(match[3]!) * 60 + int.parse(match[4]!);
          final end = int.parse(match[5]!) * 60 + int.parse(match[6]!);
          expect(end, greaterThan(start));
          segments.add({
            'weekday': '월화수목금토일'.indexOf(day!) + 1,
            'start': start,
            'end': end,
            'room': rooms.single,
          });
          lastDay = day;
        }
        expect(covered, allocation.keys.toSet());
        expect(segments, isNotEmpty);
        final startText = raw['FLEXIBLE_FR_DT'] == ''
            ? calendar['semesterStart']
            : raw['FLEXIBLE_FR_DT'];
        final endText = raw['FLEXIBLE_TO_DT'] == ''
            ? calendar['semesterEnd']
            : raw['FLEXIBLE_TO_DT'];
        expect(c['period'], {'startDate': startText, 'endDate': endText});
        final expected = <String>{};
        for (
          var date = DateTime.parse(startText as String);
          !date.isAfter(DateTime.parse(endText as String)) &&
              !date.isAfter(DateTime(2026, 12, 13));
          date = date.add(const Duration(days: 1))
        ) {
          final day = date.toIso8601String().substring(0, 10);
          if (holidays.contains(day) ||
              (day.compareTo('2026-10-20') >= 0 &&
                  day.compareTo('2026-10-26') <= 0)) {
            continue;
          }
          for (final segment in segments) {
            if (date.weekday == segment['weekday']) {
              expected.add(
                '$day/${date.weekday}/${segment['start']}/${segment['end']}/${segment['room']}',
              );
            }
          }
        }
        final actual = (c['schedules'] as List)
            .map(
              (m) =>
                  '${m['date']}/${m['weekday']}/${m['startMinute']}/${m['endMinute']}/${m['classroom']}',
            )
            .toSet();
        expect(actual, expected);
        expect(actual, hasLength((c['schedules'] as List).length));
        scheduled++;
        count += actual.length;
      }
      expect(scheduled, 28);
      expect(count, 364);
      expect(
        (byId['NRSG430-00']['schedules'] as List).first['date'],
        '2026-08-24',
      );
      expect(
        (byId['NRSG467-00']['schedules'] as List).first['date'],
        '2026-08-25',
      );
      expect(
        (byId['NRSG225-00']['schedules'] as List).first['startMinute'],
        770,
      );
    },
  );

  test(
    'Whole current native education and prior1188 deep equality; source-independent new literal clocks and allocation exceptions',
    () {
      final prior =
          read('baseline-seoul1188-reviewed-v4.json')['courses'] as List;
      final old = {
        for (final c in prior) '${c['courseCode']}-${c['section']}': c,
      };
      expect(old, hasLength(1188));
      expect(
        old.values.where((c) => (c['schedules'] as List).isNotEmpty),
        hasLength(1056),
      );
      expect(
        old.values.fold<int>(0, (n, c) => n + (c['schedules'] as List).length),
        29174,
      );
      final sources = <String, Map>{};
      final scopes = read('source-captured-scope-config.json') as List;
      for (final scope in scopes) {
        final source = read(scope['file'] as String) as Map;
        expect(
          sha256
              .convert(fixtureFile('$root${scope['file']}').readAsBytesSync())
              .toString(),
          scope['sourceSHA256'],
        );
        expect(source['selectedYear'], 2026);
        expect(source['selectedSemester'], '2R');
        expect(source['selectedCampus'], '서울');
        expect(source['rows'], hasLength(scope['whole'] as int));
        expect(source['capturedRows'], scope['whole']);
        expect(source['displayedTotal'], scope['whole']);
        for (final raw in source['rows'] as List) {
          final id = '${raw['COUR_CD']}-${raw['COUR_CLS']}';
          expect(sources.containsKey(id), false);
          sources[id] = raw as Map;
          final c = byId[id];
          expect(c['sourceEducationalMetadata'], raw);
          expect(c['courseCode'], raw['COUR_CD']);
          expect(c['section'], raw['COUR_CLS']);
          expect(c['professor'], raw['PROF_NM']);
          expect(c['classification'], raw['ISU_NM']);
          expect(c['credits'], double.parse(raw['CREDIT'] as String));
          expect(c['sourceSchedule'], raw['TIME_ROOM']);
          expect(c['campus'], 'seoul');
          if (old.containsKey(id)) {
            expect(c, old[id]);
          }
        }
      }
      expect(sources.length, courses.length);
      const table = {
        0: [480, 530],
        1: [540, 615],
        2: [630, 705],
        3: [720, 795],
        4: [810, 885],
        5: [900, 975],
        6: [990, 1065],
        7: [1080, 1130],
        8: [1140, 1190],
        9: [1200, 1250],
        10: [1260, 1310],
      };
      const physicalDay = {
        'EDUC230-00': '목',
        'EDUC274-00': '화',
        'EDUC318-00': '월',
      };
      final allClosed =
          (read('closure-cumulative-scope-audit.json')['knownSeoulClosedUnion']
                  as List)
              .toSet();
      var independentScheduled = 1056;
      var independentMeetings = 29174;
      for (final entry in sources.entries) {
        final id = entry.key;
        if (old.containsKey(id)) {
          continue;
        }
        final raw = entry.value;
        final note = raw['APPLY_DEPT'] as String;
        final c = byId[id];
        var held =
            raw['MOOC_YN'] == '1' ||
            note == '혼합수업' ||
            note.contains('일정-') ||
            allClosed.contains(id) ||
            (note.contains('유연학기') &&
                (raw['FLEXIBLE_FR_DT'] == '' || raw['FLEXIBLE_TO_DT'] == ''));
        if (['GEOG172-00', 'GEOG272-00', 'GEOG372-00'].contains(id)) {
          expect(raw['CREDIT'], '0');
          expect(raw['TIME_ROOM'], startsWith('토(0)'));
          held = true;
        }
        if (note.contains('이론강의실') ||
            RegExp(r'^(체육생활관|화정체육관) ').hasMatch(note)) {
          held = true;
        }
        final first = (raw['COUR_NM'] as String).split('\n').first;
        if (first.endsWith('M') && raw['NEMO_YN'] != '1') {
          held = true;
        }
        String? room;
        final bare = RegExp(r'^[^<>\n:]*?\d+[A-Z]?호$').firstMatch(note.trim());
        if (bare != null) {
          room = bare[0];
        }
        final marked = RegExp(
          r'강의실\s*:\s*([^<>\n]*?\d+[A-Z]?호)',
        ).firstMatch(note);
        if (marked != null &&
            RegExp(r'\d+[A-Z]?호').allMatches(note).length == 1) {
          room = marked[1]!.trim();
        }
        if (id == 'JMCO444-00') {
          expect(note, contains('강의실: 대강당 한국일보홀<br>'));
          room = '대강당 한국일보홀';
        }
        if (id == 'LIET365-00') {
          expect(note, '*강의실 생명과학관 동관 416호 오정강당으로 변경(2026.08.28.자)');
          room = '생명과학관 동관 416호 오정강당';
        }
        if (id == 'LESE322-00' || id == 'LESE326-00') {
          expect(note, startsWith('●강의실: 생명과학관(동관) 416호 오정강당'));
          room = '생명과학관(동관) 416호 오정강당';
        }
        if (id == 'ECON172-09' || id == 'ECON172-10') {
          expect(note, '(경영대 전용반)(강의실: 대강당 한국일보홀)');
          room = '대강당 한국일보홀';
        }
        if (id == 'JURA204-00') {
          expect(note, '강의실: 대강당 김양현홀');
          room = '대강당 김양현홀';
        }
        final slots = <Map<String, dynamic>>[];
        final allocations = <String, Set<String>>{};
        var partial = false;
        for (final rawLine in (raw['TIME_ROOM'] as String).split('\n')) {
          if ((raw['TIME_ROOM'] as String).isEmpty) {
            continue;
          }
          var line = rawLine.trim();
          final day = line.isEmpty ? '' : line.substring(0, 1);
          if (physicalDay.containsKey(id) && day != physicalDay[id]) {
            expect(note, contains('$day: 비대면'));
            partial = true;
            continue;
          }
          if (id == 'EDUC274-00') {
            expect(note, contains('화: 대면,(교육관 507호)'));
            room = '교육관 507호';
          }
          if (RegExp(r'^[월화수목금토일]\([^)]+\)$').hasMatch(line) && room != null) {
            line = '$line $room';
          }
          final allocation = RegExp(
            r'^([월화수목금토일])\(([^)]+)\)\s+(.+)$',
          ).firstMatch(line);
          if (allocation == null) {
            partial = true;
            continue;
          }
          final dayNumber = '월화수목금토일'.indexOf(allocation[1]!) + 1;
          for (final part in allocation[2]!.split(',')) {
            final bounds = part.split(RegExp('[-~]')).map(int.parse).toList();
            final range = [for (var p = bounds.first; p <= bounds.last; p++) p];
            if (range.any((p) => !table.containsKey(p))) {
              held = true;
              continue;
            }
            for (final p in range) {
              final key = '$dayNumber/$p';
              allocations.putIfAbsent(key, () => {}).add(allocation[3]!);
              slots.add({
                'weekday': dayNumber,
                'startMinute': table[p]![0],
                'endMinute': table[p]![1],
                'classroom': allocation[3],
                'period': p,
              });
            }
          }
        }
        final conflictKeys = allocations.entries
            .where((e) => e.value.length > 1)
            .map((e) => e.key)
            .toSet();
        if (conflictKeys.isNotEmpty) {
          partial = true;
        }
        var segments = slots
            .where(
              (s) => !conflictKeys.contains('${s['weekday']}/${s['period']}'),
            )
            .map((s) => Map<String, dynamic>.from(s)..remove('period'))
            .toList();
        if ([
          'HEED234-01',
          'HEED234-02',
          'HEED333-00',
          'HEED334-00',
          'FADM402-00',
          'HISE204-00',
          'HISE411-00',
          'HISE462-00',
        ].contains(id)) {
          final direct = RegExp(
            r'^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})',
          ).firstMatch(note)!;
          var start = int.parse(direct[1]!) * 60 + int.parse(direct[2]!);
          var end = int.parse(direct[3]!) * 60 + int.parse(direct[4]!);
          final nativeStart = segments
              .map((s) => s['startMinute'] as int)
              .reduce((a, b) => a < b ? a : b);
          if (nativeStart >= 720 && start < 720) {
            start += 720;
            end += 720;
          }
          expect(start, nativeStart);
          expect(segments.map((s) => s['weekday']).toSet(), hasLength(1));
          expect(segments.map((s) => s['classroom']).toSet(), hasLength(1));
          expect(c['sourceClockOverrideProof']['sourceExplicitPM'], false);
          segments = [
            {
              'weekday': segments.first['weekday'],
              'startMinute': start,
              'endMinute': end,
              'classroom': segments.first['classroom'],
            },
          ];
          expect(
            end,
            id == 'HEED333-00'
                ? 755
                : id.startsWith('HISE')
                ? 1155
                : 1025,
          );
        }
        if (id == 'MATE404-00') {
          expect(note, contains('화요일은 6시 20분까지 수업'));
          final tue = segments.where((s) => s['weekday'] == 2).toList();
          expect(tue.map((s) => s['startMinute']), contains(990));
          expect(tue.map((s) => s['endMinute']), contains(1130));
          segments = [
            ...segments.where((s) => s['weekday'] != 2),
            {
              'weekday': 2,
              'startMinute': 990,
              'endMinute': 1100,
              'classroom': tue.first['classroom'],
            },
          ];
          expect(raw['FLEXIBLE_TO_DT'], '2026-11-09');
        }
        if (segments.isEmpty) {
          held = true;
        }
        final expected = <String>{};
        final start = raw['FLEXIBLE_FR_DT'] == ''
            ? calendar['semesterStart']
            : raw['FLEXIBLE_FR_DT'];
        final end = raw['FLEXIBLE_TO_DT'] == ''
            ? calendar['semesterEnd']
            : raw['FLEXIBLE_TO_DT'];
        expect(c['period'], {'startDate': start, 'endDate': end});
        if (!held) {
          var date = DateTime.parse(start as String);
          while (date.compareTo(DateTime.parse(end as String)) <= 0 &&
              date.compareTo(
                    DateTime.parse(
                      calendar['ordinaryReservationEndDerived'] as String,
                    ),
                  ) <=
                  0) {
            final day = date.toIso8601String().substring(0, 10);
            if (!(calendar['holidays'] as List).contains(day) &&
                (day.compareTo(calendar['midtermStart'] as String) < 0 ||
                    day.compareTo(calendar['midtermEnd'] as String) > 0)) {
              for (final s in segments) {
                if (s['weekday'] == date.weekday) {
                  expected.add(
                    '$day/${s['weekday']}/${s['startMinute']}/${s['endMinute']}/${s['classroom']}',
                  );
                }
              }
            }
            date = date.add(const Duration(days: 1));
          }
        }
        final actual = c['schedules'] as List;
        final signatures = {
          for (final m in actual)
            '${m['date']}/${m['weekday']}/${m['startMinute']}/${m['endMinute']}/${m['classroom']}',
        };
        expect(signatures, expected, reason: id);
        expect(
          actual.length,
          signatures.length,
          reason: 'No duplicate interval $id',
        );
        for (final m in actual) {
          expect(m.containsKey('deliveryMode'), false);
        }
        if (id == 'ELED164-01') {
          expect(raw['PROF_NM'], '이영주');
          expect(note, '이지선 교수님');
          expect(c['sourceInstructorConflict']['resolved'], false);
          expect(c['professor'], '이영주');
        }
        expect(c['actualAttendanceConfirmed'], false);
        expect(c['reservationOnly'], true);
        expect(c['sourcePartialCoverage'], partial, reason: id);
        if (actual.isNotEmpty) {
          independentScheduled++;
          independentMeetings += actual.length;
        }
      }
      for (final id in [
        'PSYC320-00',
        'PSYC334-00',
        'PSYC338-00',
        'PSYC390-00',
        'PSYC468-00',
        'PSYC496-00',
      ]) {
        expect(byId[id]['credits'], 1.5);
        expect(byId[id]['sourceEducationalMetadata']['CREDIT'], '1.5');
      }
      expect(byId['PSYC703-00']['classification'], '전공선택');
      expect(byId['PSYC703-00']['schedules'], isNotEmpty);
      for (final id in [
        'MATH342-01',
        'CHEM214-01',
        'CHEM214-02',
        'CHEM214-04',
        'CHEM310-00',
      ]) {
        expect(byId[id]['schedules'], isEmpty);
      }
      for (final id in [
        'COSE212-01',
        'COSE352-02',
        'COSE354-02',
        'COSE361-01',
        'COSE471-00',
        'COSE474-01',
      ]) {
        expect(byId[id]['period'], {
          'startDate': '2026-09-01',
          'endDate': '2026-10-26',
        });
        for (final m in byId[id]['schedules'] as List) {
          expect(
            (m['date'] as String).compareTo('2026-10-26'),
            lessThanOrEqualTo(0),
          );
        }
      }
      for (final id in [
        'COSE401-00',
        'COSE402-00',
        'COSE403-00',
        'COSE404-00',
        'DATA423-00',
        'DATA424-00',
        'DATA425-00',
        'STEP420-00',
        'STEP423-00',
      ]) {
        expect(byId[id]['sourceEducationalMetadata']['TIME_ROOM'], '미정');
        expect(byId[id]['schedules'], isEmpty);
      }
      for (final id in ['CSAI202-02', 'COSE352-01']) {
        expect(byId[id]['sourcePublishedBadge'], 'FC');
        expect(byId[id]['schedules'], isNotEmpty);
      }
      expect(byId['COSE382-03']['sourceClassroom'], '미래융합기술관 101호');
      const multipleBadges = {
        'CSAI202-02': ['기초딥러닝', 'FC', 'ES'],
        'COSE212-01': ['프로그래밍언어', 'DL', 'ES'],
        'COSE352-01': ['소프트웨어공학', 'FC', 'T'],
        'COSE361-01': ['인공지능(영강)', 'T', 'DL'],
        'COSE474-01': ['딥러닝', 'DL', 'ES'],
        'JURA242-01': ['민법', 'M', 'ES'],
        'JURA249-00': ['국제법', 'M', 'ES'],
      };
      for (final entry in multipleBadges.entries) {
        final raw = byId[entry.key]['sourceEducationalMetadata'] as Map;
        expect(
          (raw['COUR_NM'] as String).split('\n').first,
          entry.value.join(),
        );
        expect(byId[entry.key]['courseName'], entry.value.first);
        expect(
          byId[entry.key]['sourcePublishedBadges'],
          entry.value.skip(1).toList(),
        );
      }
      expect(byId['JURA204-00']['sourceClassroom'], '대강당 김양현홀');
      for (final id in ['JURA242-01', 'JURA249-00']) {
        expect(byId[id]['sourceEducationalMetadata']['MOOC_YN'], '1');
        expect(byId[id]['schedules'], isEmpty);
      }
      final clinical = [
        ...read('seoul-premedicine-current10-education.json')['rows'] as List,
        ...read('seoul-medicine-current55-education.json')['rows'] as List,
      ];
      expect(clinical, hasLength(65));
      for (final raw in clinical) {
        expect(
          byId['${raw['COUR_CD']}-${raw['COUR_CLS']}']['schedules'],
          isEmpty,
        );
      }
      final coop =
          read('seoul-field-practice-current7-education.json')['rows'] as List;
      expect(coop, hasLength(7));
      for (final raw in coop) {
        expect(
          byId['${raw['COUR_CD']}-${raw['COUR_CLS']}']['schedules'],
          isEmpty,
        );
      }
      final exclusion =
          read('source-military-scope-exclusion-education.json') as Map;
      expect(exclusion['capturedRows'], 10);
      expect(exclusion['productCandidateExcluded'], true);
      expect(exclusion['nativeTextRecoveryAttempted'], false);
      final military = read(exclusion['sourceFile'] as String)['rows'] as List;
      for (final raw in military) {
        expect(byId.containsKey('${raw['COUR_CD']}-${raw['COUR_CLS']}'), false);
      }
      final mooc = read('source-mooc-official-operation-education.json') as Map;
      expect(mooc['sourceHeading'], '9. M');
      expect(byId['CCST301-00']['sourceEducationalMetadata']['MOOC_YN'], '1');
      expect(byId['CCST301-00']['schedules'], isEmpty);
      expect(byId['MOBI313-00']['schedules'], isEmpty);
      expect(byId['STAT180-01']['schedules'], isEmpty);
      expect(byId['STAT180-02']['schedules'], isNotEmpty);
      expect(byId['STAT180-02']['sourceEducationalMetadata']['MOOC_YN'], '0');
      expect(
        byId['STAT180-01']['sourceEducationalMetadata']['APPLY_DEPT'],
        '(MOOC 강의)',
      );
      for (final id in ['PAPP247-00', 'PAPP353-00']) {
        expect(byId[id]['schedules'], isEmpty);
      }

      final mon = byId['LIBT369-00']['schedules'] as List;
      expect(mon, isNotEmpty);
      for (final meeting in mon) {
        expect(meeting['weekday'], 1);
      }
      expect(independentScheduled, 1459);
      expect(independentMeetings, 40542);
      for (final id in [
        'BSMS206-00',
        'BSMS328-00',
        'BSMS426-00',
        'BMED326-00',
        'KHES239-00',
        'KHES338-00',
        'KHES443-00',
        'KLLE218-00',
      ]) {
        expect(byId[id]['schedules'], isEmpty);
      }
      final partial = byId['KHES414-00']['schedules'] as List;
      expect(partial, hasLength(28));
      for (final m in partial) {
        expect(m['startMinute'], isNot(900));
        expect(m['classroom'], '하나과학관 170호');
      }
    },
  );

  test(
    'Frozen Sejong22/18/701 remains independent and whole1712/1477/41243 real model all three modes fullDrive',
    () {
      final baseline =
          read('baseline-sejong22-18-701.json') as Map<String, dynamic>;
      expect(baseline['courses'], hasLength(22));
      expect(
        sha256
            .convert(
              fixtureFile(
                '${root}baseline-sejong22-18-701.json',
              ).readAsBytesSync(),
            )
            .toString(),
        read(
          'baseline-document-reference-independent-join-plan.json',
        )['baselineSHA256'],
      );
      expect(
        read(
          'baseline-document-reference-independent-join-plan.json',
        )['nativeOfferingAliasVerified'],
        false,
      );
      final models = [
        ...UniversityDataset.fromJson(dataset).courses,
        ...UniversityDataset.fromJson(baseline).courses,
      ];
      expect(models, hasLength(1712));
      expect(models.map((c) => c.sourceId).toSet(), hasLength(1712));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = models
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(before, hasLength(1477));
        final document = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final data = document.toJson();
        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
        ).materializeClasses();
        expect(after, hasLength(1477));
        final original = {for (final c in before) c.sourceId: c};
        var count = 0;
        for (final c in after) {
          final old = original[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, old.title);
          expect(c.professor, old.professor);
          expect(c.note, old.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            old.meetings.map((m) => m.toJson()).toList(),
          );
          count += c.meetings.length;
        }
        expect(count, 41243);
      }
    },
  );
}
