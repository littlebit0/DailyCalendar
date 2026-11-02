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

  test(
    'Kongju explicit official periods resolved in #570 follow the published clock',
    () {
      final resolved = <String, Map<String, dynamic>>{};
      var unrecognized = 0;
      for (final campus in ['cheonan', 'singwan', 'yesan', 'unknown']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/kongju-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final c in (raw['courses'] as List).cast<Map<String, dynamic>>()) {
          if (c['scheduleStatus'] == 'unrecognized') unrecognized++;
          final meta = c['sourceEducationalMetadata'] as Map?;
          if (meta?['resolvedHoldReasons'] != null) {
            resolved[c['courseCode'] as String] = c;
          }
        }
      }
      expect(unrecognized, 633);
      expect(resolved, hasLength(19));
      const holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (final c in resolved.values) {
        final meta = c['sourceEducationalMetadata'] as Map;
        expect(c['scheduleStatus'], 'scheduled');
        expect(meta['holdReasons'], isEmpty);
        expect(c['remarks'], isNot(contains('보류')));
        for (final variant in meta['originalPublishedRowVariants'] as List) {
          expect(variant['periodRaw'], c['sourceSchedule']);
        }
        for (final s in (c['schedules'] as List).cast<Map>()) {
          final date = DateTime.parse(s['date'] as String);
          expect(date.weekday, s['weekday']);
          expect(s['date'].compareTo('2026-09-01'), greaterThanOrEqualTo(0));
          expect(s['date'].compareTo('2026-12-07'), lessThanOrEqualTo(0));
          expect(holidays, isNot(contains(s['date'])));
          expect(
            date.isBefore(DateTime(2026, 10, 20)) ||
                date.isAfter(DateTime(2026, 10, 26)),
            isTrue,
          );
          // 강의일람표 table 212: 교시 p는 (8+p):00 시작, 50분 수업 + 10분
          // 쉬는 시간 = 60분 슬롯. 연속 교시는 한 구간으로 합친다.
          expect((s['startMinute'] as int) % 60, 0);
          expect((s['endMinute'] as int) % 60, 0);
          expect(s['startMinute'], greaterThanOrEqualTo(540));
          expect(s['endMinute'], lessThanOrEqualTo(1080));
        }
      }
      Set<String> slots(String code) => {
        for (final s in (resolved[code]!['schedules'] as List).cast<Map>())
          '${s['weekday']} ${s['startMinute']}-${s['endMinute']} ${s['classroom']}',
      };
      // 수7.8.9 [(인문214)]
      expect(slots('200224401'), {'3 900-1080 (인문214)'});
      // 화6,7 / 화8.9 with one room per published line.
      expect(slots('200365301'), {'2 840-960 (10공715)', '2 960-1080 (10공805)'});
      // 월7 월8 월9: 요일·교시·강의실이 같아 한 구간으로 합쳐진다.
      expect(slots('000131302'), {'1 900-1080 9공605'});
    },
  );

  test('Kongju 교시 계산 구간은 쉬는 시간 포함 60분 슬롯이고 연속 구간이 남지 않는다', () {
    for (final campus in ['cheonan', 'singwan', 'yesan', 'unknown']) {
      final raw =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/kongju-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final c in (raw['courses'] as List).cast<Map<String, dynamic>>()) {
        final schedules = (c['schedules'] as List).cast<Map>();
        // 원문이 시계 시각(HH:mm)을 직접 적은 강좌는 그 시각을 그대로 둔다.
        if (RegExp(r'\d\d:\d\d').hasMatch(c['sourceSchedule'] as String)) {
          continue;
        }
        Map? previous;
        for (final s in schedules) {
          final reason = '${c['sourceId']} ${s['date']}';
          expect((s['startMinute'] as int) % 60, 0, reason: reason);
          expect((s['endMinute'] as int) % 60, 0, reason: reason);
          expect(s['endMinute'], lessThanOrEqualTo(1080), reason: reason);
          if (previous != null &&
              previous['date'] == s['date'] &&
              previous['classroom'] == s['classroom']) {
            expect(
              (s['startMinute'] as int) - (previous['endMinute'] as int),
              greaterThanOrEqualTo(60),
              reason: reason,
            );
          }
          previous = s;
        }
      }
    }
  });
}
