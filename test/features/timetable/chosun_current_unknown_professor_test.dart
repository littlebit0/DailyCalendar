import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-c/chosun-unassigned-professor-ordinary-v7-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path.startsWith('${root}chosun-unknown-')
      ? 'assets/timetable/chosun-unknown-2026-2.json'
      : path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  if (data['courses'] is List) {
    data['researchOnly'] = false;
    for (final c in data['courses']) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  test(
    'three professor-unknown ordinary exact native clocks and prior132 full preservation',
    () {
      final old = read('${root}baseline-v5-frozen.json');
      final raw = read(
        '${root}chosun-unknown-2026-2.unassigned-professor-ordinary-v7.json',
      );
      final proof =
          jsonDecode(
                File(
                  '${root}independent3-native-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      final ids = {for (final p in proof) p['sourceId']};
      expect(ids, hasLength(3));
      final before = {for (final c in old['courses']) c['sourceId']: c};
      final all = UniversityDataset.fromJson(raw).courses;
      expect(all, hasLength(135));
      expect(all.where((c) => c.hasSchedulableMeetings), hasLength(96));
      expect(all.expand((c) => c.meetings), hasLength(1133));
      for (final c in raw['courses']) {
        final previous = before[c['sourceId']];
        if (!ids.contains(c['sourceId'])) {
          expect(c, previous);
          continue;
        }
        expect(previous['schedules'], isEmpty);
        expect(
          c['sourceEducation']['nativePublicBlock'],
          previous['sourceEducation']['nativePublicBlock'],
        );
        for (final field in [
          'sourceId',
          'courseName',
          'professor',
          'section',
          'sourceSchedule',
          'sourceClassroom',
          'departments',
          'campus',
          'courseCode',
          'classification',
          'credits',
        ]) {
          expect(c[field], previous[field]);
        }
        final p = proof.singleWhere((p) => p['sourceId'] == c['sourceId']);
        expect(c['schedules'], p['dates']);
        expect(c['professor'], anyOf('', '000'));
        expect(c['schedules'], hasLength(12));
        final block = p['nativeBlock'];
        expect(block['heldReasons'], ['nativeProfessorUnassigned']);
        expect(block['grade'], 1);
        expect(block['firstHeader'], block['lastHeader']);
        final course = all.singleWhere((v) => v.sourceId == c['sourceId']);
        for (final meeting in course.meetings) {
          expect(
            meeting.originalStartMinute,
            block['firstHeader']['startMinute'],
          );
          expect(meeting.originalEndMinute, block['lastHeader']['endMinute']);
          expect(meeting.weekday, block['weekday']);
          expect(meeting.classroom, block['classroom']);
          expect(
            meeting.date!.compareTo('2026-09-01') >= 0 &&
                meeting.date!.compareTo('2026-12-07') <= 0,
            true,
          );
        }
      }
    },
  );
  test(
    'whole96 fullthree modeDrive preserves empty professor and exact meetings',
    () {
      final all = UniversityDataset.fromJson(
        read(
          '${root}chosun-unknown-2026-2.unassigned-professor-ordinary-v7.json',
        ),
      ).courses.where((c) => c.hasSchedulableMeetings);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final records = <String, TimetableSyncValue>{};
        for (final c in all) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true);
          expect(t.professor, c.professor);
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
        expect(records, hasLength(96));
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
