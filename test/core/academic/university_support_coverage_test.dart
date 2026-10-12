import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Published expansion status agrees with institution and campus capabilities',
    () {
      final status =
          jsonDecode(
                File(
                  'docs/UNIVERSITY_SUPPORT_STATUS_2026-10-06.json',
                ).readAsStringSync(),
              )
              as Map;
      final targets =
          (jsonDecode(
                    File(
                      'docs/UNIVERSITY_EXPANSION_TARGETS.json',
                    ).readAsStringSync(),
                  )
                  as Map)['targets']
              as List;
      final rows = status['universities'] as List;
      expect(rows.length, status['requestedUniversities']);
      final schools =
          (jsonDecode(
                    File(
                      'assets/academic/universities.json',
                    ).readAsStringSync(),
                  )
                  as Map)['universities']
              as List;
      expect(status['completionClaim'], isFalse);
      expect(status['lmsExpansion'], isFalse);
      for (final row in rows) {
        if (row['academicCalendar']['status'] != 'implemented_live_verified') {
          continue;
        }
        final matched = targets.where((t) => t['name'] == row['name']);
        final target = matched.isNotEmpty
            ? matched.single as Map
            : {
                'institutionIds': row['institutionIds'],
                'campusIds': [
                  for (final school in schools)
                    if ((row['institutionIds'] as List).contains(
                      school['institutionId'],
                    ))
                      school['id'],
                ],
              };
        for (final campus in target['campusIds'] as List) {
          final profile = AcademicProfile(
            universityId: (target['institutionIds'] as List).first as String,
            universityName: row['name'] as String,
            schoolKind: 'fourYear',
            campusId: campus as String,
          );
          expect(
            profile.academicSourceId,
            (row['academicCalendar']['sourceByCampus'] as Map?)?[campus] ??
                row['academicCalendar']['sourceId'],
            reason: '${row['name']} / $campus',
          );
          final timetable = row['timetable'] as Map;
          if (timetable['status'] == 'temporarily_unsupported') {
            expect(profile.timetableSupported, isFalse);
            expect(profile.timetableUniversity, timetable['universityId']);
          } else if ((timetable['status'] as String).startsWith(
            'implemented_',
          )) {
            final catalogId =
                timetable['universityId'] ??
                timetable['sourceId'] ??
                row['academicCalendar']['sourceId'];
            expect(
              profile.timetableUniversity,
              catalogId,
              reason: '${row['name']} / $campus must use its own catalog',
            );
          } else {
            expect(
              profile.timetableUniversity,
              isNull,
              reason:
                  'Calendar-only school must not receive another school catalog',
            );
          }
        }
      }
    },
  );
}
