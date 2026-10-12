// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-r/knu/current-department-allocation-followup-20261008/';
  dynamic read(String name) =>
      jsonDecode(File('$root$name').readAsStringSync());
  final candidate =
      jsonDecode(
            File(
              'work/university-research/resume-batch-20261010/before-projection/knu-daegu-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final baseline =
      read('baseline-knu-daegu-2026-2.json') as Map<String, dynamic>;
  final source =
      read('current-midterm-education-all-rows.json') as Map<String, dynamic>;
  const selected = ['ELEC0214-004', 'ELEC0321-006'];

  test(
    'Current undergraduate attachment and independent native join yield exactly two exams',
    () {
      expect(source['title'], '2026.2학기 중간시험 일정표');
      expect(source['pagesVisuallyReviewed'], [1, 2, 3, 4, 5, 6]);
      expect(source['rows'], hasLength(151));
      expect(source['noticeBodyContradiction'], contains('2025'));
      final native =
          read('independent-prior-native-two-course-education.json') as List;
      for (final c in candidate['courses'] as List) {
        final key = '${c['courseCode']}-${c['section']}';
        if (!selected.contains(key)) {
          continue;
        }
        final row = (source['rows'] as List).singleWhere(
          (r) => r['nativeOffering'] == key,
        );
        final original = native.firstWhere((r) => r['crseNo'] == key);
        expect(original['estblYear'], '2026');
        expect(original['estblSmstrSctcd'], 'CMBS001400002');
        expect(c['sourceSchedule'], original['lssnsRealTimeInfo']);
        expect(
          c['sourceClassroom'],
          '${original['lctrmInfo']} / ${original['rmnmCd']}',
        );
        expect(
          c['professor'],
          (row['professor'] as String).replaceAll('\n', ''),
        );
        expect(c['courseName'], row['courseTitle']);
        final md = (row['examDateRaw'] as String)
            .split(', ')
            .first
            .split('/')
            .map(int.parse)
            .toList();
        final date = DateTime(2026, md[0], md[1]);
        final m = (c['schedules'] as List).single;
        expect(
          m['date'],
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        );
        expect(m['weekday'], date.weekday);
        expect(
          date.weekday,
          key == 'ELEC0214-004' ? DateTime.tuesday : DateTime.saturday,
        );
        final clock = (row['examClockRaw'] as String).split('~');
        int minutes(String s) {
          final parts = s.split(':').map(int.parse).toList();
          return parts[0] * 60 + parts[1];
        }

        expect(m['startMinute'], minutes(clock[0]));
        expect(m['endMinute'], minutes(clock[1]));
        expect(m['classroom'], row['examRoomsRaw']);
        expect(
          c['sourceEducationalMetadata']['individualExamRoomAllocationUnknown'],
          true,
        );
        expect(date.isBefore(DateTime(2026, 9, 1)), false);
        expect(date.isAfter(DateTime(2026, 12, 18)), false);
      }
      expect(candidate['completionClaim'], false);
      expect(candidate['period'], baseline['period']);
    },
  );

  test(
    'Full immutable baseline and every unrelated held or scheduled course stay deep equal',
    () {
      final before = {
        for (final c in baseline['courses'] as List) c['sourceId']: c,
      };
      expect(candidate['courses'], hasLength(3117));
      var modified = 0;
      for (final c in candidate['courses'] as List) {
        final key = '${c['courseCode']}-${c['section']}';
        if (!selected.contains(key)) {
          expect(c, before[c['sourceId']]);
          continue;
        }
        modified++;
        final old = before[c['sourceId']];
        expect(old['schedules'], isEmpty);
        for (final field in old.keys) {
          if ([
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
          ].contains(field)) {
            continue;
          }
          expect(c[field], old[field], reason: field);
        }
        expect(c['schedules'], hasLength(1));
      }
      expect(modified, 2);
      expect(
        (candidate['courses'] as List).where(
          (c) => (c['schedules'] as List).isEmpty,
        ),
        hasLength(55),
      );
    },
  );

  test(
    'Actual full current course model preserves two exact exams in all three modes through complete Drive JSON',
    () {
      final ds = UniversityDataset.fromJson(candidate);
      expect(ds.courses, hasLength(3117));
      final usable = ds.courses.where((c) => c.hasSchedulableMeetings).toList();
      expect(usable, hasLength(3062));
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
        expect(restored, hasLength(3062));
        final original = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            original[c.sourceId]!.toJson()..remove('id'),
          );
          if (c.sourceId == 'knu/daegu/2026/2/ELEC0214/004' ||
              c.sourceId == 'knu/daegu/2026/2/ELEC0321/006') {
            expect(c.meetings, hasLength(1));
            expect(c.note, contains('개인별 배정은 미확인'));
          }
        }
      }
    },
  );
}
