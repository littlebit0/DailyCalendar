import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root = 'work/university-research/catalog-w/dongguk/';
Map<String, dynamic> read(String name) =>
    jsonDecode(
          fixtureFile(
            name.startsWith('dongguk-')
                ? 'assets/timetable/${name.replaceAll('.public-export-partial-v1', '')}'
                : '$root$name',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
void main() {
  test(
    'Actual public export rows preserve native fields, clocks, campus and all dated reservations through full Drive',
    () {
      final export = read('current-public-seoul-2026-2-export-education.json');
      final native = {
        for (final row in export['rows'] as List) row['학수번호']: row,
      };
      expect(native, hasLength(2543));
      final calendar =
          (read('current-own-calendar-education.json')['tables'] as List)
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' ');
      expect(calendar, contains('2026.09.01.'));
      expect(calendar, contains('2026.10.20. ~ 2026.10.26.'));
      expect(calendar, contains('2026.12.08. ~ 2026.12.14.'));
      expect(calendar, contains('2026.12.14. 종강'));
      final currentProof =
          jsonDecode(
                fixtureFile(
                  'work/university-research/five-school-ajou-dongguk-hansung-seoultech-hknu-bulk-v2-20261010/proof.json',
                ).readAsStringSync(),
              )
              as Map;
      final reviewedRooms = <String, Map>{
        for (final row in currentProof['newCourses'] as List)
          if (row['school'] == 'dongguk') row['sourceId'] as String: row as Map,
      };
      final scheduled = <dynamic>[];
      var total = 0, meetings = 0;
      for (final campus in ['seoul', 'ilsan', 'unknown']) {
        final raw = read(
          'dongguk-$campus-2026-2.public-export-partial-v1.json',
        );
        final dataset = UniversityDataset.fromJson(raw);
        for (var i = 0; i < dataset.courses.length; i++) {
          final course = dataset.courses[i];
          final row = native['${course.code}-${course.section}'] as Map;
          expect(
            (raw['courses'][i]['metadata'] as Map)['nativeEducationalRow'],
            row,
          );
          expect(course.title, row['교과목명']);
          expect(course.professor, isEmpty);
          expect(raw['courses'][i]['classification'], row['이수구분'] ?? '');
          expect(
            course.credits,
            row['학점'] == null ? null : double.parse(row['학점']),
          );
          expect(
            course.campus,
            {'서울': 'seoul', '일산': 'ilsan'}[row['강의지역']] ?? 'unknown',
          );
          total++;
          if (course.meetings.isEmpty) continue;
          final chunks = (row['요일/교시'] as String).split(
            RegExp(r'(?<=\)), (?=[월화수목금토일])'),
          );
          final slots = <String>{};
          for (final chunk in chunks) {
            final clocks = RegExp(
              r'\((\d\d):(\d\d)\)',
            ).allMatches(chunk).toList();
            expect(clocks, hasLength(2), reason: chunk);
            int minute(RegExpMatch m) =>
                int.parse(m[1]!) * 60 + int.parse(m[2]!);
            for (final day in RegExp(
              '[월화수목금토일]',
            ).allMatches(chunk.split('교시').first)) {
              slots.add(
                '${'월화수목금토일'.indexOf(day[0]!) + 1}/${minute(clocks[0])}/${minute(clocks[1])}',
              );
            }
          }
          final expected = <String>{};
          for (
            var d = DateTime(2026, 9, 1);
            !d.isAfter(DateTime(2026, 12, 7));
            d = d.add(const Duration(days: 1))
          ) {
            final date = d.toIso8601String().substring(0, 10);
            if ([
                  '2026-09-24',
                  '2026-09-25',
                  '2026-09-26',
                  '2026-10-03',
                  '2026-10-05',
                  '2026-10-09',
                ].contains(date) ||
                (!d.isBefore(DateTime(2026, 10, 20)) &&
                    !d.isAfter(DateTime(2026, 10, 26)))) {
              continue;
            }
            for (final slot in slots.where(
              (s) => s.startsWith('${d.weekday}/'),
            )) {
              var room = row['강의실'] ?? '';
              final review = reviewedRooms[course.sourceId];
              if (review != null) {
                final nativeSlot = (review['literalSlots'] as List).singleWhere(
                  (r) =>
                      '${r['weekday']}/${r['startMinute']}/${r['endMinute']}' ==
                      slot,
                );
                room = nativeSlot['classroom'];
                expect(
                  review['wholeSourceEvidence']['wholeNativeEducationalRow'],
                  row,
                );
              }
              expected.add('$date/$slot/$room');
            }
          }
          expect(
            course.meetings
                .map(
                  (m) =>
                      '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
                )
                .toSet(),
            expected,
          );
          expect(course.meetings.length, expected.length);
          meetings += course.meetings.length;
          scheduled.add(course);
        }
      }
      expect(total, 2543);
      expect(scheduled, hasLength(2295));
      expect(meetings, 42705);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map(
              (c) =>
                  c.toTimetable(id: c.sourceId, mode: mode) as TimetableClass,
            )
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        final before = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(2295));
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, prior.title);
          expect(c.note, prior.note);
          expect(c.professor, prior.professor);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            prior.meetings.map((m) => m.toJson()).toList(),
          );
        }
      }
    },
  );
}
