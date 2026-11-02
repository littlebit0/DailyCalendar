// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  const root =
      'work/university-research/catalog-r/suwon/full-term-ordinary-v3-20261008/';
  dynamic read(String name) =>
      jsonDecode(fixtureFile('$root$name').readAsStringSync());
  final raw =
      jsonDecode(
            fixtureFile(
              'work/university-research/resume-batch-20261010/before-projection/suwon-unknown-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final baseline = read('baseline2334-v2-frozen.json') as Map;
  final proof = read('educational-proof.json') as Map;
  final oldById = {
    for (final c in baseline['courses'] as List) c['sourceId']: c,
  };
  final courses = UniversityDataset.fromJson(raw).courses;

  test(
    '108 independent current public snapshots retain2596native rows2334identities and original2602appointments',
    () {
      final native = <String, List<dynamic>>{};
      expect((proof['sourceFilesSHA256'] as Map).length, 108);
      for (final filename in (proof['sourceFilesSHA256'] as Map).keys) {
        final source =
            jsonDecode(fixtureFile(filename as String).readAsStringSync())
                as Map;
        expect(source['year'], '2026');
        expect(source['semester'], '2');
        final rows = source['rows'] as List;
        final complete =
            ['전체-p1', '전체-p2', '전체-p3', '전체-p4'].contains(source['query'])
            ? rows.take(rows.length - 1)
            : rows;
        for (final value in complete) {
          final row = value as List<dynamic>;
          if (native.containsKey(row[0])) {
            expect(row, native[row[0]]);
          }
          native[row[0] as String] = row;
        }
      }
      expect(native, hasLength(2596));
      expect(courses, hasLength(2334));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2334));
      var originalMeetings = 0;
      var nativeVariants = 0;
      var closed = 0;
      for (final c in raw['courses'] as List) {
        final old = oldById[c['sourceId']];
        for (final field in old.keys) {
          if ([
            'schedules',
            'scheduleStatus',
            'remarks',
            'metadata',
          ].contains(field)) {
            continue;
          }
          expect(c[field], old[field], reason: field as String);
        }
        expect(
          c['metadata']['originalEducationalRecords'],
          old['metadata']['originalEducationalRecords'],
        );
        final before = old['schedules'] as List;
        originalMeetings += before.length;
        expect((c['schedules'] as List).take(before.length).toList(), before);
        var isClosed = false;
        for (final v in c['metadata']['originalEducationalRecords'] as List) {
          nativeVariants++;
          final row = v['values'] as List;
          expect(row, native[row[0]]);
          expect(c['courseCode'], row[2]);
          expect(c['section'], row[4]);
          if (row[20] != '' || row[21] != '') {
            isClosed = true;
          }
        }
        if (isClosed) {
          closed++;
          expect(c['schedules'], isEmpty);
        }
        expect(c['campus'], 'unknown');
        expect(c['metadata']['actualAttendanceConfirmed'], false);
      }
      expect(nativeVariants, 2596);
      expect(closed, 132);
      expect(originalMeetings, 2602);
    },
  );

  test(
    'Own published1–8clock exact native weekday room and full ordinary bounds without fictional midterms',
    () {
      final exclusion = (proof['reservationScope']['excludedDates'] as List)
          .toSet();
      final clock = proof['clockEvidence']['clock'] as List;
      expect(clock.map((c) => c['period']).toList(), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(proof['calendarEvidence']['datePolicy']['opening'], '2026-09-01');
      expect(proof['calendarEvidence']['datePolicy']['finalExams'], [
        '2026-12-08',
        '2026-12-14',
      ]);
      expect(
        proof['calendarEvidence']['datePolicy']['midtermDatesProven'],
        false,
      );
      int minute(String t) =>
          int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3));
      var scheduled = 0;
      var meetings = 0;
      var inHalfCountWeek = 0;
      for (final c in raw['courses'] as List) {
        final appointments = c['schedules'] as List;
        final holds = c['metadata']['reservationHoldReasons'] as List;
        if (holds.isNotEmpty) {
          expect(appointments, isEmpty);
          continue;
        }
        scheduled++;
        final sourceRow =
            c['metadata']['originalEducationalRecords'][0]['values'] as List;
        expect(sourceRow[14], false);
        expect(sourceRow[15], false);
        final text = sourceRow[12] as String;
        final allocation = <String>{};
        for (final block in RegExp(r'([^(),]+)\(([^()]*)\)').allMatches(text)) {
          for (final day in RegExp(
            r'([월화수목금토일])(\d+(?:,\d+)*)',
          ).allMatches(block[2]!)) {
            for (final period in day[2]!.split(',').map(int.parse)) {
              expect(period >= 1 && period <= 8, true);
              allocation.add(
                '${'월화수목금토일'.indexOf(day[1]!) + 1}/$period/${block[1]}',
              );
            }
          }
        }
        final expected = <String>{};
        for (
          var d = DateTime(2026, 9, 1);
          !d.isAfter(DateTime(2026, 12, 7));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (exclusion.contains(date)) {
            continue;
          }
          for (final entry in allocation) {
            if (entry.startsWith('${d.weekday}/')) {
              expected.add('$date/$entry');
            }
          }
        }
        final expanded = <String>{};
        final unique = <String>{};
        for (final m in appointments) {
          meetings++;
          final date = DateTime.parse(m['date'] as String);
          expect(date.weekday, m['weekday']);
          expect(exclusion.contains(m['date']), false);
          expect(m.containsKey('deliveryMode'), false);
          expect(
            unique.add(
              '${m['date']}/${m['weekday']}/${m['startMinute']}/${m['endMinute']}/${m['classroom']}',
            ),
            true,
          );
          var matched = 0;
          for (final p in clock) {
            final start = minute(p['start'] as String);
            final end = minute(p['end'] as String);
            if (start >= m['startMinute'] && end <= m['endMinute']) {
              matched++;
              expanded.add(
                '${m['date']}/${m['weekday']}/${p['period']}/${m['classroom']}',
              );
            }
          }
          expect(matched, greaterThan(0));
          expect(
            clock.any((p) => minute(p['start'] as String) == m['startMinute']),
            true,
          );
          expect(
            clock.any((p) => minute(p['end'] as String) == m['endMinute']),
            true,
          );
          if ((m['date'] as String).compareTo('2026-10-20') >= 0 &&
              (m['date'] as String).compareTo('2026-10-26') <= 0) {
            inHalfCountWeek++;
          }
        }
        expect(expanded, expected, reason: c['sourceId'] as String);
      }
      expect(scheduled, 1518);
      expect(meetings, 22940);
      expect(inHalfCountWeek, greaterThan(0));
    },
  );

  test(
    '1518actual model reservations22940 full Drive meetings retain all three user modes',
    () {
      expect(raw['completionClaim'], false);
      expect(raw['wholeOperatingVerified'], false);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = courses
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(before, hasLength(1518));
        final doc = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final payload = doc.toJson();

        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(1518));
        final original = {for (final c in before) c.sourceId: c};
        var count = 0;
        for (final c in restored) {
          final prior = original[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, prior.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            prior.meetings.map((m) => m.toJson()).toList(),
          );
          count += c.meetings.length;
        }
        expect(count, 22940);
      }
    },
  );
}
