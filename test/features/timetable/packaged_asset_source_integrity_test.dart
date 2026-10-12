import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'Packaged university rows equal frozen education sources without rewriting educational fields',
    () {
      final manifest =
          jsonDecode(
                File(
                  'work/university-research/checkpoint152-source-manifest.json',
                ).readAsStringSync(),
              )
              as List;
      for (final entry in manifest) {
        final expected = read(entry['source'] as String);
        final actual = read(entry['file'] as String);
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
