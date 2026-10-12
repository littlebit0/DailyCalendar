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
    'Packaged university rows equal frozen education sources without rewriting educational fields',
    () {
      final manifest =
          jsonDecode(
                File(
                  'work/university-research/checkpoint75-source-manifest.json',
                ).readAsStringSync(),
              )
              as List;
      for (final entry in manifest) {
        final expected = read(entry['source'] as String);
        final actual = read(
          entry['file'] == 'assets/timetable/nsu-unknown-2026-2.json'
              ? 'work/university-research/catalog-e/nsu-two-images-semester-v2-20261009/baseline39-current-asset.json'
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
        if (actual['universityId'] == 'kaist' ||
            actual['universityId'] == 'ut') {
          final currentById = {
            for (final row in actual['courses'] as List) row['sourceId']: row,
          };
          final archivedNotes = actual['universityId'] == 'ut'
              ? jsonDecode(
                      File(
                        'work/university-research/catalog-c/ut-current-own-regular-planned-dates-v6-20261009/full-prior-research-note-external-archive.json',
                      ).readAsStringSync(),
                    )
                    as List
              : <dynamic>[];
          for (final row in expected['courses'] as List) {
            final current = Map<String, dynamic>.from(
              currentById[row['sourceId']] as Map,
            );
            if (actual['universityId'] == 'ut') {
              final note = archivedNotes.singleWhere(
                (n) => n['sourceId'] == row['sourceId'],
              );
              expect(note['previousWholeResearchRemarks'], row['remarks']);
              expect(
                current['remarks'],
                (row['remarks'] as String).replaceFirst(
                  note['exactRemovedResearchScopePhrase'] as String,
                  note['exactReplacementResearchScopePhrase'] as String,
                ),
              );
              expect(
                (current['schedules'] as List)
                    .take((row['schedules'] as List).length)
                    .toList(),
                row['schedules'],
              );
              current['remarks'] = row['remarks'];
              current['period'] = row['period'];
              current['schedules'] = row['schedules'];
              current.remove('regularPlannedSemesterScope');
            }
            expect(
              current,
              row,
              reason:
                  'Historical native whole object must remain recoverable after the verified planned-term extension',
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
