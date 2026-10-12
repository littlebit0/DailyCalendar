import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

void main() {
  test(
    'all Sangmyung departments have a source-backed college or official parent',
    () {
      final document =
          jsonDecode(
                File(
                  'assets/timetable/organizations/smu.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      CourseOrganizationDirectory.fromJson(document);
      final professorPrograms = (document['mappings'] as List)
          .cast<Map<String, dynamic>>()
          .where((unit) => unit['group'] == '마이크로전공')
          .toList();
      expect(professorPrograms.length, 39);
      expect(
        professorPrograms.every((unit) => unit['college'] == null),
        isTrue,
      );
      expect(
        professorPrograms.every(
          (unit) => unit['affiliationStatus'] == 'officialProgramSystem',
        ),
        isTrue,
      );

      for (final unit
          in (document['mappings'] as List).cast<Map<String, dynamic>>()) {
        if (unit['department'] == null) continue;
        expect(
          unit['college'] ?? unit['group'],
          isNotNull,
          reason: unit['department'] as String,
        );
        if (unit['affiliationStatus'] != null) {
          expect(unit['affiliationSourceUrl'], isNotEmpty);
          expect(unit['affiliationEvidence'], isNotEmpty);
          expect(unit['affiliationStatus'], isNot('unresolvedNameGroup'));
        }
      }
    },
  );

  test(
    'Sangmyung official hosts correct linked and renamed department affiliations',
    () {
      final document =
          jsonDecode(
                File(
                  'assets/timetable/organizations/smu.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final units = (document['mappings'] as List).cast<Map<String, dynamic>>();
      for (final (name, campus, college) in [
        ('디지털만화영상전공', 'cheonan', '예술대학'),
      ]) {
        final unit = units.singleWhere(
          (u) => u['department'] == name && u['campus'] == campus,
        );
        expect(unit['college'], college, reason: name);
        expect(
          unit['isOfferingUnit'],
          isFalse,
        ); // Program affiliation cannot invent college-direct offerings.
      }
    },
  );

  test(
    'official program systems override host-college grouping for all Sangmyung programs',
    () {
      final document =
          jsonDecode(
                File(
                  'assets/timetable/organizations/smu.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final units = (document['mappings'] as List).cast<Map<String, dynamic>>();
      for (final (group, count) in [('마이크로전공', 39), ('연계전공', 9), ('융합전공', 7)]) {
        final programs = units.where((u) => u['group'] == group).toList();
        expect(programs.length, count);
        expect(
          programs.every(
            (u) => u['college'] == null && u['collegeKnown'] == false,
          ),
          isTrue,
        );
      }
      final production = units.singleWhere(
        (u) => u['department'] == '콘텐츠제작연계전공',
      );
      expect(production['group'], '연계전공');
      for (final name in ['SW융합학부지능IOT융합전공', '지능·데이터융합학부 빅데이터융합전공']) {
        final regular = units.singleWhere((u) => u['department'] == name);
        expect(regular['college'], '융합공과대학');
        expect(
          regular['group'],
          isNull,
        ); // Official undergraduate departments, not additional-major system entries.
      }
    },
  );

  test('Sangmyung trial does not alter other university organization data', () {
    final before =
        jsonDecode(
              File(
                'work/smu-affiliation-trial-20261012/other-organization-hashes-before.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final entry in before.entries) {
      expect(
        sha256.convert(File(entry.key).readAsBytesSync()).toString(),
        entry.value,
        reason: entry.key,
      );
    }
  });
}
