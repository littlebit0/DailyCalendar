// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> read(String path) =>
    jsonDecode(
          File(
            path.startsWith('assets/timetable/') &&
                    File(
                      'work/university-research/resume-batch-20261010/before-projection/${path.split('/').last}',
                    ).existsSync()
                ? 'work/university-research/resume-batch-20261010/before-projection/${path.split('/').last}'
                : path,
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  test(
    'Frozen checkpoint74 education and unchanged packages preserve original educational fields',
    () {
      final manifest =
          jsonDecode(
                File(
                  'work/university-research/checkpoint74-source-manifest.json',
                ).readAsStringSync(),
              )
              as List;
      for (final entry in manifest) {
        final expected = read(entry['source'] as String);
        final actual = read(
          entry['file'] == 'assets/timetable/nsu-unknown-2026-2.json'
              ? 'work/university-research/catalog-e/nsu-two-images-semester-v2-20261009/baseline39-current-asset.json'
              : entry['file'] == 'assets/timetable/kmou-unknown-2026-2.json'
              ? 'work/university-research/catalog-c/kmou-elecom-semester-makeup-v3-20261009/prior13-current-asset-snapshot.json'
              : entry['file'] == 'assets/timetable/dongguk-seoul-2026-2.json'
              ? 'work/university-research/remaining-ordinary-native-clock-audit-v1-20261009/dongguk-seoul-2026-2.baseline118.json'
              : entry['file'] as String,
        );
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
        expect(
          actual['courses'],
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
