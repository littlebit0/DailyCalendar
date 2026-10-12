import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-f/mju/current-business-bulk-direct-clock-v11-20261009';
dynamic read(String path) {
  final actual = path;
  final data = jsonDecode(File(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  test(
    'MJU21 bulk rows: prior221 whole,20 native direct HH,299 dates,all3mode full Drive',
    () {
      final proof = read(
        '$folder/independent-literal-date-clock-proof-prepared.json',
      );
      for (final input in proof['sourceInputs'] as List) {
        expect(
          sha256
              .convert(File(input['path'] as String).readAsBytesSync())
              .toString(),
          input['sha256'],
        );
      }
      final source = read(
        '$folder/current-bulk-table-education-first-transcription.json',
      );
      expect(source['academicYear'], 2026);
      expect(source['semester'], '2');
      expect(source['rows'], hasLength(21));
      final literals =
          read(
                '$folder/independent-calendar-weekday-literal-dates.json',
              )['literalDatesByWeekday']
              as Map;
      final prior = <String, dynamic>{};
      final parts = <Map<String, dynamic>>[];
      for (final campus in ['humanities', 'natural', 'unknown']) {
        final old = read(proof['priorDatasetPaths'][campus] as String);
        for (final c in old['courses'] as List) {
          prior[c['sourceId'] as String] = c;
        }
        parts.add(
          campus == 'unknown'
              ? read(
                  '$folder/mju-unknown-2026-2.business-bulk-direct-clock-v11-prepared.json',
                )
              : old,
        );
      }
      expect(prior, hasLength(221));
      final current = <String, dynamic>{};
      for (final part in parts) {
        for (final c in part['courses'] as List) {
          expect(current.containsKey(c['sourceId']), false);
          current[c['sourceId'] as String] = c;
        }
      }
      expect(current, hasLength(241));
      for (final e in prior.entries) {
        expect(current[e.key], e.value);
      }
      expect(current['mju/humanities/2026-2/5190']['schedules'], isEmpty);
      final weekdays = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5};
      var addedMeetings = 0;
      for (final row in source['rows'] as List) {
        if (row['nativeLectureNumber'] == '5190') {
          continue;
        }
        final id = 'mju/unknown/2026-2/${row['nativeLectureNumber']}';
        expect(prior.containsKey(id), false);
        final c = current[id] as Map;
        expect(c['sourceEducation']['nativePublicCells'], row);
        expect(c['courseName'], row['courseName']);
        expect(c['professor'], row['professor']);
        expect(c['classification'], row['classification']);
        expect(c['credits'], row['credits']);
        expect(c['courseCode'], '');
        expect(c['section'], '');
        expect(c['campus'], 'unknown');
        expect(c['sourceClassroom'], '');
        final split = (row['nativeTime'] as String).split(' ');
        final rawClock = split[1].split('-');
        final start =
            int.parse(rawClock[0].substring(0, 2)) * 60 +
            int.parse(rawClock[0].substring(2));
        final end =
            int.parse(rawClock[1].substring(0, 2)) * 60 +
            int.parse(rawClock[1].substring(2));
        final expectedDates = <String>[];
        for (final day in split[0].split('')) {
          expectedDates.addAll(
            (literals['${weekdays[day]}'] as List).cast<String>(),
          );
        }
        expectedDates.sort();
        final meetings = c['schedules'] as List;
        expect(meetings.map((m) => m['date']).toList(), expectedDates);
        addedMeetings += meetings.length;
        for (final m in meetings) {
          expect(m['weekday'], DateTime.parse(m['date'] as String).weekday);
          expect(m['startMinute'], start);
          expect(m['endMinute'], end);
          expect(m['originalStartMinute'], start);
          expect(m['originalEndMinute'], end);
          expect(m['classroom'], '');
          expect(m.containsKey('deliveryMode'), false);
        }
        final note = (c['departmentRemarks'] as Map).values.join(' ');
        expect(note, contains(row['nativeEligibility']));
        expect(note, contains('일괄수강 교과목 변경 불가'));
      }
      expect(addedMeetings, 299);
      final courses = parts
          .expand((d) => UniversityDataset.fromJson(d).courses)
          .toList();
      expect(courses, hasLength(241));
      final plans = courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(plans, hasLength(28));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 496);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = plans
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
        final lookup = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(28));
        expect(restored.map((c) => c.sourceId).toSet(), lookup.keys.toSet());
        for (final c in restored) {
          expect(
            c.toJson()..remove('id'),
            lookup[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.isValid, true);
        }
        for (final row in source['rows'] as List) {
          if (row['nativeLectureNumber'] == '5190') {
            continue;
          }
          final c = restored.singleWhere(
            (c) =>
                c.sourceId ==
                'mju/unknown/2026-2/${row['nativeLectureNumber']}',
          );
          for (final meeting in c.meetings) {
            expect(c.modeOn(meeting, DateTime.parse(meeting.date!)), mode);
          }
        }
      }
    },
  );
}
