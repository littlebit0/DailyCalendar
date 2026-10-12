import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-c/hanyang-current-specific-room-correction-v3-20261009/';
const prior =
    'work/university-research/catalog-c/hanyang-ordinary-source-semantic-v2-20261009/';
Map<String, dynamic> read(String p) =>
    jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;
void main() {
  test(
    'current professor-specific room correction preserves original fields and does not activate SMART-F',
    () {
      final raw = File(
        '${root}current-public-notice-independent-20261009.html',
      ).readAsStringSync();
      final text = raw
          .replaceAll(RegExp('<[^>]*>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('26-2학기'));
      expect(text, contains('8월 21일'));
      expect(text, contains('윤성현'));
      expect(text, contains('제3법학관'));
      expect(text, contains('103호'));
      final old = read(
        '${prior}hanyang-seoul-2026-2.ordinary-source-semantic-candidate-v2.json',
      );
      final now = read(
        '${root}hanyang-seoul-2026-2.current-specific-room-correction-candidate-v3.json',
      );
      final before = {for (final c in old['courses']) c['sourceId']: c};
      var changed = 0;
      for (final c in now['courses']) {
        final b = before[c['sourceId']];
        expect(c['schedules'], b['schedules']);
        if (c['sourceId'] != 'hanyang/seoul/2026-2/11311') {
          expect(c, b);
          continue;
        }
        changed++;
        expect(c['courseCode'], 'PPL1021');
        expect(c['section'], '00');
        expect(c['professor'], '윤성현');
        expect(c['schedules'], isEmpty);
        expect(c['scheduleStatus'], b['scheduleStatus']);
        expect(c['sourceSchedule'], '화(14:30-16:00),수(14:30-16:00)');
        expect(c['sourceClassroom'], '서울 제3법학관 103호,서울 제3법학관 103호');
        final original = c['metadata']['originalEducationalRecord'];
        expect(original, b['metadata']['originalEducationalRecord']);
        final correction = c['metadata']['currentOfficialClassroomCorrection'];
        expect(correction['originalSourceClassroom'], b['sourceClassroom']);
        expect(
          correction['changedClassroomHasNoPublishedBuildingNumericCode'],
          true,
        );
        expect(correction['exactProfessor'], '윤성현');
        final restored = Map<String, dynamic>.from(c);
        for (final field in [
          'sourceClassroom',
          'remarks',
          'departmentRemarks',
        ]) {
          restored[field] = b[field];
        }
        restored['metadata'] = Map<String, dynamic>.from(c['metadata'])
          ..remove('currentOfficialClassroomCorrection');
        expect(restored, b);
        for (final value in c['departmentRemarks'].values) {
          expect(value, contains('윤성현'));
          expect(value, contains('제3법학관103'));
        }
      }
      expect(changed, 1);
      expect(now['courses'], hasLength(2805));
      final other = now['courses'].singleWhere(
        (c) => c['sourceId'] == 'hanyang/seoul/2026-2/12506',
      );
      expect(other, before[other['sourceId']]);
    },
  );
  test(
    'all3455 reservations and fullthree-mode Drive retained across Seoul andERICA',
    () {
      final all = [
        ...UniversityDataset.fromJson(
          read(
            '${root}hanyang-seoul-2026-2.current-specific-room-correction-candidate-v3.json',
          ),
        ).courses,
        ...UniversityDataset.fromJson(
          read(
            '${prior}hanyang-erica-2026-2.ordinary-source-semantic-candidate-v2.json',
          ),
        ).courses,
      ];
      expect(all, hasLength(4961));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(3455));
      expect(scheduled.expand((c) => c.meetings).length, 83940);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final records = <String, TimetableSyncValue>{};
        for (final c in scheduled) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true);
          expect(t.defaultMode, mode);
          expect(TimetableClass.fromJson(t.toJson()).toJson(), t.toJson());
          final key = timetableCourseSyncKey(t);
          expect(records.containsKey(key), false);
          records[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        final doc = TimetableSyncDocument.records(courses: records);
        expect(
          TimetableSyncDocument.fromJson(
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
          ).toJson(),
          doc.toJson(),
        );
      }
    },
  );
}
