import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-f/kau/current-whole-public-scope-followup-v2-20261008/';
  dynamic read(String n) =>
      jsonDecode(fixtureFile('$root$n').readAsStringSync());
  final candidate =
      jsonDecode(
            fixtureFile(
              'assets/timetable/kau-main-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final baseline =
      read('baseline-public83-frozen.json') as Map<String, dynamic>;
  final source =
      read('current-published-holiday-makeup-education.json')
          as Map<String, dynamic>;
  for (final course in baseline['courses'] as List) {
    if (course['metadata']?.containsKey('researchOnly') == true) {
      course['metadata']['researchOnly'] = false;
    }
  }
  final original = {
    for (final c in baseline['courses'] as List) c['sourceId']: c,
  };

  test(
    'All original83 identities and old332meetings preserved, held61 and unaffected8 remain deep equal',
    () {
      expect(candidate['courses'], hasLength(83));
      expect(
        (candidate['courses'] as List).map((c) => c['sourceId']).toSet(),
        hasLength(83),
      );
      var modified = 0;
      for (final c in candidate['courses'] as List) {
        final old = original[c['sourceId']];
        final before = old['schedules'] as List;
        final after = c['schedules'] as List;
        expect(after.take(before.length).toList(), before);
        if (after.length == before.length) {
          expect(c, old);
        } else {
          modified++;
          for (final field in old.keys) {
            if (['schedules', 'period', 'departmentRemarks'].contains(field)) {
              continue;
            }
            expect(c[field], old[field], reason: field);
          }
          expect(c['sourceClassroom'], isEmpty);
          expect(c['section'], isEmpty);
        }
      }
      expect(modified, 14);
      expect(
        (candidate['courses'] as List).where(
          (c) => (c['schedules'] as List).isEmpty,
        ),
        hasLength(61),
      );
      expect(candidate['completionClaim'], false);
      expect(candidate['wholeSchoolCourseCoverageComplete'], false);
      expect(candidate['wholeOperatingVerified'], false);
    },
  );

  test(
    '18 exact published holiday makeups independently use native weekday clock, calendar date and unresolved original room',
    () {
      expect(source['publicationDate'], '2026-09-22');
      expect(source['unassignedMakeupDate'], '2026-12-16');
      final rows = [
        ...read(
              'kau-current-ta-undergraduate-education-20261008.json',
            )['educationRows']
            as List,
        ...read('kau-current-sw-later-clock-20261008.json')['educationRows']
            as List,
      ];
      final expectedPairs = {
        '2026-10-09': '2026-12-15',
        '2026-09-24': '2026-12-17',
        '2026-09-25': '2026-12-18',
        '2026-10-05': '2026-12-21',
      };
      expect({
        for (final p in source['publishedPairs'] as List)
          p['holiday']: p['makeupDate'],
      }, expectedPairs);
      var count = 0;
      for (final c in candidate['courses'] as List) {
        final before = original[c['sourceId']]['schedules'] as List;
        final added = (c['schedules'] as List).skip(before.length).toList();
        if (added.isEmpty) {
          continue;
        }
        final nativeNumber = (c['sourceId'] as String).split('/').last;
        final native = rows.firstWhere(
          (r) => r['nativeLectureNumber'] == nativeNumber,
        );
        final timing = native['nativeSchedule'] as String;
        final clock = RegExp(
          r'(\d{2}):(\d{2})[~∼](\d{2}):(\d{2})',
        ).firstMatch(timing)!;
        final start = int.parse(clock[1]!) * 60 + int.parse(clock[2]!);
        final end = int.parse(clock[3]!) * 60 + int.parse(clock[4]!);
        final weekdays = timing
            .split('')
            .where((x) => '월화수목금토일'.contains(x) && x.isNotEmpty)
            .map((x) => '월화수목금토일'.indexOf(x) + 1)
            .toSet();
        final expectedDates =
            expectedPairs.entries
                .where((e) => weekdays.contains(DateTime.parse(e.key).weekday))
                .map((e) => e.value)
                .toList()
              ..sort();
        expect(added.map((m) => m['date']).toList(), expectedDates);
        for (final m in added) {
          count++;
          expect(m['weekday'], DateTime.parse(m['date'] as String).weekday);
          expect(m['startMinute'], start);
          expect(m['endMinute'], end);
          expect(m['classroom'], isEmpty);
          expect(m.containsKey('deliveryMode'), false);
          expect(m['date'] == '2026-12-16', false);
          expect(
            DateTime.parse(m['date'] as String).isAfter(DateTime(2026, 12, 21)),
            false,
          );
        }
        expect(c['period']['endDate'], expectedDates.last);
        expect(
          c['sourceEducationalMetadata']['actualTeacherMakeupConfirmationPending'],
          true,
        );
        expect(
          c['sourceEducationalMetadata']['actualAttendanceConfirmed'],
          false,
        );
      }
      expect(count, 18);
    },
  );

  test(
    'Actual83model22scheduled350meetings preserve three user modes and complete Drive JSON',
    () {
      final ds = UniversityDataset.fromJson(candidate);
      expect(ds.courses, hasLength(83));
      final usable = ds.courses.where((c) => c.hasSchedulableMeetings).toList();
      expect(usable, hasLength(22));
      expect(usable.fold<int>(0, (sum, c) => sum + c.meetings.length), 350);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = usable
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final payload = jsonEncode(doc.toJson());

        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(payload) as Map<String, dynamic>,
        ).materializeClasses();
        final originalClasses = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(22));
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            originalClasses[c.sourceId]!.toJson()..remove('id'),
          );
        }
      }
    },
  );
}
