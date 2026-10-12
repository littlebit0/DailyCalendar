import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'Hoseo historical v2 current native clock and initial dated subset preserve all identities and three Drive modes',
    () {
      const root =
          'work/university-research/catalog-r/hoseo/early-regular-partial-v2/';
      final proof =
          jsonDecode(File('${root}educational-proof.json').readAsStringSync())
              as Map;
      final raws = [
        for (final campus in ['asan', 'cheonan', 'unknown'])
          jsonDecode(
                File(
                  '${root}hoseo-$campus-2026-2.early-planned.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
      ];
      final courses = raws
          .expand((raw) => UniversityDataset.fromJson(raw).courses)
          .toList();
      final rawRows = raws.expand((raw) => raw['courses'] as List).toList();
      final raw = raws.first;
      expect(courses, hasLength(2499));
      expect(proof['nativeProof']['sourceNativeRows'], hasLength(2627));
      expect(raw['researchOnly'], isTrue);
      expect(raw['completionClaim'], isFalse);
      var sourceOccurrences = 0;
      var conflicts = 0;
      var printedCampuses = 0;
      for (var i = 0; i < courses.length; i++) {
        final c = courses[i];
        final r = rawRows[i] as Map;
        final meta = r['metadata'] as Map;
        final originals = meta['originalEducationalRecords'] as List;
        sourceOccurrences += originals.length;
        for (final x in originals) {
          expect(
            x,
            (proof['nativeProof']['sourceNativeRows'] as List).singleWhere(
              (dynamic n) =>
                  n['sourceSheet'] == x['sourceSheet'] &&
                  n['sourceRow'] == x['sourceRow'],
            ),
          );
          final v = x['values'] as List;
          expect(c.code, v[6]);
          expect(c.section, v[7]);
          expect(c.title, v[2]);
          expect(c.departments, contains(v[1]));
          expect(c.departmentClassifications[v[1]], v[3]);
          expect(meta['sourceNativeTeachingMethods'], contains(v[4]));
          expect(c.sourceSchedule, v[9] ?? '');
        }
        final holds = meta['reservationHoldReasons'] as List;
        if (holds.isNotEmpty) {
          expect(c.meetings, isEmpty);
        } else {
          final v = originals.first['values'] as List;
          expect(v[4], '대면수업');
          expect(v[8], anyOf('주간', '주간(천안)'));
          expect(v[10], isNotNull);
          expect(v[11], isNull);
          final expected = <String>{};
          for (final m in RegExp(
            r'([월화수목금])([1-8])(?:~([1-8]))?',
          ).allMatches(v[9])) {
            final a = int.parse(m[2]!);
            final z = int.parse(m[3] ?? m[2]!);
            for (
              var d = DateTime(2026, 8, 31);
              !d.isAfter(DateTime(2026, 9, 20));
              d = d.add(const Duration(days: 1))
            ) {
              if (d.weekday != '월화수목금'.indexOf(m[1]!) + 1) continue;
              expected.add(
                '${d.toIso8601String().substring(0, 10)}/${(9 + a) * 60}/${(9 + z) * 60 + 50}/${v[10]}',
              );
            }
          }
          expect(
            c.meetings
                .map(
                  (m) =>
                      '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
                )
                .toSet(),
            expected,
          );
          expect(
            (r['schedules'] as List).every(
              (dynamic m) => !(m as Map).containsKey('deliveryMode'),
            ),
            isTrue,
          );
        }
        expect(meta['actualAttendanceConfirmed'], isFalse);
        expect(meta['currentWholeClosureVerified'], isFalse);
        if (meta['campusAllocationRoomConflict'] == true) {
          conflicts++;
          expect(c.campus, 'unknown');
        }
        if (c.campus != 'unknown') {
          printedCampuses++;
          expect(meta['sourcePublishedCampusLabels'], [c.campus]);
        }
        expect(r['sourceId'], c.sourceId);
      }
      expect(sourceOccurrences, 2627);
      expect(conflicts, 5);
      expect(printedCampuses, 82);
      expect(proof['nativeProof']['ownMidtermFinalDatesVerified'], isFalse);
      expect(
        proof['clockEvidence']['nativeEducationalExcerpt'],
        contains('교시별 강의시간은 50분'),
      );
      expect(
        proof['clockEvidence']['currentGuidePage6NativeStartTimes'],
        contains('10:00 11:00 12:00 13:00 14:00 15:00 16:00 17:00'),
      );
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1059));
      expect(courses.fold<int>(0, (a, c) => a + c.meetings.length), 3627);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = courses
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(after, hasLength(1059));
        final byId = {for (final c in before) c.sourceId: c};
        for (final c in after) {
          final original = byId[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.title, original.title);
          expect(c.professor, original.professor);
          expect(c.note, original.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
        }
      }
    },
  );
}
