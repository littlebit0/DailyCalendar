import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test('GKNU four-year institutional profile rejects another school', () {
    for (final id in [
      'institution:academyinfo:0000021',
      'academyinfo:0000021',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '국립경국대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'gknu');
      expect(profile.timetableCampus, 'unknown');
      expect(profile.academicSourceId, 'gknu');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립경국대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test(
    'GKNU scoped reservations retain unknown delivery in all modes and Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/gknu/';
      final originals =
          (jsonDecode(
                    fixtureFile(
                      '${root}gknu-glocal-2026-2-native-education-rows-v1.json',
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
      for (final campus in ['unknown', 'yecheon']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/gknu-$campus-2026-2.json',
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
          expect(c.code, matches(RegExp(r'^\d{8}$')));
          expect(c.section, '01');
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          for (final m in c.meetings) {
            appointments++;
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-07'), lessThanOrEqualTo(0));
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
            expect(
              date.isBefore(DateTime(2026, 10, 20)) ||
                  date.isAfter(DateTime(2026, 10, 26)),
              isTrue,
            );
            expect(m.originalStartMinute, greaterThanOrEqualTo(540));
            expect(m.originalEndMinute, lessThanOrEqualTo(1070));
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 24);
      expect(scheduled, hasLength(14));
      expect(appointments, 170);
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
        expect(restored, hasLength(14));
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
