import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'INU physical campus filters partition all native courses without changing stable identity or any source field',
    () {
      const root = 'work/university-research/catalog-f/inu/';
      final prior =
          jsonDecode(
                File(
                  '${root}inu-main-2026-2.whole2437-partial-dated-v2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final priorById = {
        for (final c in prior['courses'] as List) c['sourceId']: c,
      };
      final datasets = <UniversityDataset>[];
      final sourceIds = <String>{};
      const expected = {
        'songdo': 2043,
        'michuhol': 141,
        'multiple': 2,
        'unknown': 251,
      };
      for (final campus in expected.keys) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/inu-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(raw['completionClaim'], false);
        expect(raw['wholeSchoolCourseCoverageComplete'], false);
        final dataset = UniversityDataset.fromJson(raw);
        datasets.add(dataset);
        expect(dataset.campus, campus);
        expect(dataset.courses, hasLength(expected[campus]!));
        for (final c in raw['courses'] as List) {
          expect(sourceIds.add(c['sourceId'] as String), true);
          expect(c['sourceId'], startsWith('inu/main/2026-2/'));
          final original = priorById[c['sourceId']] as Map;
          // Reservations can be extended; original educational cells and
          // native identity must still survive the campus partition.
          expect(c['sourceEducation'], original['sourceEducation']);
          for (final field in [
            'sourceId',
            'courseCode',
            'section',
            'courseName',
            'professor',
            'credits',
            'sourceSchedule',
            'sourceClassroom',
          ]) {
            expect(
              c[field],
              original[field],
              reason: '${c['sourceId']}/$field',
            );
          }
          final education = c['sourceEducation'] as Map;
          final names = education['publicRoomCampusNames'] as List;
          if (campus == 'unknown') {
            expect(education['publicRoomCampusMappingComplete'], false);
          } else {
            expect(education['publicRoomCampusMappingComplete'], true);
            expect(
              names.toSet(),
              campus == 'multiple'
                  ? {'송도캠퍼스', '미추홀캠퍼스'}
                  : {campus == 'songdo' ? '송도캠퍼스' : '미추홀캠퍼스'},
            );
          }
        }
      }
      expect(sourceIds, priorById.keys.toSet());
      expect(sourceIds, hasLength(2437));
      final all = datasets.expand((d) => d.courses).toList();
      final scheduled = all.where((c) => c.meetings.isNotEmpty).toList();
      expect(scheduled, hasLength(1975));
      expect(scheduled.fold<int>(0, (n, c) => n + c.meetings.length), 62689);
      expect(all.every((c) => c.section.isEmpty), true);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(1975));
        final lookup = {for (final c in originals) c.sourceId: c};
        expect(restored.map((c) => c.sourceId).toSet(), lookup.keys.toSet());
        for (final c in restored) {
          final original = lookup[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.note, original.note);
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          final restoredJson = c.toJson()..remove('id');
          final originalJson = original.toJson()..remove('id');
          expect(restoredJson, originalJson);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
