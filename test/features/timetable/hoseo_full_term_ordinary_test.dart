import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

Map<String, dynamic> readMap(String path) {
  final actual = path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  if (data['courses'] is List) {
    data['researchOnly'] = false;
    for (final row in data['courses']) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  test('Hoseo own full term, native 2499 and three complete Drive modes', () {
    const root =
        'work/university-research/catalog-r/hoseo/full-term-ordinary-v3-20261008/';
    const prior =
        'work/university-research/catalog-r/hoseo/early-regular-partial-v2/';
    final proof = readMap('${root}educational-proof.json');
    final nativeProof = readMap('${prior}educational-proof.json');
    final originals = nativeProof['nativeProof']['sourceNativeRows'] as List;
    final excluded = (proof['excludedDates'] as List).cast<String>().toSet();
    expect(originals, hasLength(2627));
    expect(
      proof['currentTermAndExamRechecked']['midtermFinalRangePublished'],
      isFalse,
    );
    expect(proof['currentTermAndExamRechecked']['examNoticeMinimumDays'], 7);
    expect(proof['exactSchoolHolidayDates'], contains('2026-10-23'));
    expect(excluded, isNot(contains('2026-09-28')));
    expect(
      proof['anniversarySeptember28']['ordinarySeptember28ReservationsRetained'],
      isTrue,
    );
    final models = <UniversityCourse>[];
    var sourceOccurrences = 0;
    var oldScheduled = 0;
    var oldDates = 0;
    var newScheduled = 0;
    var dates = 0;
    var titleOnlyAdded = 0;
    for (final campus in ['asan', 'cheonan', 'unknown']) {
      final raw = readMap('${root}hoseo-$campus-2026-2.ordinary-planned.json');
      final baseline = readMap(
        '${prior}hoseo-$campus-2026-2.early-planned.json',
      );
      for (final c in baseline['courses']) {
        if (c['metadata']?.containsKey('researchOnly') == true) {
          c['metadata']['researchOnly'] = false;
        }
      }
      final courses = UniversityDataset.fromJson(raw).courses;
      final sourceRows = raw['courses'] as List;
      final beforeRows = baseline['courses'] as List;
      expect(raw['researchOnly'], isFalse);
      expect(raw['completionClaim'], isFalse);
      expect(courses, hasLength(beforeRows.length));
      models.addAll(courses);
      for (var i = 0; i < courses.length; i++) {
        final course = courses[i];
        final current = sourceRows[i] as Map;
        final before = beforeRows[i] as Map;
        final meta = current['metadata'] as Map;
        final previousMeta = before['metadata'] as Map;
        for (final key in before.keys) {
          if (![
            'metadata',
            'schedules',
            'scheduleStatus',
            'remarks',
          ].contains(key)) {
            expect(
              current[key],
              before[key],
              reason: '$key/${course.sourceId}',
            );
          }
        }
        for (final key in previousMeta.keys) {
          if (![
            'reservationHoldReasons',
            'heldReason',
            'selectedDateSubset',
          ].contains(key)) {
            expect(
              meta[key],
              previousMeta[key],
              reason: '$key/${course.sourceId}',
            );
          }
        }
        final records = meta['originalEducationalRecords'] as List;
        sourceOccurrences += records.length;
        for (final record in records) {
          final row = record as Map;
          expect(
            row,
            originals.singleWhere(
              (dynamic original) =>
                  original['sourceSheet'] == row['sourceSheet'] &&
                  original['sourceRow'] == row['sourceRow'],
            ),
          );
          final values = row['values'] as List;
          expect(course.code, values[6]);
          expect(course.section, values[7]);
          expect(course.title, values[2]);
          expect(course.departments, contains(values[1]));
          expect(course.departmentClassifications[values[1]], values[3]);
          expect(meta['sourceNativeTeachingMethods'], contains(values[4]));
        }
        final previousDates = before['schedules'] as List;
        final currentDates = current['schedules'] as List;
        expect(currentDates.take(previousDates.length).toList(), previousDates);
        oldDates += previousDates.length;
        if (previousDates.isNotEmpty) {
          oldScheduled++;
        }
        final holds = meta['reservationHoldReasons'] as List;
        if (holds.isNotEmpty) {
          expect(course.meetings, isEmpty);
          continue;
        }
        newScheduled++;
        dates += course.meetings.length;
        if (previousDates.isEmpty) {
          titleOnlyAdded++;
          expect(previousMeta['reservationHoldReasons'], [
            'individual lab/intensive/week/practical operatingdates unknown',
          ]);
        }
        final values = records.first['values'] as List;
        expect(values[4], '대면수업');
        expect(values[8], anyOf('주간', '주간(천안)'));
        expect(values[10], isNotNull);
        expect(values[11], isNull);
        final expected = <String>{};
        for (final m in RegExp(
          r'([월화수목금])([1-8])(?:~([1-8]))?',
        ).allMatches(values[9] as String)) {
          final startMinute = (9 + int.parse(m[2]!)) * 60;
          final endMinute = (9 + int.parse(m[3] ?? m[2]!)) * 60 + 50;
          for (
            var d = DateTime(2026, 8, 31);
            !d.isAfter(DateTime(2026, 12, 18));
            d = d.add(const Duration(days: 1))
          ) {
            final day = d.toIso8601String().substring(0, 10);
            if (d.weekday == '월화수목금'.indexOf(m[1]!) + 1 &&
                !excluded.contains(day)) {
              expected.add('$day/$startMinute/$endMinute/${values[10]}');
            }
          }
        }
        expect(
          course.meetings
              .map(
                (m) =>
                    '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              )
              .toSet(),
          expected,
        );
        expect(course.meetings.length, expected.length);
        expect(
          currentDates.every(
            (dynamic m) => !(m as Map).containsKey('deliveryMode'),
          ),
          isTrue,
        );
        expect(meta['actualAttendanceConfirmed'], isFalse);
        expect(meta['currentWholeClosureVerified'], isFalse);
        expect(meta['individualOperatingDaysVerified'], isFalse);
      }
    }
    expect(models, hasLength(2499));
    expect(models.map((c) => c.sourceId).toSet(), hasLength(2499));
    expect(models.where((c) => c.campus == 'asan'), hasLength(43));
    expect(models.where((c) => c.campus == 'cheonan'), hasLength(39));
    expect(models.where((c) => c.campus == 'unknown'), hasLength(2417));
    expect(sourceOccurrences, 2627);
    expect(oldScheduled, 1059);
    expect(oldDates, 3627);
    expect(titleOnlyAdded, 438);
    expect(newScheduled, 1497);
    expect(dates, 25860);
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final before = models
          .where((course) => course.hasSchedulableMeetings)
          .map((course) => course.toTimetable(id: course.sourceId, mode: mode))
          .toList();
      final document = TimetableSyncDocument.legacy(
        courses: before,
        termNames: {},
        activeYear: 2026,
        activeSemester: '2',
      );
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
      ).materializeClasses();
      expect(restored, hasLength(1497));
      final byId = {for (final course in before) course.sourceId: course};
      var restoredDates = 0;
      for (final course in restored) {
        final original = byId[course.sourceId]!;
        expect(course.isValid, isTrue);
        expect(course.defaultMode, mode);
        expect(course.title, original.title);
        expect(course.professor, original.professor);
        expect(course.note, original.note);
        expect(
          course.meetings.map((m) => m.toJson()).toList(),
          original.meetings.map((m) => m.toJson()).toList(),
        );
        restoredDates += course.meetings.length;
      }
      expect(restoredDates, 25860);
    }
  });
}
