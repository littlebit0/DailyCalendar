import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'Kongju institutional profile uses the published Cheonan scoped dataset',
    () {
      for (final id in [
        'institution:academyinfo:0000008',
        'academyinfo:0000008',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '국립공주대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'kongju');
        expect(profile.timetableCampus, 'cheonan');
        expect(profile.academicSourceId, 'kongju');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '국립공주대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          isFalse,
        );
      }
    },
  );
  test(
    'Kongju scoped reservations retain unknown delivery in all modes and Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/kongju/';
      final originals =
          (jsonDecode(
                    fixtureFile(
                      '${root}kongju-contract-2026-2-educational-rows-v1.json',
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
      for (final campus in ['cheonan']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/kongju-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final originalIds =
            (jsonDecode(
                      fixtureFile(
                        '${root}current-whole-lecture-list-followup-20261008/baseline-cheonan65-frozen.json',
                      ).readAsStringSync(),
                    )['courses']
                    as List)
                .map((c) => c['sourceId'])
                .toSet();
        raw['courses'] = (raw['courses'] as List)
            .where((c) => originalIds.contains(c['sourceId']))
            .toList();
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
          expect(c.code, matches(RegExp(r'^\d{7}$')));
          expect(c.section, matches(RegExp(r'^\d{2}$')));
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          for (final m in c.meetings) {
            appointments++;
            expect(m.weekday, 6);
            final original = metadata['originalEducationalFields'] as Map;
            int minute(String value) =>
                int.parse(value.substring(0, 2)) * 60 +
                int.parse(value.substring(3));
            expect(
              m.originalStartMinute,
              minute(original['startTime'] as String),
            );
            expect(m.originalEndMinute, minute(original['endTime'] as String));
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-07'), lessThanOrEqualTo(0));
            expect([
              '2026-09-26',
              '2026-10-03',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
            expect(
              date.isBefore(DateTime(2026, 10, 20)) ||
                  date.isAfter(DateTime(2026, 10, 26)),
              isTrue,
            );
            expect(m.originalStartMinute, greaterThanOrEqualTo(510));
            expect(m.originalEndMinute, lessThanOrEqualTo(1220));
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 65);
      expect(scheduled, hasLength(22));
      expect(appointments, 242);
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
        expect(restored, hasLength(22));
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
