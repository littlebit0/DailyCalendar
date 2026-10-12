import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-r/ku/current-whole-public-followup-v2-20261009/';
  // Historical v2 source checks remain frozen; v3 product checks are separate.
  dynamic read(String name) => jsonDecode(File('$root$name').readAsStringSync());
  final source = read('source-nursing53-education.json') as Map;
  final dataset =
      read('korea-seoul-2026-2.nursing-native53-reviewed-v2-20261009.json')
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
              File(
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
      expect(byId, hasLength(53));
      expect(
        sha256
            .convert(
              File('${root}source-nursing53-education.json').readAsBytesSync(),
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
    'All current standard source rows independently preserve exact clock breaks room/day partials and actual operational holds',
    () {
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
      final clock = read('current-2026-2-campus-clock-education.json') as Map;
      for (final r in clock['seoul'] as List) {
        expect([r['startMinute'], r['endMinute']], table[r['period']]);
      }
      const partials = {
        'ARCH106-01',
        'ARCH106-02',
        'ARCH106-03',
        'SEMI110-00',
        'ECOC424-00',
      };
      final wholeIds = <String>{};
      for (final scope
          in read('standard-source-independent-scope-config.json') as List) {
        final slug = scope['slug'];
        final n = scope['count'];
        final sourceName = 'source-$slug$n-education.json';
        final raw = read(sourceName) as Map;
        final candidate =
            read('korea-seoul-2026-2.$slug-native$n-reviewed-v2-20261009.json')
                as Map;
        final mapped = {
          for (final c in candidate['courses'] as List)
            '${c['courseCode']}-${c['section']}': c,
        };
        expect(raw['selectedYear'], 2026);
        expect(raw['selectedSemester'], '2R');
        expect(raw['selectedCampus'], '서울');
        expect(raw['rows'], hasLength(n as int));
        expect(mapped, hasLength(n));
        expect(
          sha256.convert(File('$root$sourceName').readAsBytesSync()).toString(),
          scope['sourceSHA256'],
        );
        expect(candidate['completionClaim'], false);
        var scheduled = 0;
        var dates = 0;
        for (final row in raw['rows'] as List) {
          final identity = '${row['COUR_CD']}-${row['COUR_CLS']}';
          expect(
            wholeIds.add(identity),
            true,
            reason: 'Native cross-query ambiguity must not be overwritten',
          );
          final c = mapped[identity];
          expect(c['sourceEducationalMetadata'], row);
          expect(c['courseCode'], row['COUR_CD']);
          expect(c['section'], row['COUR_CLS']);
          expect(c['professor'], row['PROF_NM']);
          expect(c['credits'], double.parse(row['CREDIT'] as String));
          expect(c['classification'], row['ISU_NM']);
          expect(c['reservationOnly'], true);
          expect(c['actualAttendanceConfirmed'], false);
          final title = (row['COUR_NM'] as String).split('\n').first.trim();
          var hold =
              title.endsWith('FC') ||
              title.endsWith('NM') ||
              row['APPLY_DEPT'] == '혼합수업' ||
              (row['APPLY_DEPT'] as String).contains('일정-') ||
              ((row['APPLY_DEPT'] as String).contains('유연학기') &&
                  (row['FLEXIBLE_FR_DT'] == '' || row['FLEXIBLE_TO_DT'] == ''));
          var remarkRoom = '';
          if (['MECH460', 'MECH485'].contains(row['COUR_CD'])) {
            remarkRoom = row['APPLY_DEPT'] as String;
          }
          final roomRemark = RegExp(
            r'^강의실\s*:\s*([^<>\n]+)$',
          ).firstMatch((row['APPLY_DEPT'] as String).trim());
          if (roomRemark != null) {
            remarkRoom = roomRemark[1]!.trim();
          }
          final segments = <String>{};
          final nativeRooms = <String, String>{};
          for (final line in (row['TIME_ROOM'] as String).split('\n')) {
            var text = line.trim();
            if (RegExp(r'^[월화수목금토일]\([^)]+\)$').hasMatch(text) &&
                remarkRoom.isNotEmpty) {
              text = '$text $remarkRoom';
            }
            final match = RegExp(
              r'^([월화수목금토일])\(([^)]+)\)\s+(.+)$',
            ).firstMatch(text);
            if (match == null) {
              if (!partials.contains(identity)) {
                hold = true;
              }
              continue;
            }
            final day = '월화수목금토일'.indexOf(match[1]!) + 1;
            for (final part in match[2]!.split(',')) {
              final range = part.split(RegExp('[-~]')).map(int.parse).toList();
              for (var p = range.first; p <= range.last; p++) {
                final key = '$day/$p';
                if (nativeRooms.containsKey(key) &&
                    nativeRooms[key] != match[3]) {
                  hold = true;
                }
                nativeRooms[key] = match[3]!;
                if (!table.containsKey(p)) {
                  hold = true;
                  continue;
                }
                segments.add(
                  '$day/${table[p]![0]}/${table[p]![1]}/${match[3]}',
                );
              }
            }
          }
          if (segments.isEmpty) {
            hold = true;
          }
          if (hold) {
            expect(c['schedules'], isEmpty, reason: identity);
            continue;
          }
          if (partials.contains(identity)) {
            expect(c['sourcePartialCoverage'], true);
            expect(c['sourcePerDayHolds'], hasLength(1));
            if (identity.startsWith('ARCH106')) {
              expect(segments.every((v) => v.startsWith('5/')), true);
              expect(c['sourcePerDayHolds'][0]['weekday'], 2);
            } else if (identity == 'SEMI110-00') {
              expect(segments.every((v) => v.startsWith('1/')), true);
              expect(c['sourcePerDayHolds'][0]['weekday'], 2);
            } else {
              expect(segments.every((v) => v.startsWith('4/')), true);
              expect(c['sourcePerDayHolds'][0]['weekday'], isNull);
            }
          }
          final start = row['FLEXIBLE_FR_DT'] == ''
              ? '2026-09-01'
              : row['FLEXIBLE_FR_DT'] as String;
          final end = row['FLEXIBLE_TO_DT'] == ''
              ? '2026-12-18'
              : row['FLEXIBLE_TO_DT'] as String;
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
                (ds.compareTo('2026-10-20') >= 0 &&
                    ds.compareTo('2026-10-26') <= 0)) {
              continue;
            }
            for (final segment in segments) {
              if (segment.startsWith('${date.weekday}/')) {
                expected.add('$ds/$segment');
              }
            }
          }
          final actual = (c['schedules'] as List)
              .map(
                (m) =>
                    '${m['date']}/${m['weekday']}/${m['startMinute']}/${m['endMinute']}/${m['classroom']}',
              )
              .toSet();
          expect(actual, expected, reason: identity);
          expect(actual, hasLength((c['schedules'] as List).length));
          scheduled++;
          dates += actual.length;
        }
        expect(scheduled, scope['scheduled']);
        expect(dates, scope['meetings']);
      }
      expect(wholeIds, hasLength(381));
    },
  );

  test(
    'Frozen Sejong22/18/701 remains independent and whole456/369/10163 real model all three modes fullDrive',
    () {
      final baseline =
          read('baseline-sejong22-18-701.json') as Map<String, dynamic>;
      expect(baseline['courses'], hasLength(22));
      expect(
        sha256
            .convert(
              File('${root}baseline-sejong22-18-701.json').readAsBytesSync(),
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
        for (final scope
            in read('standard-source-independent-scope-config.json') as List)
          ...UniversityDataset.fromJson(
            read(
                  'korea-seoul-2026-2.${scope['slug']}-native${scope['count']}-reviewed-v2-20261009.json',
                )
                as Map<String, dynamic>,
          ).courses,
        ...UniversityDataset.fromJson(baseline).courses,
      ];
      expect(models, hasLength(456));
      expect(models.map((c) => c.sourceId).toSet(), hasLength(456));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = models
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(before, hasLength(369));
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
        expect(after, hasLength(369));
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
        expect(count, 10163);
      }
    },
  );
}
