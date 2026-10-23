import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-r/ku/current-public-broad-followup-v3-20261009/';
  dynamic read(String name) =>
      jsonDecode(fixtureFile('$root$name').readAsStringSync());
  final source = read('source-nursing53-education.json') as Map;
  final dataset =
      read('korea-seoul-2026-2.current-native-reviewed-v3-20261009.json')
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
      expect(byId, hasLength(881));
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
    '881 current source-native rows,434 frozen originals and independent new operating exceptions/clocks/dates',
    () {
      final baseline =
          read('baseline-seoul434-reviewed-v2.json')['courses'] as List;
      final old = {
        for (final c in baseline) '${c['courseCode']}-${c['section']}': c,
      };
      const reviewed = {
        'BUSS205-01',
        'BUSS342-01',
        'NEIK212-00',
        'NEIK242-00',
        'ACEE231-00',
      };
      final sourceIds = <String>{};
      var rawCount = 0;
      for (final scope in read('source-captured-scope-config.json') as List) {
        final raw = read(scope['file'] as String) as Map;
        expect(raw['selectedYear'], 2026);
        expect(raw['selectedSemester'], '2R');
        expect(raw['selectedCampus'], '서울');
        expect(raw['rows'], hasLength(scope['whole'] as int));
        expect(
          sha256
              .convert(fixtureFile('$root${scope['file']}').readAsBytesSync())
              .toString(),
          scope['sourceSHA256'],
        );
        for (final r in raw['rows'] as List) {
          final id = '${r['COUR_CD']}-${r['COUR_CLS']}';
          expect(sourceIds.add(id), true);
          final c = byId[id];
          expect(c['sourceEducationalMetadata'], r);
          expect(c['courseCode'], r['COUR_CD']);
          expect(c['section'], r['COUR_CLS']);
          expect(c['professor'], r['PROF_NM']);
          expect(c['classification'], r['ISU_NM']);
          expect(c['credits'], double.parse(r['CREDIT'] as String));
          expect(c['campus'], 'seoul');
          if (old.containsKey(id)) {
            if (!reviewed.contains(id)) {
              expect(c, old[id]);
            } else {
              expect(old[id]['schedules'], isEmpty);
              expect(
                c['sourceReviewedOperatingHoldChange']['priorRemarks'],
                old[id]['remarks'],
              );
              const changed = {
                'schedules',
                'scheduleStatus',
                'remarks',
                'sourceOperatingHolds',
                'sourcePartialCoverage',
                'sourcePerBlockHolds',
              };
              for (final key in (old[id] as Map).keys) {
                if (!changed.contains(key)) {
                  expect(c[key], old[id][key]);
                }
              }
            }
          }
          rawCount++;
        }
      }
      expect(rawCount, 881);
      expect(sourceIds, hasLength(881));
      expect(old, hasLength(434));
      expect(
        old.values.where((c) => (c['schedules'] as List).isNotEmpty),
        hasLength(351),
      );
      expect(
        old.values.fold<int>(0, (n, c) => n + (c['schedules'] as List).length),
        9462,
      );

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
      const sourcePartials = {
        'ARCH106-01',
        'ARCH106-02',
        'ARCH106-03',
        'SEMI110-00',
        'ECOC424-00',
      };
      var independentlyScheduled = 0;
      var independentMeetings = 0;
      for (final scope in read('source-captured-scope-config.json') as List) {
        for (final r in read(scope['file'] as String)['rows'] as List) {
          final id = '${r['COUR_CD']}-${r['COUR_CLS']}';
          if (old.containsKey(id) && !reviewed.contains(id)) {
            independentlyScheduled += (old[id]['schedules'] as List).isEmpty
                ? 0
                : 1;
            independentMeetings += (old[id]['schedules'] as List).length;
            continue;
          }
          final c = byId[id];
          final note = r['APPLY_DEPT'] as String;
          var held =
              r['MOOC_YN'] == '1' ||
              (r['COUR_NM'] as String).split('\n').first.endsWith('M') &&
                  r['NEMO_YN'] != '1';
          held =
              held ||
              note == '혼합수업' ||
              note.contains('일정-') ||
              (note.contains('유연학기') &&
                  (r['FLEXIBLE_FR_DT'] == '' || r['FLEXIBLE_TO_DT'] == ''));
          String? remarkedRoom;
          final normalized = note.replaceFirst(RegExp(r'^[(*★※\s]*'), '');
          if (normalized.startsWith('강의실:') || normalized.startsWith('강의실 :')) {
            final match = RegExp(
              r'강의실\s*:\s*([^<>\n]*?\d+[A-Z]?호(?:\([^)]*\))?)',
            ).firstMatch(normalized);
            if (match != null &&
                RegExp(r'\d+[A-Z]?호').allMatches(normalized).length == 1) {
              remarkedRoom = match[1]!.trim();
            }
          }
          if (['MECH460-00', 'MECH485-00'].contains(id)) {
            remarkedRoom = note;
          }
          final sourceRoomKeys = <String, String>{};
          var segments = <Map<String, dynamic>>[];
          var partialBlock = false;
          for (final line in (r['TIME_ROOM'] as String).split('\n')) {
            var text = line.trim();
            if (RegExp(r'^[월화수목금토일]\([^)]+\)$').hasMatch(text) &&
                remarkedRoom != null) {
              text = '$text $remarkedRoom';
            }
            final allocation = RegExp(
              r'^([월화수목금토일])\(([^)]+)\)\s+(.+)$',
            ).firstMatch(text);
            if (allocation == null) {
              if (!sourcePartials.contains(id)) {
                held = true;
              }
              continue;
            }
            final weekday = '월화수목금토일'.indexOf(allocation[1]!) + 1;
            for (final part in allocation[2]!.split(',')) {
              final bounds = part.split(RegExp('[-~]')).map(int.parse).toList();
              for (var p = bounds.first; p <= bounds.last; p++) {
                if (!table.containsKey(p)) {
                  if (['KISE402-00', 'KISE408-00'].contains(id) &&
                      p == 11 &&
                      bounds.length == 1) {
                    partialBlock = true;
                  } else {
                    held = true;
                  }
                  continue;
                }
                final key = '$weekday/$p';
                if (sourceRoomKeys.containsKey(key) &&
                    sourceRoomKeys[key] != allocation[3]) {
                  held = true;
                }
                sourceRoomKeys[key] = allocation[3]!;
                segments.add({
                  'weekday': weekday,
                  'start': table[p]![0],
                  'end': table[p]![1],
                  'room': allocation[3],
                });
              }
            }
          }
          if (['DISS241-00', 'GKSS202-00'].contains(id)) {
            final direct = RegExp(
              r'강의\s*시간\s*:\s*(\d{1,2}):(\d{2})\s*~\s*(\d{1,2}):(\d{2})',
            ).firstMatch(note)!;
            expect(segments.map((s) => s['weekday']).toSet(), hasLength(1));
            expect(segments.map((s) => s['room']).toSet(), hasLength(1));
            expect(segments.last['end'], 1190);
            final first = segments.first;
            final start = int.parse(direct[1]!) * 60 + int.parse(direct[2]!);
            final end = int.parse(direct[3]!) * 60 + int.parse(direct[4]!);
            expect([start, end], [990, 1130]);
            expect(c['sourceClockOverrideProof']['sourceText'], direct[0]);
            segments = [
              {
                'weekday': first['weekday'],
                'start': start,
                'end': end,
                'room': first['room'],
              },
            ];
          }
          if (segments.isEmpty) {
            held = true;
          }
          if (held) {
            expect(c['schedules'], isEmpty, reason: id);
            continue;
          }
          if (partialBlock) {
            expect(c['sourcePartialCoverage'], true);
            expect(c['sourcePerBlockHolds'], hasLength(1));
            expect(c['sourcePerBlockHolds'][0]['sourcePeriods'], [11]);
            expect(segments, hasLength(2));
          }
          final start = r['FLEXIBLE_FR_DT'] == ''
              ? '2026-09-01'
              : r['FLEXIBLE_FR_DT'] as String;
          final end = r['FLEXIBLE_TO_DT'] == ''
              ? '2026-12-18'
              : r['FLEXIBLE_TO_DT'] as String;
          expect(c['period'], {'startDate': start, 'endDate': end});
          final expected = <String>{};
          for (
            var date = DateTime.parse(start);
            !date.isAfter(DateTime.parse(end)) &&
                !date.isAfter(DateTime(2026, 12, 13));
            date = date.add(const Duration(days: 1))
          ) {
            final ds = date.toIso8601String().substring(0, 10);
            if ((calendar['holidays'] as List).contains(ds) ||
                ds.compareTo('2026-10-20') >= 0 &&
                    ds.compareTo('2026-10-26') <= 0) {
              continue;
            }
            for (final segment in segments) {
              if (date.weekday == segment['weekday']) {
                expected.add(
                  '$ds/${date.weekday}/${segment['start']}/${segment['end']}/${segment['room']}',
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
          expect(actual, expected, reason: id);
          expect(actual, hasLength((c['schedules'] as List).length));
          independentlyScheduled++;
          independentMeetings += actual.length;
        }
      }
      expect(independentlyScheduled, 788);
      expect(independentMeetings, 21621);
      expect(byId['SOCI347-00']['sourceClassroom'], '서관B110호');
      expect(byId['JAPN368-00']['sourceClassroom'], '서관 224A호');
      expect(byId['JAPN482-00']['sourceClassroom'], '서관 224A호');
      expect(byId['CHIN206-01']['credits'], 3);
      final operation =
          read('source-fc-nemo-official-operation-education.json') as Map;
      expect(operation['privateLmsNotAccessed'], true);
      expect(
        operation['interpretation']['sourcePublicationDate'],
        contains('undated'),
      );
      for (final id in reviewed) {
        expect(byId[id]['schedules'], isNotEmpty);
        for (final m in byId[id]['schedules'] as List) {
          expect(m.containsKey('deliveryMode'), false);
        }
      }
      for (final id in [
        'ACEE232-00',
        'ACEE282-03',
        'ACEE308-00',
        'ACEE325-00',
        'KMSE405-00',
        'SEMI405-00',
        'SEMI406-00',
      ]) {
        expect(byId[id]['schedules'], isEmpty);
      }
    },
  );

  test(
    'Frozen Sejong22/18/701 remains independent and whole903/806/22322 real model all three modes fullDrive',
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
      expect(models, hasLength(903));
      expect(models.map((c) => c.sourceId).toSet(), hasLength(903));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = models
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(before, hasLength(806));
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
        expect(after, hasLength(806));
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
        expect(count, 22322);
      }
    },
  );
}
