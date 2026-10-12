import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-f/mju/current-electronics-ie-reference-v4-20261009';
Map<String, dynamic> read(String path) {
  final actual = path;
  return jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  test(
    'MJU11 current native references preserve all prior209 objects and full three-mode Drive',
    () {
      final proof = read(
        '$folder/independent-native-reference-preservation-proof.json',
      );
      for (final row in proof['sourceInputs'] as List) {
        expect(
          sha256
              .convert(File(row['path'] as String).readAsBytesSync())
              .toString(),
          row['sha256'],
        );
      }
      final prior = <String, dynamic>{};
      final parts = <Map<String, dynamic>>[];
      for (final campus in ['humanities', 'natural', 'unknown']) {
        final original = read(proof['priorDatasetPaths'][campus] as String);
        for (final row in original['courses'] as List) {
          prior[row['sourceId'] as String] = row;
        }
        parts.add(
          campus == 'unknown'
              ? read(
                  '$folder/mju-unknown-2026-2.electronics-ie-reference-v4.json',
                )
              : original,
        );
      }
      expect(prior, hasLength(209));
      final current = <String, dynamic>{};
      for (final part in parts) {
        for (final c in part['courses'] as List) {
          expect(current.containsKey(c['sourceId']), false);
          current[c['sourceId'] as String] = c;
        }
      }
      expect(current, hasLength(220));
      for (final entry in prior.entries) {
        expect(current[entry.key], entry.value);
      }
      final newProofs = proof['proofs'] as List;
      expect(newProofs, hasLength(11));
      for (final p in newProofs) {
        final c = current[p['sourceId']] as Map;
        expect(prior.containsKey(p['sourceId']), false);
        final row = p['nativeRow'] as Map;
        final nativeSource = read(p['sourceFile'] as String);
        expect(
          (nativeSource['educationRows'] as List)
              .where(
                (r) => r['nativeLectureNumber'] == row['nativeLectureNumber'],
              )
              .single,
          row,
        );
        expect(
          c['sourceId'],
          'mju/unknown/2026-2/${row['nativeLectureNumber']}',
        );
        expect(c['academicYear'], 2026);
        expect(c['semester'], '2');
        expect(c['courseName'], row['courseName']);
        expect(c['professor'], row['professor']);
        expect(c['campus'], 'unknown');
        expect(c['courseCode'], '');
        expect(c['section'], '');
        expect(c['sourceSchedule'], '');
        expect(c['sourceClassroom'], '');
        expect(c['schedules'], isEmpty);
        expect(c['sourceEducation']['nativePublicCells'], row);
        expect(c['sourceEducation']['closed'], false);
        final restrictions =
            nativeSource['nativeRestrictionStatements'] ??
            nativeSource['nativeStatements'];
        expect(
          c['sourceEducation']['nativeRestrictionStatements'],
          restrictions,
        );
        for (final literal in restrictions as List) {
          expect(
            (c['departmentRemarks'] as Map).values.single,
            contains(literal),
          );
        }
      }
      expect(current.containsKey('mju/unknown/2026-2/0536'), false);
      expect(current.containsKey('mju/unknown/2026-2/0537'), false);
      expect(current['mju/unknown/2026-2/0557']['courseName'], '자료구죠');
      expect(
        current['mju/unknown/2026-2/0558']['sourceEducation']['nativePublicCells']['scope'],
        '증원불가; 폐강 뜻 아님',
      );
      final courses = parts
          .expand((part) => UniversityDataset.fromJson(part).courses)
          .toList();
      expect(courses, hasLength(220));
      final scheduled = courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(scheduled, hasLength(7));
      expect(scheduled.fold<int>(0, (n, c) => n + c.meetings.length), 172);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
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
        final lookup = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(7));
        expect(restored.map((c) => c.sourceId).toSet(), lookup.keys.toSet());
        for (final c in restored) {
          expect(
            c.toJson()..remove('id'),
            lookup[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.isValid, true);
          for (final meeting in c.meetings) {
            expect(c.modeOn(meeting, DateTime.parse(meeting.date!)), mode);
            expect(DateTime.parse(meeting.date!).weekday, meeting.weekday);
          }
        }
      }
    },
  );
}
