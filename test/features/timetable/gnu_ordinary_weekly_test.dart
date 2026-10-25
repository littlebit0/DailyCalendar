import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const researchRoot =
    'work/university-research/catalog-r/gnu/remaining-campus-clock-followup-v5-20261008/';
Map<String, dynamic> readMap(String path) {
  final data =
      jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
  data['researchOnly'] = false;
  for (final row in data['courses'] ?? []) {
    if (row['metadata']?.containsKey('researchOnly') == true) {
      row['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  final audit = readMap('${researchRoot}audit.json');
  final files = (audit['candidateFiles'] as List).cast<String>();
  final payloads = files.map((file) => readMap('$researchRoot$file')).toList();
  final courses = payloads.expand((p) => p['courses'] as List).toList();
  final baselines = files
      .expand(
        (file) =>
            readMap(
                  '${researchRoot}baseline-${file.replaceAll('ordinary-university-guide-v5', 'ordinary-weekly-faq-v4')}',
                )['courses']
                as List,
      )
      .toList();
  for (final dynamic c in baselines) {
    if (c['metadata'].containsKey('researchOnly')) {
      c['metadata']['researchOnly'] = false;
    }
  }
  final before = {for (final dynamic c in baselines) c['sourceId']: c};
  final originals =
      jsonDecode(
            fixtureFile(
              'work/university-research/catalogs/gnu-public-course-rows.json',
            ).readAsStringSync(),
          )
          as List;
  final native = {
    for (final dynamic r in originals) '${r['code']}-${r['section']}': r,
  };
  final oldIds = (audit['preservedPrior2779'] as List).toSet();
  final newIds = (audit['newCases'] as List)
      .map((dynamic c) => c['sourceId'])
      .toSet();
  final models = payloads
      .expand((p) => UniversityDataset.fromJson(p).courses)
      .toList();
  test(
    '4842 native fields and all prior2779 plus held1880 deeply preserved',
    () {
      expect(courses, hasLength(4842));
      expect(
        courses.map((dynamic c) => c['sourceId']).toSet(),
        hasLength(4842),
      );
      expect(newIds, hasLength(183));
      expect(oldIds, hasLength(2779));
      var oldMeetings = 0;
      var held = 0;
      for (final dynamic c in courses) {
        final source = c['metadata']['originalEducationalFields'];
        expect(source, native['${c['courseCode']}-${c['section']}']);
        final prior = before[c['sourceId']];
        for (final field in [
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
          'departmentCredits',
          'departments',
          'departmentClassifications',
          'sourceSchedule',
          'period',
        ]) {
          expect(c[field], prior[field]);
        }
        if (!newIds.contains(c['sourceId'])) {
          expect(c, prior);
          if (oldIds.contains(c['sourceId'])) {
            oldMeetings += (c['schedules'] as List).length;
          } else {
            held++;
          }
        } else {
          expect(c['campus'], anyOf('tongyeong', 'changwon', 'naedong'));
          expect(source['closedFirstAnnouncement'], isFalse);
          expect(source['closedSecondAnnouncement'], isFalse);
          expect(source['method'], '대면수업');
          expect(source['remoteType'], '');
          expect(source['remarks'], isNot(contains('집중')));
          expect(c['metadata']['actualAttendanceConfirmed'], isFalse);
        }
      }
      expect(oldMeetings, 49938);
      expect(held, 1880);
    },
  );
  test(
    '3301 new reservations independently match native periods and own official general undergraduate clock and makeup dates',
    () {
      final clock = <int, List<int>>{};
      {
        final table =
            readMap(
                  '${researchRoot}current2026-2-university-undergraduate-clock-education.json',
                )['clockTable']
                as List;
        final parsed = <int, List<int>>{};
        for (final dynamic row in table.skip(1)) {
          for (final index in [0, 2]) {
            final period = int.parse(
              RegExp(r'^\d+').firstMatch(row[index] as String)!.group(0)!,
            );
            final timeParts = RegExp(
              r'(\d{2}):(\d{2})',
            ).allMatches(row[index + 1] as String).toList();
            parsed[period] = timeParts
                .map((m) => int.parse(m[1]!) * 60 + int.parse(m[2]!))
                .toList();
          }
        }
        expect(parsed.keys.toSet(), {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11});
        if (clock.isEmpty) {
          clock.addAll(parsed);
        } else {
          expect(clock, parsed);
        }
      }
      final own =
          readMap(
                '${researchRoot}own-term-makeup-education.json',
              )['visuallyVerifiedEducationOnly']
              as Map;
      expect(own['termStart'], '2026-09-01');
      expect(own['termEnd'], '2026-12-21');
      final makeup = own['holidayToMakeup'] as Map;
      var total = 0;
      for (final dynamic c in courses.where(
        (dynamic c) => newIds.contains(c['sourceId']),
      )) {
        final source = native['${c['courseCode']}-${c['section']}'];
        final expected = <String>{};
        final segments = RegExp(
          r'([월화수목금토일])([0-9,]+)\[([^\]]+)\]',
        ).allMatches(source['schedule'] as String);
        for (final segment in segments) {
          final day = '월화수목금토일'.indexOf(segment[1]!) + 1;
          final periods = segment[2]!.split(',').map(int.parse).toList();
          final groups = <List<int>>[];
          for (final period in periods) {
            expect(clock.containsKey(period), isTrue);
            if (groups.isNotEmpty && period == groups.last.last + 1) {
              groups.last.add(period);
            } else {
              groups.add([period]);
            }
          }
          for (
            var date = DateTime(2026, 9, 1);
            !date.isAfter(DateTime(2026, 12, 7));
            date = date.add(const Duration(days: 1))
          ) {
            final iso = date.toIso8601String().substring(0, 10);
            if (date.weekday != day || iso == '2026-10-03') {
              continue;
            }
            final actualDate = (makeup[iso] ?? iso) as String;
            final actualDay = DateTime.parse(actualDate).weekday;
            for (final group in groups) {
              expected.add(
                '$actualDate|$actualDay|${clock[group.first]!.first}|${clock[group.last]!.last}|${segment[3]}',
              );
            }
          }
        }
        final actual = <String>{};
        for (final dynamic m in c['schedules']) {
          expect(m.containsKey('deliveryMode'), isFalse);
          expect(m['date'].compareTo('2026-12-15'), lessThan(0));
          actual.add(
            '${m['date']}|${m['weekday']}|${m['startMinute']}|${m['endMinute']}|${m['classroom']}',
          );
          total++;
        }
        expect(actual, expected);
        expect(actual.length, (c['schedules'] as List).length);
      }
      expect(total, 3301);
    },
  );
  test(
    '2962 actual models all3 user modes full Drive JSON and53239 meetings',
    () {
      final scheduled = models.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(2962));
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
        final encoded = document.toJson();
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>,
        ).materializeClasses();
        final originalClasses = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(2962));
        expect(restored.map((c) => c.sourceId).toSet(), hasLength(2962));
        expect(
          restored.fold<int>(0, (sum, c) => sum + c.meetings.length),
          53239,
        );
        for (final c in restored) {
          final original = originalClasses[c.sourceId]!;
          expect(c.defaultMode, mode);
          expect(c.note, original.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          if (newIds.contains(c.sourceId)) {
            expect(c.note, contains('실제 개별 출석일 확정 자료가 아니며'));
            for (final meeting in c.meetings) {
              expect(c.modeOn(meeting, DateTime.parse(meeting.date!)), mode);
            }
          }
        }
      }
    },
  );
}
