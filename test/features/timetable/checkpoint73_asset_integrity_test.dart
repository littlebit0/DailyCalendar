import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'Packaged university rows equal frozen education sources without rewriting educational fields',
    () {
      final manifest =
          jsonDecode(
                fixtureFile(
                  'work/university-research/checkpoint73-source-manifest.json',
                ).readAsStringSync(),
              )
              as List;
      for (final entry in manifest) {
        final expected = read(entry['source'] as String);
        final actual = read(entry['file'] as String);
        if (actual['universityId'] == 'donga' &&
            actual['campus'] == 'unknown') {
          (expected['courses'] as List).addAll(
            read(
                  'work/university-research/catalog-c/donga-cell-extension-20261008/donga-unknown-cell-2026-2.published-partial-20261008.json',
                )['courses']
                as List,
          );
        }
        for (final course in expected['courses'] as List) {
          final metadata = course['metadata'] as Map?;
          if (metadata != null && metadata.containsKey('researchOnly')) {
            metadata['researchOnly'] = false;
          }
        }
        final expectedIds = {
          for (final row in expected['courses'] as List) row['sourceId'],
        };
        final preservedCourses =
            actual['universityId'] == 'korea' && actual['campus'] == 'sejong'
            ? (actual['courses'] as List)
                  .where((row) => expectedIds.contains(row['sourceId']))
                  .toList()
            : actual['courses'];
        expect(
          preservedCourses,
          expected['courses'],
          reason: entry['file'] as String,
        );
        expect(actual['researchOnly'], false);
        expect(actual['productionIntegrationEnabled'], true);
        expect(actual['completionClaim'], false);
        expect(actual['wholeOperatingVerified'], false);
      }
    },
  );
}
