import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'Historical checkpoint71 identities survive current catalog expansion including CELL union',
    () {
      final manifest =
          jsonDecode(
                File(
                  'work/university-research/checkpoint71-source-manifest.json',
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
        final current = {
          for (final course in actual['courses'] as List)
            course['sourceId']: course,
        };
        expect(current.length, (actual['courses'] as List).length);
        for (final previous in expected['courses'] as List) {
          final course = current[previous['sourceId']];
          expect(course, isNotNull, reason: entry['file'] as String);
          for (final field in [
            'sourceId',
            'courseCode',
            'section',
            'courseName',
            'academicYear',
            'semester',
            'campus',
          ]) {
            expect(
              course[field],
              previous[field],
              reason: '${entry['file']} $field',
            );
          }
        }
        expect(actual['researchOnly'], false);
        expect(actual['productionIntegrationEnabled'], true);
        expect(actual['completionClaim'], false);
        expect(actual['wholeOperatingVerified'], false);
      }
    },
  );
}
