import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const root = 'work/university-research/catalog-g';
const directory = '$root/conditional-operating-followup-v2-20261009';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  for (final row in data['courses'] ?? []) {
    if (row['metadata']?.containsKey('researchOnly') == true) {
      row['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  test('current 28 partial plans preserve native whole and all-mode Drive', () {
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
      '12570002': [13],
      '15256001': [13],
      '15256002': [13],
      'K0003001': [14],
      'K0003002': [14],
      'K0003003': [14],
      'K0023001': [13],
      'K0026001': [14],
      'K0107001': [14],
      'M3853001': [8, 15],
    };
    final expectedDates = <String, List<String>>{
      '12570001': ['2026-11-30', '2026-12-01'],
      '13455001': ['2026-12-01'],
      '13713001': ['2026-11-30', '2026-12-01'],
      '14079001': ['2026-11-30'],
      '14079002': ['2026-11-30'],
      '14516001': ['2026-11-29', '2026-11-30', '2026-12-01'],
      '15184003': ['2026-11-30', '2026-12-01'],
      '15184004': ['2026-12-01'],
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
        '$root/conditional-operating-followup-v1-20261009/gachon-$campus-2026-2.json',
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
    expect(promoted.length, 28);
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
            (r as Map)['campus'] == (raw['campus'] == 'global' ? '20' : '21') &&
            (r['sourceRow'] as Map)['HAKSU_NO'] == source['HAKSU_NO'],
      );
      expect(report, original);
      final offering = source['HAKSU_NO'] as String;
      expect(source['HAKSU_NO'], '${raw['courseCode']}${raw['section']}');
      expect(source['PROFNM'], raw['professor']);
      expect(source['LOC_NM'], raw['sourceClassroom']);
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
      for (final block in proof['originalClockBlocks'] as List) {
        final sameDay =
            rawSlots
                .where((m) => days[m.group(1)] == (block as Map)['weekday'])
                .map((m) => int.parse(m.group(2)!))
                .toList()
              ..sort();
        expect(sameDay, isNotEmpty);
        expect(
          block['startMinute'],
          (currentClock[sameDay.first.toString()] as Map)['startMinute'],
        );
        expect(
          block['endMinute'],
          (currentClock[sameDay.last.toString()] as Map)['endMinute'],
        );
        expect(block['classroom'], source['LOC_NM']);
      }
      final held = Set<String>.from(rules['heldDates'] as List);
      final omitted = Set<int>.from(rules['omitWeeks'] as List);
      final periods = report['weeklyRows'] as List;
      expect(periods.length, 15);
      final expected = <Map<String, dynamic>>[];
      for (
        var date = DateTime(2026, 9, 1);
        !date.isAfter(DateTime(2026, 12, 14));
        date = date.add(const Duration(days: 1))
      ) {
        final day = date.toIso8601String().substring(0, 10);
        final week = date.difference(DateTime(2026, 9, 1)).inDays ~/ 7 + 1;
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
    expect(unchanged, 3781);
    expect(oldDated, 54202);
    expect(newDated, 664);
    expect(models.where((c) => c.meetings.isNotEmpty).length, 3225);
    expect(
      after.values.fold<int>(
        0,
        (sum, c) => sum + (c['schedules'] as List).length,
      ),
      54866,
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
      expect(restored.courses.length, 3225);
      for (final entry in savedByKey.entries) {
        final actual = TimetableClass.fromJson(
          Map<String, dynamic>.from(restored.courses[entry.key]!.value as Map),
        );
        final expected = {...entry.value.toJson(), 'id': entry.key};
        expect(actual.toJson(), expected);
        expect(actual.defaultMode, mode);
      }
    }
  });
}
