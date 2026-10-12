// Historical checkpoint 72; not a claim of current school support.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const originalHashes = {
  "work/university-research/catalog-w/mmu/mmu-unknown-2026-2.published-grid-partial-v1.json":
      "55a937a1f3845c6b715a45074dd50100dce1a713ef923bc6056713fcb57339be",
  "work/university-research/catalog-f/kau/kau-main-2026-2.public83-partial-v1.json":
      "d85d11860dc8a56e19d5e688b275ea44ca6cb88549c31746e06fb812c723e6bd",
  "work/university-research/catalog-c/jbnu-current-20261008/jbnu-unknown-medical-document-2026-2.published-partial-20261008.json":
      "f93413ac63c8125f759f3505c89a41e5adb7a7acb9d0f30c07ff88bbef0efd43",
};

void main() {
  test(
    'checkpoint 72 frozen sources preserve identities and schedule roundtrips',
    () {
      final manifest =
          jsonDecode(
                fixtureFile(
                  'work/university-research/checkpoint72-source-manifest.json',
                ).readAsStringSync(),
              )
              as List;
      for (final entry in manifest) {
        final file = fixtureFile(entry['source'] as String);
        expect(
          sha256.convert(file.readAsBytesSync()).toString(),
          originalHashes[entry['source']],
        );
        final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        expect(dataset.courses.length, (raw['courses'] as List).length);
        expect(
          dataset.courses.map((c) => c.sourceId).toSet().length,
          dataset.courses.length,
        );
        for (final course in dataset.courses.where(
          (c) => c.hasSchedulableMeetings,
        )) {
          for (final mode in LectureMode.values) {
            final saved = course.toTimetable(id: course.sourceId, mode: mode);
            final restored = TimetableClass.fromJson(
              jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
            );
            expect(restored.toJson(), saved.toJson(), reason: course.sourceId);
            expect(restored.isValid, saved.isValid, reason: course.sourceId);
          }
        }
      }
    },
  );
}
