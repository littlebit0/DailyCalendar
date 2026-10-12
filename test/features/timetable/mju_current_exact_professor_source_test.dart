import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-f/mju/current-bulk-professor-transcription-correction-v19-20261009';
const correctedId = 'mju/unknown/2026-2/5932';
dynamic read(String path) {
  final actual = path;
  final data = jsonDecode(fixtureFile(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

Map<String, dynamic> clone(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

void main() {
  test(
    'MJU original professor correction only, prior240 whole, all241/28/496 three-mode Drive',
    () {
      final proof = read('$folder/whole-preservation-correction-proof.json');
      for (final input in proof['sourceInputs'] as List) {
        expect(
          sha256
              .convert(fixtureFile(input['path'] as String).readAsBytesSync())
              .toString(),
          input['sha256'],
        );
      }
      final receipt = read(
        '$folder/independent-original-professor-correction-receipt.json',
      );
      expect(receipt['sourceId'], correctedId);
      expect(receipt['rootIndependentOriginalImageReReviewConfirmed'], true);
      expect(receipt['exactObservedMenuRow']['nativeCells'], [
        '창의혁신리더십론 (5932)',
        '4학년',
        '이론',
        '양등월',
      ]);
      final prior = <String, dynamic>{};
      final parts = <Map<String, dynamic>>[];
      for (final campus in ['humanities', 'natural', 'unknown']) {
        final old = read(proof['priorPaths'][campus] as String);
        for (final c in old['courses'] as List) {
          prior[c['sourceId'] as String] = c;
        }
        parts.add(
          campus == 'unknown'
              ? read(
                  '$folder/mju-unknown-2026-2.business-bulk-professor-corrected-v19.json',
                )
              : old,
        );
      }
      final current = <String, dynamic>{};
      for (final part in parts) {
        for (final c in part['courses'] as List) {
          expect(current.containsKey(c['sourceId']), false);
          current[c['sourceId'] as String] = c;
        }
      }
      expect(prior, hasLength(241));
      expect(current.keys.toSet(), prior.keys.toSet());
      for (final e in prior.entries) {
        if (e.key != correctedId) {
          expect(current[e.key], e.value);
        } else {
          final before = clone(e.value as Map<String, dynamic>);
          final after = clone(current[e.key] as Map<String, dynamic>);
          expect(before['professor'], '양동열');
          expect(after['professor'], '양등월');
          expect(
            after['sourceEducation']['nativePublicCells']['professor'],
            '양등월',
          );
          before.remove('professor');
          after.remove('professor');
          before['sourceEducation']['nativePublicCells'].remove('professor');
          after['sourceEducation']['nativePublicCells'].remove('professor');
          before['sourceEducation']['nativePublicCells'].remove(
            'professorVisualConfidence',
          );
          after['sourceEducation']['nativePublicCells'].remove(
            'professorVisualConfidence',
          );
          after['sourceEducation'].remove(
            'nativeProfessorTranscriptionCorrection',
          );
          expect(after, before);
        }
        expect(current[e.key]['schedules'], e.value['schedules']);
      }
      expect(current['mju/humanities/2026-2/5190']['schedules'], isEmpty);
      final archived = read('$folder/prior-v11-unknown-whole-archive.json');
      expect(archived, read(proof['priorPaths']['unknown'] as String));
      final originalRows =
          read('$folder/prior-v11-native21-transcription-archive.json')['rows']
              as List;
      final correctedRows =
          read('$folder/corrected-native21-transcription.json')['rows'] as List;
      expect(originalRows, hasLength(21));
      expect(correctedRows, hasLength(21));
      for (var i = 0; i < originalRows.length; i++) {
        if (originalRows[i]['nativeLectureNumber'] != '5932') {
          expect(correctedRows[i], originalRows[i]);
        } else {
          expect(originalRows[i]['professor'], '양동열');
          expect(correctedRows[i]['professor'], '양등월');
        }
      }
      final courses = parts
          .expand((d) => UniversityDataset.fromJson(d).courses)
          .toList();
      expect(courses, hasLength(241));
      final plans = courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(plans, hasLength(28));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 496);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = plans
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        final expected = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(28));
        expect(restored.map((c) => c.sourceId).toSet(), expected.keys.toSet());
        for (final c in restored) {
          expect(
            c.toJson()..remove('id'),
            expected[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.isValid, true);
          for (final meeting in c.meetings) {
            expect(c.modeOn(meeting, DateTime.parse(meeting.date!)), mode);
          }
        }
        expect(
          restored.singleWhere((c) => c.sourceId == correctedId).professor,
          '양등월',
        );
      }
    },
  );
}
