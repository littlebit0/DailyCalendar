// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const root = 'work/university-research/catalog-g';
const directory = '$root/conditional-operating-followup-v4-20261009';
Map<String, dynamic> read(String path) {
  final actual = path.startsWith('$directory/gachon-')
      ? 'work/university-research/resume-batch-20261010/before-projection/${path.split('/').last}'
      : path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  for (final row in data['courses'] ?? []) {
    if (row['metadata']?.containsKey('researchOnly') == true) {
      row['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  test(
    'all 571 reviewed; 201 partial or regular plans preserve native whole and all-mode Drive',
    () {
      final audit = read('$directory/source-operating-audit.json');
      final originalReports =
          read('$root/gachon-full-operating-report-audit.json')['reports']
              as List;
      final currentClock =
          read(
                '$root/gachon-current-scope-clock-term-manifest.json',
              )['clock50minPeriods']
              as Map;
      final expectedWeeks = <String, List<int>>{
        '60000087': [],
        '61475001': [4, 6],
        'K0025004': [14],
        '08382001': [14],
        '09804001': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804002': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804003': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804004': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804005': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804006': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804007': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804008': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804009': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804010': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804011': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804012': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804013': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804014': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804015': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804016': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804017': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804018': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804019': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804020': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804021': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804022': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804023': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804025': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804026': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804027': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804028': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804029': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '09804030': [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        '60015001': [4, 6],
        '61488001': [4, 6],
        '12195001': [14],
        '13454001': [14],
        '13613002': [2, 3, 4, 6],
        '14699001': [4, 6],
        '14704001': [8, 15],
        '14794001': [14],
        '14794002': [14],
        '15288001': [4],
        '15759006': [14],
        '60000039': [],
        '60000049': [13],
        '60000070': [],
        '60000085': [],
        '60000086': [],
        '60000088': [],
        '61142001': [],
        '61142002': [],
        '61142005': [],
        '61285001': [],
        '61330001': [4],
        '61330005': [4, 6, 12],
        '61559004': [],
        'BL002001': [13],
        '07919001': [14],
        '11752001': [],
        '12529001': [],
        '12589001': [2, 13],
        '12787001': [5, 13],
        '13108001': [],
        '13121003': [5],
        '13216004': [],
        '13377001': [13],
        '13419001': [8],
        '13698001': [],
        '13698002': [],
        '13700001': [7, 13],
        '13700006': [2],
        '13763003': [],
        '13764001': [],
        '13768001': [4, 8],
        '13768002': [4, 8],
        '13768003': [4, 8],
        '13769002': [4, 13],
        '13824001': [],
        '13829002': [],
        '13832001': [8],
        '13833001': [4, 15],
        '13917002': [4],
        '13955001': [10, 13],
        '14003002': [1],
        '14072001': [7, 14],
        '14072002': [7, 14],
        '14121001': [],
        '14153001': [12],
        '14167001': [12, 13, 14],
        '14189001': [4],
        '14199001': [10],
        '14416001': [15],
        '14416002': [15],
        '14418001': [13],
        '14418003': [13],
        '14449001': [],
        '14465003': [],
        '14479001': [13],
        '14479002': [13],
        '14487001': [9],
        '14503001': [4],
        '14528001': [],
        '14530001': [14],
        '14552001': [3],
        '14642001': [14],
        '14786001': [14],
        '14786002': [14],
        '14786003': [14],
        '14801003': [4],
        '14819001': [14, 15],
        '14837001': [],
        '14850001': [4, 6],
        '14853005': [],
        '14896001': [15],
        '15038001': [5, 9, 13],
        '15086001': [4],
        '15091001': [4, 6],
        '15117001': [14, 15],
        '15219001': [],
        '15219002': [],
        '15224001': [],
        '15224002': [],
        '15256003': [13],
        '15256004': [13],
        '15269001': [],
        '15269002': [],
        '15428001': [7],
        '15457001': [9],
        '15515001': [4],
        '15550001': [],
        '15618001': [5],
        '15695002': [15],
        '15704001': [1, 7, 14],
        '15747001': [4],
        '15750001': [],
        '15832003': [13, 14],
        '15834002': [4],
        '15834003': [5, 13],
        '15873001': [],
        '15892001': [13],
        '61009001': [9],
        '61009003': [9],
        '61066001': [],
        '61146001': [],
        '61154001': [],
        '61170001': [5],
        '61170002': [],
        '61173001': [],
        '61241001': [5, 11],
        '61270001': [5],
        '61274001': [6],
        '61310001': [5],
        '61310002': [5],
        '61314001': [4],
        '61314002': [12],
        '61322001': [5],
        '61322002': [4],
        '61329003': [4, 6],
        '61331002': [],
        '61334001': [],
        '61354004': [4, 6],
        '61354006': [],
        '61395001': [4, 6],
        '61395002': [4, 6],
        '61414001': [],
        '61420001': [4],
        '61447001': [],
        '61454001': [],
        '61476001': [],
        '61476002': [],
        '61481001': [],
        '61497001': [],
        '61517001': [],
        '61517002': [],
        '61532001': [9],
        '61541001': [5, 6, 12],
        '61541002': [5, 6, 12],
        '61577001': [],
        '61582002': [10],
        '61584002': [],
        '61588001': [],
        '61671001': [],
        '61674001': [4],
        '61679001': [],
        'AIB04001': [],
        'AIB06001': [],
        'K0061001': [],
        'K0062002': [],
        'K0064001': [8],
        'K0065001': [14],
        'K0065002': [14],
        '13920001': [9],
        '13920002': [9],
        '61137001': [5],
        'M3481001': [4],
        'M3481002': [4],
        'M3840001': [8],
        'M3840002': [8],
        '14598002': [],
        '14949003': [],
      };
      final expectedDates = <String, List<String>>{
        '13454001': ['2026-12-01'],
        '60000070': ['2026-11-30', '2026-12-01'],
        '61330001': ['2026-09-17', '2026-10-01'],
        '13824001': ['2026-12-01'],
      };
      final promoted = {
        for (final item in audit['promoted'] as List)
          (item as Map)['sourceId'] as String: item,
      };
      final before = <String, Map<String, dynamic>>{};
      final after = <String, Map<String, dynamic>>{};
      final models = <UniversityCourse>[];
      for (final campus in ['global', 'medical']) {
        final prior = read(
          '$root/conditional-operating-followup-v3-20261009/gachon-$campus-2026-2.json',
        );
        final current = read('$directory/gachon-$campus-2026-2.json');
        for (final row in prior['courses'] as List) {
          final raw = Map<String, dynamic>.from(row as Map);
          before[raw['sourceId'] as String] = raw;
        }
        for (final row in current['courses'] as List) {
          final raw = Map<String, dynamic>.from(row as Map);
          after[raw['sourceId'] as String] = raw;
        }
        models.addAll(UniversityDataset.fromJson(current).courses);
      }
      expect(after.keys.toSet(), before.keys.toSet());
      expect(after.length, 3809);
      expect(promoted.length, 201);
      var unchanged = 0;
      var oldDated = 0;
      var newDated = 0;
      for (final entry in after.entries) {
        final previous = before[entry.key]!;
        oldDated += (previous['schedules'] as List).length;
        final proof = promoted[entry.key];
        if (proof == null) {
          expect(entry.value, previous);
          unchanged++;
          continue;
        }
        expect(previous['scheduleStatus'], 'unrecognized');
        expect(previous['schedules'], isEmpty);
        final raw = entry.value;
        for (final field in [
          'sourceId',
          'universityId',
          'campus',
          'academicYear',
          'semester',
          'courseCode',
          'section',
          'courseName',
          'professor',
          'credits',
          'sourceSchedule',
          'sourceClassroom',
          'departments',
          'departmentCredits',
          'departmentClassifications',
          'period',
        ]) {
          expect(raw[field], previous[field], reason: '${entry.key} $field');
        }
        expect(raw['sourceDepartmentRemarks'], previous['departmentRemarks']);
        final report = proof['report'] as Map;
        final source = report['sourceRow'] as Map;
        final original = originalReports.singleWhere(
          (r) =>
              (r as Map)['campus'] ==
                  (raw['campus'] == 'global' ? '20' : '21') &&
              (r['sourceRow'] as Map)['HAKSU_NO'] == source['HAKSU_NO'],
        );
        expect(report, original);
        final offering = source['HAKSU_NO'] as String;
        expect(source['HAKSU_NO'], '${raw['courseCode']}${raw['section']}');
        expect(source['PROFNM'], raw['professor']);
        expect(source['LOC_NM'] ?? '', raw['sourceClassroom']);
        expect(source['CYBER_YN'], isNull);
        final identity = report['report'] as Map;
        expect(identity['headerCourseCodeMatches'], isTrue);
        expect(identity['currentTermMatches'], isTrue);
        expect(identity['catalogProfessorAppearsInReport'], isTrue);
        expect(report['potentialDifferentTermStatement'], isFalse);
        final rules = proof['rule'] as Map;
        expect(rules['omitWeeks'], expectedWeeks[offering] ?? <int>[]);
        expect(rules['heldDates'], expectedDates[offering] ?? <String>[]);
        final rawSlots = RegExp(
          r'([월화수목금토일])([0-9]+)',
        ).allMatches(source['TIME'] as String).toList();
        const days = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
        final independentlyParsedBlocks = <Map<String, dynamic>>[];
        for (final weekday in [1, 2, 3, 4, 5, 6, 7]) {
          final numbers =
              rawSlots
                  .where((m) => days[m.group(1)] == weekday)
                  .map((m) => int.parse(m.group(2)!))
                  .toList()
                ..sort();
          final runs = <List<int>>[];
          for (final number in numbers) {
            if (runs.isEmpty || number != runs.last.last + 1) {
              runs.add(<int>[]);
            }
            runs.last.add(number);
          }
          for (final run in runs) {
            independentlyParsedBlocks.add({
              'weekday': weekday,
              'startMinute':
                  (currentClock[run.first.toString()] as Map)['startMinute'],
              'endMinute':
                  (currentClock[run.last.toString()] as Map)['endMinute'],
              'classroom': source['LOC_NM'] ?? '',
            });
          }
        }
        expect(
          (proof['originalClockBlocks'] as List).map((value) {
            final block = Map<String, dynamic>.from(value as Map);
            block.remove('firstPeriod');
            block.remove('lastPeriod');
            return block;
          }).toList(),
          independentlyParsedBlocks,
          reason: offering,
        );
        final held = Set<String>.from(rules['heldDates'] as List);
        final omitted = Set<int>.from(rules['omitWeeks'] as List);
        final periods = report['weeklyRows'] as List;
        expect(periods.length, anyOf(4, 5, 12, 15));
        final ownPeriod = raw['period'] as Map;
        final firstPrinted = (periods.first as Map)['startMonthDay'] as String;
        final lastPrinted = (periods.last as Map)['endMonthDay'] as String;
        DateTime printedDate(String value) {
          final parts = value.split('/').map(int.parse).toList();
          return DateTime(2026, parts[0], parts[1]);
        }

        expect(
          DateTime.parse(
            ownPeriod['startDate'] as String,
          ).isBefore(printedDate(firstPrinted)),
          isFalse,
        );
        expect(
          DateTime.parse(ownPeriod['endDate'] as String),
          printedDate(lastPrinted),
        );
        final expected = <Map<String, dynamic>>[];
        for (
          var date = DateTime.parse(ownPeriod['startDate'] as String);
          !date.isAfter(DateTime.parse(ownPeriod['endDate'] as String));
          date = date.add(const Duration(days: 1))
        ) {
          final day = date.toIso8601String().substring(0, 10);
          final week =
              (periods.singleWhere((value) {
                        final weekRow = value as Map;
                        return !date.isBefore(
                              printedDate(weekRow['startMonthDay'] as String),
                            ) &&
                            !date.isAfter(
                              printedDate(weekRow['endMonthDay'] as String),
                            );
                      })
                      as Map)['week']
                  as int;
          if (held.contains(day) ||
              omitted.contains(week) ||
              {
                '2026-09-24',
                '2026-09-25',
                '2026-09-26',
                '2026-10-03',
                '2026-10-05',
                '2026-10-09',
              }.contains(day)) {
            continue;
          }
          for (final block in proof['originalClockBlocks'] as List) {
            if ((block as Map)['weekday'] == date.weekday) {
              expected.add({
                'weekday': date.weekday,
                'startMinute': block['startMinute'],
                'endMinute': block['endMinute'],
                'classroom': block['classroom'],
                'date': day,
              });
            }
          }
        }
        expect(raw['schedules'], expected);
        newDated += expected.length;
        expect(
          (raw['sourceEducation'] as Map)['actualAttendanceConfirmed'],
          isFalse,
        );
        expect(expected.every((m) => !m.containsKey('deliveryMode')), isTrue);
      }
      expect(unchanged, 3608);
      expect(oldDated, 55027);
      expect(newDated, 2956);
      expect(models.where((c) => c.meetings.isNotEmpty).length, 3435);
      expect(
        after.values.fold<int>(
          0,
          (sum, c) => sum + (c['schedules'] as List).length,
        ),
        57983,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        final savedByKey = <String, TimetableClass>{};
        for (final course in models.where((c) => c.meetings.isNotEmpty)) {
          final saved = course.toTimetable(id: course.sourceId, mode: mode);
          final key = timetableCourseSyncKey(saved);
          savedByKey[key] = saved;
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'gachon-source-only-fixture',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())),
        );
        expect(restored.courses.length, 3435);
        for (final entry in savedByKey.entries) {
          final actual = TimetableClass.fromJson(
            Map<String, dynamic>.from(
              restored.courses[entry.key]!.value as Map,
            ),
          );
          final expected = {...entry.value.toJson(), 'id': entry.key};
          expect(actual.toJson(), expected);
          expect(actual.defaultMode, mode);
        }
      }
    },
  );
}
