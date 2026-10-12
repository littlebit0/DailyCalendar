import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'Koreatech scoped reservations retain unknown delivery in all modes and Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/koreatech/';
      final originals =
          (jsonDecode(
                    File(
                      '${root}koreatech-2026-2-public-educational-rows-v1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['rows']
              as List;
      final native = {
        for (final row in originals)
          '${row['nativeCourseCode']}-${row['nativeSection']}': row,
      };
      final scheduled = <dynamic>[];
      var total = 0;
      var appointments = 0;
      for (final campus in ['unknown']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/koreatech-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        final rows = raw['courses'] as List;
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final r = rows[i] as Map;
          final metadata = r['metadata'] as Map;
          total++;
          expect(
            metadata['originalEducationalFields'],
            native[c.codeAndSection],
          );
          expect(metadata['actualAttendanceConfirmed'], isFalse);
          expect(metadata['actualPhysicalDatesConfirmed'], isFalse);
          expect(c.code, matches(RegExp(r'^[A-Z]{3}\d{3}$')));
          expect(c.section, matches(RegExp(r'^\d{2}$')));
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          for (final m in c.meetings) {
            appointments++;
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(m.date!.compareTo('2026-08-31'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-06'), lessThanOrEqualTo(0));
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
              '2026-11-02',
            ], isNot(contains(m.date)));
            expect(m.originalStartMinute, greaterThanOrEqualTo(540));
            final nativeClock =
                jsonDecode(
                      File(
                        '${root}bulk-current-native-clock-v5-20261010/proof.json',
                      ).readAsStringSync(),
                    )
                    as Map;
            final proofs = (nativeClock['proofs'] as List)
                .where((p) => p['sourceId'] == c.sourceId)
                .toList();
            if (proofs.isNotEmpty) {
              final expected = proofs.single['expectedWholeMeetings'] as List;
              expect(
                expected.any(
                  (s) =>
                      s['date'] == m.date &&
                      s['weekday'] == m.weekday &&
                      s['startMinute'] == m.originalStartMinute &&
                      s['endMinute'] == m.originalEndMinute &&
                      s['classroom'] == m.classroom,
                ),
                true,
                reason: c.sourceId,
              );
            } else {
              expect(
                m.originalEndMinute,
                lessThanOrEqualTo(
                  const {
                        'MTC743',
                        'MTC753',
                        'MTC905',
                        'MTC906',
                        'MTD431',
                      }.contains(c.code)
                      ? 1140
                      : 1080,
                ),
              );
            }
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 791);
      expect(scheduled, hasLength(59));
      expect(appointments, 1292);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map(
              (dynamic c) =>
                  c.toTimetable(id: c.sourceId, mode: mode) as TimetableClass,
            )
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
        expect(restored, hasLength(59));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final original = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, original.note);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
