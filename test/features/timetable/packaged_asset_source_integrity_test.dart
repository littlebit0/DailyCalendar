// Historical checkpoint 152; not a claim of current school support.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'checkpoint 152 frozen sources preserve identities and schedule roundtrips',
    () {
      final manifest =
          jsonDecode(
                fixtureFile(
                  'work/university-research/checkpoint152-source-manifest.json',
                ).readAsStringSync(),
              )
              as List;
      for (final entry in manifest) {
        final file = fixtureFile(entry['source'] as String);
        expect(
          sha256.convert(file.readAsBytesSync()).toString(),
          entry['frozenSourceSha256'] ?? entry['sha256'],
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
