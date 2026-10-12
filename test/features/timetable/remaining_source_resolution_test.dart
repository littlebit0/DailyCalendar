import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'HUFS all652 resolved rows match independently captured literal schedule and syllabus date decisions',
    () {
      const root =
          'work/university-research/catalog-t/hufs-bulk-native-operation-v15-20261010/';
      final proof = read('${root}proof.json');
      final expected = read(
        '${root}source-literal-independent-expectations.json',
      );
      final records = {
        for (final campus in ['seoul', 'global'])
          for (final c in UniversityDataset.fromJson(
            read('assets/timetable/hufs-$campus-2026-2.json'),
          ).courses)
            c.sourceId: c,
      };
      expect(proof['proofs'], hasLength(652));
      expect(expected, hasLength(652));
      for (final p in proof['proofs'] as List) {
        final c = records[p['sourceId']]!;
        expect(
          c.meetings
              .map(
                (m) => {
                  'date': m.date,
                  'weekday': m.weekday,
                  'startMinute': m.originalStartMinute,
                  'endMinute': m.originalEndMinute,
                  'classroom': m.classroom,
                },
              )
              .toList(),
          expected[c.sourceId],
          reason: c.sourceId,
        );
        for (final m in c.meetings) {
          expect(
            (p['nativeFixedSlots'] as List).any(
              (s) =>
                  s['weekday'] == m.weekday &&
                  s['startMinute'] == m.originalStartMinute &&
                  s['endMinute'] == m.originalEndMinute &&
                  s['classroom'] == m.classroom,
            ),
            true,
          );
          expect(c.period!.contains(m.teachingDate!), true);
        }
      }
    },
  );

  test(
    'Sogang413 additions are native exact exam appointments, not weekly lectures',
    () {
      const root =
          'work/university-research/catalog-c/sogang-direct-current-published-exam-queue-refinement-v5-20261010/';
      final proof = read(
        '${root}independent-current-native-exam-clock-date-proof.json',
      );
      final courses = {
        for (final c in UniversityDataset.fromJson(
          read('assets/timetable/sogang-unknown-2026-2.json'),
        ).courses)
          c.sourceId: c,
      };
      expect(proof['eligibleProofs'], hasLength(413));
      for (final p in proof['eligibleProofs'] as List) {
        final c = courses[p['sourceId']]!;
        expect(c.meetings, hasLength(1));
        final m = c.meetings.single;
        expect(m.date, p['calendarDate']);
        expect(m.weekday, p['weekday']);
        expect(m.originalStartMinute, p['startMinute']);
        expect(m.originalEndMinute, p['endMinute']);
        expect(m.classroom, p['classroomLiteral']);
        expect(p['wholeOriginalNativeEducation']['exam'], p['nativeExamText']);
        for (final mode in [
          LectureMode.inPerson,
          LectureMode.liveOnline,
          LectureMode.video,
        ]) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(
            saved.modeOn(m, m.teachingDate!),
            p['sourceExamDeliveryMode'] == null
                ? mode
                : LectureMode.values.byName(
                    p['sourceExamDeliveryMode'] as String,
                  ),
          );
          if (p['sourceExamDeliveryMode'] != null) {
            expect(p['deliveryModeSourceLiteral'], isNotEmpty);
          }
          expect(
            classOccurrences(
              [saved],
              [m.teachingDate!.add(const Duration(days: 7))],
            ),
            isEmpty,
          );
        }
      }
    },
  );

  test(
    'Hanyang444 new reservations retain exact native clock and room literals',
    () {
      final proof = read(
        'work/university-research/catalog-c/hanyang-held-native-bulk-v5-20261010/independent-native-calendar-validation.json',
      );
      final courses = {
        for (final campus in ['seoul', 'erica'])
          for (final c in UniversityDataset.fromJson(
            read('assets/timetable/hanyang-$campus-2026-2.json'),
          ).courses)
            c.sourceId: c,
      };
      expect(proof['byCourse'], hasLength(444));
      for (final p in proof['byCourse'] as List) {
        final c = courses[p['sourceId']]!;
        final expected = (p['expectedSchedulesCalendarDerived'] as List)
            .map(
              (r) => {
                'date': r['date'],
                'weekday': r['weekday'],
                'startMinute': r['startMinute'],
                'endMinute': r['endMinute'],
                'classroom': (r['classroom'] as String).startsWith('비지정(')
                    ? ''
                    : r['classroom'],
              },
            )
            .toList();
        expect(
          c.meetings
              .map(
                (m) => {
                  'date': m.date,
                  'weekday': m.weekday,
                  'startMinute': m.originalStartMinute,
                  'endMinute': m.originalEndMinute,
                  'classroom': m.classroom,
                },
              )
              .toList(),
          expected,
          reason: c.sourceId,
        );
      }
    },
  );

  test(
    'Mokpo102 missing periods repaired without altering native fields or teaching dates',
    () {
      const root = 'work/source-validation22-20261011/';
      final corrections =
          jsonDecode(
                fixtureFile(
                  '${root}mokpo-period-corrections.json',
                ).readAsStringSync(),
              )
              as List;
      var count = 0;
      for (final fix in corrections) {
        final path = fix['file'] as String;
        final file = path.split('/').last;
        final prior = read('$root$file.before');
        final current = read(path);
        final before = {
          for (final c in prior['courses'] as List) c['sourceId']: c,
        };
        for (final id in fix['courseIds'] as List) {
          count++;
          final c =
              (current['courses'] as List).singleWhere(
                    (c) => c['sourceId'] == id,
                  )
                  as Map;
          expect(c['period'], {
            'startDate': '2026-09-01',
            'endDate': '2026-12-07',
          });
          final unchanged = Map<String, dynamic>.from(c)..remove('period');
          expect(unchanged, before[id]);
          final model = UniversityDataset.fromJson(current).courses
              .singleWhere((c) => c.sourceId == id)
              .toTimetable(id: id, mode: LectureMode.inPerson);
          final restored = TimetableClass.fromJson(model.toJson());
          expect(restored.period!.start, DateTime(2026, 9, 1));
          expect(restored.period!.end, DateTime(2026, 12, 7));
          expect(
            classOccurrences(
              [restored],
              [DateTime(2026, 12, 8), DateTime(2027, 9, 1)],
            ),
            isEmpty,
          );
        }
      }
      expect(count, 102);
    },
  );
}
