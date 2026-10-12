import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-r/ku/current-public-sejong-followup-v8-20261009/';
  dynamic read(String name) {
    final path = '$root$name';
    final data = jsonDecode(File(path).readAsStringSync());
    if (data is Map && data['courses'] is List) {
      for (final row in data['courses']) {
        if (row['metadata']?.containsKey('researchOnly') == true) {
          row['metadata']['researchOnly'] = false;
        }
      }
    }
    return data;
  }

  final dataset =
      read('korea-sejong-2026-2.current-native-reviewed-v8-20261009.json')
          as Map<String, dynamic>;
  final courses = dataset['courses'] as List;
  final baseline =
      read('baseline-sejong22-18-701.json') as Map<String, dynamic>;
  final seoul =
      read('baseline-seoul3612-reviewed-v7.json') as Map<String, dynamic>;
  final byId = {for (final c in courses) c['sourceId']: c};
  final scopes = read('source-captured-scope-config-open.json') as List;
  final calendar = read('current-own-sejong-calendar-education.json') as Map;
  final sourceRows = <String, Map>{};
  final sourceVariants = <String, List<Map>>{};

  test(
    'Own Sejong current regular UI table and calendar preserve campus scope and exam reservation distinction',
    () {
      final proof =
          read('source-sejong-own-current-calendar-department-guide-education-v1.json')
              as Map;
      final months = proof['calendars'] as List;
      expect(
        months[0]['nativeEducationalCalendarText'],
        contains('09.01 2026학년도 제2학기 개강'),
      );
      expect(
        months[1]['nativeEducationalCalendarText'],
        contains('10.20 ~ 10.26 제2학기 중간고사'),
      );
      expect(
        months[2]['nativeEducationalCalendarText'],
        contains('12.14 ~ 12.18 제2학기 기말고사'),
      );
      expect(
        months[2]['nativeEducationalCalendarText'],
        contains('12.18 제2학기 종강(16주차)'),
      );
      expect(proof['midtermNotice']['nativeText'], contains('별도의 휴강 없이'));
      expect(calendar['semesterStart'], '2026-09-01');
      expect(calendar['semesterEnd'], '2026-12-18');
      expect(calendar['midtermStart'], '2026-10-20');
      expect(calendar['midtermEnd'], '2026-10-26');
      expect(calendar['finalStart'], '2026-12-14');
      expect(calendar['finalEnd'], '2026-12-18');
      expect(calendar['holidays'], [
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      ]);
      for (final month in months) {
        expect(month['normalMonthPost']['year'], '2026');
      }
      expect(calendar['ordinaryReservationEndDerived'], '2026-12-13');
      final ui =
          read('source-current-ui-regular-campus-clock-education.json') as Map;
      expect(ui['selectedYear'], 2026);
      expect(ui['selectedSemester'], '2R');
      final table = ui['nativeTables'][0] as List;
      expect(table[0][1], '정규학기 (Regular Semester)');
      expect(table.last, ['13', '', '21:00~21:50', '']);
      final derived =
          read('current-own-sejong-regular-clock-education.json') as Map;
      expect(
        derived['sourceSHA256'],
        sha256
            .convert(
              File(
                '${root}source-current-ui-regular-campus-clock-education.json',
              ).readAsBytesSync(),
            )
            .toString(),
      );
      expect(derived['periods'], hasLength(14));
      for (final p in derived['periods'] as List) {
        expect(p['sourceLiteral'], table[(p['period'] as int) + 2][2]);
      }
      expect(dataset['completionClaim'], false);
    },
  );

  test(
    'Every current native header, identity and educational field independently preserved, no dictionary overwrite or private fields',
    () {
      for (final scope in scopes) {
        final source = read(scope['file'] as String) as Map;
        expect(
          sha256
              .convert(File('$root${scope['file']}').readAsBytesSync())
              .toString(),
          scope['sourceSHA256'],
        );
        expect(source['campus'] ?? source['selectedCampus'], '세종');
        expect(source['year'] ?? source['selectedYear'], 2026);
        expect(
          source['term'] ?? source['selectedSemester'],
          anyOf('2학기', '2R'),
        );
        expect(source['rows'], hasLength(scope['whole'] as int));
        expect(source['capturedRows'], scope['whole']);
        expect(source['displayedTotal'], scope['whole']);
        for (final raw in source['rows'] as List) {
          final id = '${raw['COUR_CD']}-${raw['COUR_CLS']}';
          sourceVariants.putIfAbsent(id, () => []).add(raw as Map);
          final prior = sourceRows[id];
          sourceRows.putIfAbsent(id, () => raw);
          expect(raw['CAMPUS'], '세종');
          expect(raw['YEAR'], '2026');
          expect(raw['TERM'], '2R');
          final c = byId['korea/sejong/2026-2/$id'];
          if (prior != null) {
            expect(c['sourceEducationalVariants'], contains(raw));
            expect(c['sourceQueryProvenance'], isNotEmpty);
            continue;
          }
          expect(c['sourceEducationalMetadata'], raw);
          expect(c['courseCode'], raw['COUR_CD']);
          expect(c['section'], raw['COUR_CLS']);
          expect(c['professor'], raw['PROF_NM']);
          expect(c['classification'], raw['ISU_NM']);
          expect(c['credits'], double.parse(raw['CREDIT'] as String));
          expect(c['sourceSchedule'], raw['TIME_ROOM']);
          expect(c['campus'], 'sejong');
          final first = (raw['COUR_NM'] as String).split('\n').first.trim();
          expect(
            '${c['courseName']}${(c['sourcePublishedBadges'] as List).join()}',
            first,
          );
          if (first.endsWith('FCDL')) {
            expect(c['sourcePublishedBadges'], ['FC', 'DL']);
            expect(c['remarks'], contains('LMS 사전학습'));
          }
          for (final badge in c['sourcePublishedBadges'] as List) {
            expect(['M', 'FC', 'T', 'NM', 'DL', 'ES'], contains(badge));
          }
          expect(
            RegExp(
              r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?:010|02|044|031)[- ]\d{3,4}[- ]\d{4}',
            ).hasMatch(raw['APPLY_DEPT'] as String),
            false,
          );
        }
      }
      expect(scopes, hasLength(61));
      expect(sourceRows, hasLength(1705));
      expect(courses, hasLength(1727));
      expect(
        courses.where((c) => (c['schedules'] as List).isNotEmpty).length,
        1421,
      );
      expect(
        courses.fold<int>(
          0,
          (count, c) => count + (c['schedules'] as List).length,
        ),
        49166,
      );
      expect(sourceRows.length + 22, courses.length);
      expect(byId.length, courses.length);
    },
  );

  test(
    'Current source native period-room blocks independently determine every reservation, preserving published breaks and exceptions',
    () {
      final table =
          read(
                'source-current-ui-regular-campus-clock-education.json',
              )['nativeTables'][0]
              as List;
      final clocks = <int, List<int>>{};
      for (final row in table.skip(2)) {
        final m = RegExp(
          r'^(\d{2}):(\d{2})~(\d{2}):(\d{2})$',
        ).firstMatch(row[2] as String);
        if (m != null) {
          clocks[int.parse(row[0] as String)] = [
            int.parse(m[1]!) * 60 + int.parse(m[2]!),
            int.parse(m[3]!) * 60 + int.parse(m[4]!),
          ];
        }
      }
      final closures =
          read('source-sejong-current-53-closure-education.json') as Map;
      expect(closures['rows'], hasLength(53));
      final closed = {
        for (final row in closures['rows'] as List)
          '${row['nativeCode']}-${row['nativeSection']}',
      };
      expect(closed, hasLength(53));
      for (final entry in sourceRows.entries) {
        final raw = entry.value;
        final id = entry.key;
        final c = byId['korea/sejong/2026-2/$id'];
        final note = raw['APPLY_DEPT'] as String;
        final conflictsFromOriginals = <String>{};
        for (final variant in sourceVariants[id]!.skip(1)) {
          for (final key in {...raw.keys, ...variant.keys}) {
            if (key != 'DEPARTMENT' && raw[key] != variant[key]) {
              conflictsFromOriginals.add(key as String);
            }
          }
        }
        if (sourceVariants[id]!.length > 1) {
          expect(
            (c['sourceCrossQueryConflicts'] as List).toSet(),
            conflictsFromOriginals,
          );
        }
        var held =
            [
              'PHAR528',
              'PHAR530',
              'PHAR532',
              'PHAR534',
              'PHAR536',
              'PHAR538',
              'PHAR540',
            ].contains(raw['COUR_CD']) ||
            conflictsFromOriginals.isNotEmpty ||
            raw['MOOC_YN'] == '1' ||
            closed.contains(id) ||
            note == '혼합수업' ||
            (note.contains('유연학기') &&
                (raw['FLEXIBLE_FR_DT'] == '' || raw['FLEXIBLE_TO_DT'] == ''));
        final slots = <Map<String, dynamic>>[];
        final allocation = <String, Set<String>>{};
        for (final line in (raw['TIME_ROOM'] as String).split('\n')) {
          final m = RegExp(
            r'^([월화수목금토일])\(([^)]+)\)\s+(.+)$',
          ).firstMatch(line.trim());
          if (m == null) {
            continue;
          }
          final day = '월화수목금토일'.indexOf(m[1]!) + 1;
          for (final part in m[2]!.split(',')) {
            final range = part.split(RegExp('[-~]')).map(int.parse).toList();
            if ([
              for (var period = range.first; period <= range.last; period++)
                period,
            ].any((period) => !clocks.containsKey(period))) {
              continue;
            }
            for (var period = range.first; period <= range.last; period++) {
              allocation.putIfAbsent('$day/$period', () => {}).add(m[3]!);
              slots.add({
                'weekday': day,
                'period': period,
                'startMinute': clocks[period]![0],
                'endMinute': clocks[period]![1],
                'classroom': m[3],
              });
            }
          }
        }
        final conflicts = allocation.entries
            .where((e) => e.value.length > 1)
            .map((e) => e.key)
            .toSet();
        final exact = slots
            .where((s) => !conflicts.contains('${s['weekday']}/${s['period']}'))
            .toList();
        if (exact.isEmpty) {
          held = true;
        }
        final start = raw['FLEXIBLE_FR_DT'] == ''
            ? calendar['semesterStart']
            : raw['FLEXIBLE_FR_DT'];
        final end = raw['FLEXIBLE_TO_DT'] == ''
            ? calendar['semesterEnd']
            : raw['FLEXIBLE_TO_DT'];
        expect(c['period'], {'startDate': start, 'endDate': end});
        final expected = <String>{};
        if (!held) {
          for (
            var date = DateTime.parse(start as String);
            date.compareTo(DateTime.parse(end as String)) <= 0 &&
                date.compareTo(
                      DateTime.parse(
                        calendar['ordinaryReservationEndDerived'] as String,
                      ),
                    ) <=
                    0;
            date = date.add(const Duration(days: 1))
          ) {
            final ds = date.toIso8601String().substring(0, 10);
            if ((calendar['holidays'] as List).contains(ds) ||
                (ds.compareTo(calendar['midtermStart'] as String) >= 0 &&
                    ds.compareTo(calendar['midtermEnd'] as String) <= 0)) {
              continue;
            }
            for (final s in exact) {
              if (s['weekday'] == date.weekday) {
                expected.add(
                  '$ds/${s['weekday']}/${s['startMinute']}/${s['endMinute']}/${s['classroom']}',
                );
              }
            }
          }
        }
        final actual = c['schedules'] as List;
        final signatures = {
          for (final s in actual)
            '${s['date']}/${s['weekday']}/${s['startMinute']}/${s['endMinute']}/${s['classroom']}',
        };
        expect(signatures, expected, reason: id);
        expect(actual.length, signatures.length);
        expect(c['actualAttendanceConfirmed'], false);
        expect(c['reservationOnly'], true);
        for (final s in actual) {
          expect(s.containsKey('deliveryMode'), false);
        }
      }
    },
  );

  test(
    'Frozen Seoul3612 and Sejong22 source identities remain deep unchanged without invented native document aliases',
    () {
      expect(
        sha256
            .convert(
              File(
                '${root}baseline-seoul3612-reviewed-v7.json',
              ).readAsBytesSync(),
            )
            .toString(),
        '58b6fe71fc497dbcbddbc775f5fb56cb7ef63a5ca90b12fe22b7357fe261605f',
      );
      expect(seoul['courses'], hasLength(3612));
      expect(baseline['courses'], hasLength(22));
      for (final c in baseline['courses'] as List) {
        expect(byId[c['sourceId']], c);
      }
      final audit =
          read('potential-old-document-native-alias-education-open.json')
              as Map;
      expect(audit['confirmedNativeAliases'], isEmpty);
      expect(audit['old22DeepMustRemain'], true);
    },
  );

  test(
    'Whole frozen Seoul and expanded Sejong actual model all three user modes fullDrive roundtrip',
    () {
      final models = [
        ...UniversityDataset.fromJson(seoul).courses,
        ...UniversityDataset.fromJson(dataset).courses,
      ];
      expect(models, hasLength(5339));
      expect(models.map((c) => c.sourceId).toSet().length, models.length);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = models
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(before, hasLength(4029));
        expect(
          before.fold<int>(0, (count, c) => count + c.meetings.length),
          121627,
        );
        final json = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        ).toJson();

        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        ).materializeClasses();
        expect(after.length, before.length);
        final original = {for (final c in before) c.sourceId: c};
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
        }
      }
    },
  );
}
