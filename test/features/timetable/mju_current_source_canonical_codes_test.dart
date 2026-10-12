import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-f/mju/current-six-canonical-code-public-header-v21-20261009';
dynamic read(String path) {
  final actual = path;
  final data = jsonDecode(File(actual).readAsStringSync());
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
const literalCodes = {
  '5880': 'HCA02343',
  '5879': 'HCA02343',
  '5878': 'HCA02313',
  '5889': 'HCA02442',
  '5931': 'HCE06404',
  '5932': 'HCE06405',
};
void main() {
  test(
    'MJU six printed canonical codes,other235 whole,all241/28/496 full3modeDrive',
    () {
      final proof = read(
        '$folder/independent-six-code-whole-preservation-proof.json',
      );
      for (final input in proof['sourceInputs'] as List) {
        expect(
          sha256
              .convert(File(input['path'] as String).readAsBytesSync())
              .toString(),
          input['sha256'],
        );
      }
      final records =
          read(
                '$folder/six-current-registration-public-code-education.json',
              )['records']
              as List;
      expect(records, hasLength(6));
      final prior = <String, dynamic>{};
      final parts = <Map<String, dynamic>>[];
      for (final campus in ['humanities', 'natural', 'unknown']) {
        final old = read(proof['priorPaths'][campus] as String);
        for (final c in old['courses'] as List) {
          prior[c['sourceId'] as String] = c;
        }
        parts.add(
          campus == 'unknown'
              ? read('$folder/mju-unknown-2026-2.six-canonical-code-v21.json')
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
      final changed = (proof['changedSourceIds'] as List)
          .cast<String>()
          .toSet();
      expect(changed, hasLength(6));
      for (final e in prior.entries) {
        final after = current[e.key] as Map<String, dynamic>;
        expect(after['schedules'], e.value['schedules']);
        if (!changed.contains(e.key)) {
          expect(after, e.value);
          continue;
        }
        final record = records.singleWhere((r) => r['sourceId'] == e.key);
        expect(e.value['courseCode'], '');
        expect(
          after['courseCode'],
          literalCodes[record['nativeLectureNumber']],
        );
        expect(after['section'], '');
        expect(after['campus'], 'unknown');
        expect(record['nativeEducationalPlanRows'][0], [
          '교과목코드',
          after['courseCode'],
          '교과목명',
          after['courseName'],
        ]);
        expect(record['nativeEducationalPlanRows'][1][3], after['professor']);
        expect(
          record['observedListRow']['nativeCells'][0],
          '${after['courseName']} (${record['nativeLectureNumber']})',
        );
        expect(record['observedListRow']['nativeCells'][3], after['professor']);
        expect(record['URLNumericCodeOrTermParsed'], false);
        expect(
          after['sourceEducation']['previousResearchDepartmentRemarks'],
          e.value['departmentRemarks'],
        );
        for (final note in (e.value['departmentRemarks'] as Map).entries) {
          expect(
            after['departmentRemarks'][note.key],
            startsWith(note.value as String),
          );
          expect(
            after['departmentRemarks'][note.key],
            contains(after['courseCode']),
          );
        }
        final beforeCopy = clone(e.value as Map<String, dynamic>);
        final afterCopy = clone(after);
        beforeCopy.remove('courseCode');
        afterCopy.remove('courseCode');
        beforeCopy.remove('departmentRemarks');
        afterCopy.remove('departmentRemarks');
        afterCopy['sourceEducation'].remove(
          'additionalOfficialCanonicalCodeEvidence',
        );
        afterCopy['sourceEducation'].remove(
          'previousResearchDepartmentRemarks',
        );
        expect(afterCopy, beforeCopy);
      }
      expect(
        read('$folder/prior-v19-unknown-whole-archive.json'),
        read(proof['priorPaths']['unknown'] as String),
      );
      expect(current['mju/humanities/2026-2/5190']['schedules'], isEmpty);
      for (final ref in ['5339', '5340']) {
        expect(current['mju/unknown/2026-2/$ref']['professor'], '');
        expect(
          current['mju/unknown/2026-2/$ref'],
          prior['mju/unknown/2026-2/$ref'],
        );
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
      }
    },
  );
}
