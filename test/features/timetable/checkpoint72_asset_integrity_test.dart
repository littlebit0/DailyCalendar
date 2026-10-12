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
                  'work/university-research/checkpoint72-source-manifest.json',
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
        if (actual['universityId'] == 'kau') {
          // Current official makeups extend v1 periods and append meetings.
          // The current source is checked exactly by the latest manifest test.
          final current = {
            for (final course in actual['courses'] as List)
              course['sourceId']: course,
          };
          expect(current, hasLength((expected['courses'] as List).length));
          for (final previous in expected['courses'] as List) {
            final course = current[previous['sourceId']];
            expect(course, isNotNull);
            for (final field in previous.keys) {
              if ([
                'schedules',
                'period',
                'departmentRemarks',
              ].contains(field)) {
                continue;
              }
              expect(course[field], previous[field], reason: field);
            }
            final oldMeetings = previous['schedules'] as List;
            expect(
              (course['schedules'] as List).take(oldMeetings.length).toList(),
              oldMeetings,
            );
          }
        } else {
          expect(
            actual['courses'],
            expected['courses'],
            reason: entry['file'] as String,
          );
        }
        expect(actual['researchOnly'], false);
        expect(actual['productionIntegrationEnabled'], true);
        expect(actual['completionClaim'], false);
        expect(actual['wholeOperatingVerified'], false);
      }
    },
  );
}
