import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'Hanbat scoped reservations retain unknown delivery in all modes and Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/hanbat/';
      final originals =
          (jsonDecode(
                    fixtureFile(
                      '${root}hanbat-current-2026-2-native-education-rows-v1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['rows']
              as List;
      final native = {
        for (final row in originals) '${row['nativeLectureId']}': row,
      };
      final scheduled = <dynamic>[];
      var total = 0;
      var appointments = 0;
      for (final campus in ['daejeon', 'sejong']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/hanbat-$campus-2026-2.json',
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
            native[(metadata['originalEducationalFields']
                    as Map)['nativeLectureId']
                .toString()],
          );
          expect(
            (metadata['originalEducationalFields'] as Map)['campus'],
            raw['campusName'],
          );
          expect(
            c.sourceId.endsWith(
              '/${(metadata['originalEducationalFields'] as Map)['nativeLectureId']}',
            ),
            isTrue,
          );
          expect(
            c.sourceClassification,
            (metadata['originalEducationalFields'] as Map)['classification'],
          );
          expect(metadata['actualAttendanceConfirmed'], isFalse);
          expect(metadata['actualPhysicalDatesConfirmed'], isFalse);
          expect(c.code, matches(RegExp(r'^[A-Z]+\d+$')));
          expect(c.section, matches(RegExp(r'^\d{2}$')));
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          for (final m in c.meetings) {
            appointments++;
            if (m.weekday == 6 && m.originalStartMinute == 895) {
              expect(m.originalEndMinute, 945);
            }
            if (m.weekday != 6 && m.originalStartMinute == 1120) {
              expect(m.originalEndMinute, 1170);
            }
            expect(m.originalEndMinute - m.originalStartMinute, 50);
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-14'), lessThanOrEqualTo(0));
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
              '2026-09-26',
              '2026-10-03',
            ], isNot(contains(m.date)));
            expect(m.originalStartMinute, greaterThanOrEqualTo(540));
            expect(m.originalEndMinute, lessThanOrEqualTo(1340));
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 1698);
      expect(scheduled, hasLength(1611));
      expect(appointments, 72676);
      expect(
        scheduled.any(
          (dynamic c) => c.meetings.any(
            (dynamic m) =>
                m.weekday == 6 &&
                m.originalStartMinute == 895 &&
                m.originalEndMinute == 945,
          ),
        ),
        isTrue,
      );
      expect(
        scheduled.any(
          (dynamic c) => c.meetings.any(
            (dynamic m) =>
                m.weekday != 6 &&
                m.originalStartMinute == 1120 &&
                m.originalEndMinute == 1170,
          ),
        ),
        isTrue,
      );
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
        expect(restored, hasLength(1611));
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
