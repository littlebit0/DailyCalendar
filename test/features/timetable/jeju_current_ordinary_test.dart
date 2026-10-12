import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

const base = 'work/university-research/catalog-r/jeju/';
const root = '${base}ordinary-room-program-followup-v2-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
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

List<Map<String, dynamic>> nativePairs(String text) {
  final compact = text.replaceAll(RegExp(r'\s+'), '').replaceAll('+', '');
  final result = <Map<String, dynamic>>[];
  final roomFirst = RegExp(r'\[([^\[\]]+)\]((?:[월화수목금토일]\d+[AB]?)+)');
  final periodFirst = RegExp(r'([월화수목금토일])(\d+[AB]?)\[([^\[\]]+)\]');
  final runs = roomFirst.allMatches(compact).toList();
  if (runs.isNotEmpty && runs.map((m) => m[0]).join() == compact) {
    for (final run in runs) {
      for (final p in RegExp(r'([월화수목금토일])(\d+[AB]?)').allMatches(run[2]!)) {
        result.add({'day': p[1], 'period': p[2], 'room': run[1]});
      }
    }
  } else {
    final pairs = periodFirst.allMatches(compact).toList();
    expect(pairs.map((p) => p[0]).join(), compact);
    for (final p in pairs) {
      result.add({'day': p[1], 'period': p[2], 'room': p[3]});
    }
  }
  return result;
}

(int, int) ownClock(String period) {
  const blocks = {
    '1A': (540, 615),
    '2B': (630, 705),
    '4A': (720, 795),
    '5B': (810, 885),
    '7A': (900, 975),
    '8B': (990, 1065),
  };
  if (blocks.containsKey(period)) {
    return blocks[period]!;
  }
  final p = int.parse(period);
  expect(p, inInclusiveRange(1, 14));
  if (p <= 9) {
    return ((8 + p) * 60, (8 + p) * 60 + 50);
  }
  return (1110 + (p - 10) * 50, 1155 + (p - 10) * 50);
}

void main() {
  test(
    'Jeju v2 all native fields, 1510 baseline, explicit pairs and full three-mode Drive',
    () {
      final nativeRows =
          read(
                'work/university-research/catalog-i/jeju-current-whole-educational-review-20261008.json',
              )['courses']
              as List;
      final native = {
        for (final r in nativeRows) '${r['enrollmentNumber']}': r,
      };
      final scheduled = <UniversityCourse>[];
      final additions = <String>[];
      var total = 0,
          dates = 0,
          subjectCodes = 0,
          priorCount = 0,
          priorDates = 0;
      var medicalHeld = 0, vetAdded = 0, futureAdded = 0, addedDates = 0;
      var remoteHeld = 0, mixedHeld = 0, emptyHeld = 0;
      final campusCounts = <String, List<int>>{};
      for (final campus in ['ara', 'sara', 'unknown']) {
        final old = read(
          '${base}jeju-$campus-2026-2.reservation-planned-v1.json',
        );
        final raw = read(
          '${root}jeju-$campus-2026-2.reservation-planned-v2.json',
        );
        final rows = raw['courses'] as List;
        for (final c in old['courses']) {
          if (c['metadata']?.containsKey('researchOnly') == true) {
            c['metadata']['researchOnly'] = false;
          }
        }
        final priors = {
          for (final r in old['courses'] as List) r['sourceId']: r,
        };
        final dataset = UniversityDataset.fromJson(raw);
        expect(raw['researchOnly'], false);
        expect(raw['completionClaim'], false);
        var campusScheduled = 0, campusDates = 0;
        for (var i = 0; i < rows.length; i++) {
          total++;
          final r = rows[i] as Map;
          final prior = priors[r['sourceId']] as Map;
          final c = dataset.courses[i];
          final meta = r['metadata'] as Map;
          final original = meta['originalEducationalFields'] as Map;
          expect(original, native['${original['enrollmentNumber']}']);
          for (final key in [
            'sourceId',
            'campus',
            'academicYear',
            'semester',
            'courseCode',
            'courseName',
            'section',
            'professor',
            'classification',
            'credits',
            'departments',
            'departmentCredits',
            'departmentClassifications',
            'sourceSchedule',
            'period',
          ]) {
            expect(r[key], prior[key], reason: '$key ${c.sourceId}');
          }
          expect(c.section, isEmpty);
          expect(meta['actualAttendanceConfirmed'], false);
          expect(meta['currentActiveStatusVerified'], false);
          if (original['subjectCode'] != null) {
            subjectCodes++;
            expect(c.code, original['subjectCode']);
          } else {
            expect(meta['referenceKind'], 'publishedEnrollmentNumber');
            expect(c.code, meta['publishedEnrollmentNumber']);
          }
          if ((prior['schedules'] as List).isNotEmpty) {
            expect(r, prior, reason: 'Baseline full object ${c.sourceId}');
            priorCount++;
            priorDates += (prior['schedules'] as List).length;
          }
          final department = original['department'] as String;
          if (department.startsWith('의과대학 ')) {
            medicalHeld++;
            expect(c.hasSchedulableMeetings, false);
          }
          switch (original['operatingReview']) {
            case 'remote-actual-attendance-or-assessment-review':
              remoteHeld++;
              expect(c.hasSchedulableMeetings, false);
            case 'blended-attendance-period-review':
              mixedHeld++;
              expect(c.hasSchedulableMeetings, false);
            case 'published-time-unavailable':
              emptyHeld++;
              expect(c.hasSchedulableMeetings, false);
          }
          if (!c.hasSchedulableMeetings) {
            continue;
          }
          campusScheduled++;
          campusDates += c.meetings.length;
          scheduled.add(c);
          expect(
            original['operatingReview'],
            'ordinary-clock-current-operation-review',
          );
          final isNew = (prior['schedules'] as List).isEmpty;
          List<Map<String, dynamic>> pairs = [];
          if (isNew) {
            additions.add(c.sourceId);
            addedDates += c.meetings.length;
            pairs = nativePairs(original['rawTimeAndRoom'] as String);
            if (department.startsWith('수의과대학 ')) {
              vetAdded++;
            }
            if (department.startsWith('미래융합')) {
              futureAdded++;
            }
            expect(meta['heldReason'], '');
            expect(pairs, isNotEmpty);
          }
          expect(
            (r['schedules'] as List).every(
              (dynamic s) => !(s as Map).containsKey('deliveryMode'),
            ),
            true,
          );
          for (final m in c.meetings) {
            dates++;
            final day = DateTime.parse(m.date!);
            expect(day.weekday, m.weekday);
            expect(day.isBefore(DateTime(2026, 9, 1)), false);
            expect(day.isAfter(DateTime(2026, 12, 7)), false);
            expect(
              day.isBefore(DateTime(2026, 10, 20)) ||
                  day.isAfter(DateTime(2026, 10, 26)),
              true,
            );
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-09-26',
              '2026-10-03',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));

            if (isNew) {
              expect(
                pairs.any((p) {
                  final clock = ownClock(p['period'] as String);
                  return '월화수목금토일'.indexOf(p['day'] as String) + 1 ==
                          m.weekday &&
                      clock.$1 == m.originalStartMinute &&
                      clock.$2 == m.originalEndMinute &&
                      p['room'] == m.classroom.replaceAll(RegExp(r'\s+'), '');
                }),
                true,
                reason: '${c.sourceId} ${m.date}',
              );
            }
          }
          if (isNew) {
            final expected = <String>{};
            for (
              var day = DateTime(2026, 9, 1);
              !day.isAfter(DateTime(2026, 12, 7));
              day = day.add(const Duration(days: 1))
            ) {
              final key =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              if ((day.isBefore(DateTime(2026, 10, 20)) ||
                      day.isAfter(DateTime(2026, 10, 26))) &&
                  ![
                    '2026-09-24',
                    '2026-09-25',
                    '2026-09-26',
                    '2026-10-03',
                    '2026-10-05',
                    '2026-10-09',
                  ].contains(key)) {
                for (final pair in pairs) {
                  if ('월화수목금토일'.indexOf(pair['day'] as String) + 1 ==
                      day.weekday) {
                    final clock = ownClock(pair['period'] as String);
                    expected.add(
                      '$key|${clock.$1}|${clock.$2}|${pair['room']}',
                    );
                  }
                }
              }
            }
            final actual = c.meetings
                .map(
                  (m) =>
                      '${m.date}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom.replaceAll(RegExp(r'\s+'), '')}',
                )
                .toSet();
            expect(
              actual,
              expected,
              reason: 'Complete native date expansion ${c.sourceId}',
            );
            expect(actual.length, c.meetings.length);
          }
        }
        campusCounts[campus] = [rows.length, campusScheduled, campusDates];
      }
      expect(total, 3095);
      expect(subjectCodes, 531);
      expect(priorCount, 1510);
      expect(priorDates, 52732);
      expect(additions, hasLength(181));
      expect(addedDates, 10185);
      expect(vetAdded, 23);
      expect(futureAdded, 31);
      expect(medicalHeld, 72);
      expect(remoteHeld, 133);
      expect(mixedHeld, 182);
      expect(emptyHeld, 935);
      expect(scheduled, hasLength(1691));
      expect(dates, 62917);
      expect(campusCounts, {
        'ara': [768, 684, 25135],
        'sara': [49, 37, 1435],
        'unknown': [2278, 970, 36347],
      });
      final audit = read('${root}audit.json');
      expect(
        (audit['added'] as List).map((r) => r['sourceId']).toSet(),
        additions.toSet(),
      );
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
        expect(restored, hasLength(1691));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.note, prior.note);
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
}
