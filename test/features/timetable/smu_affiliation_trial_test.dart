import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

void main() {
  test(
    'all Sangmyung departments have a source-backed college or official parent',
    () {
      final document =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/organizations/smu.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      CourseOrganizationDirectory.fromJson(document);
      final professorPrograms = (document['mappings'] as List)
          .cast<Map<String, dynamic>>()
          .where((unit) => unit['group'] == '마이크로전공')
          .toList();
      expect(professorPrograms.length, 40);
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
                fixtureFile(
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
                fixtureFile(
                  'assets/timetable/organizations/smu.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final units = (document['mappings'] as List).cast<Map<String, dynamic>>();
      for (final (group, count) in [('마이크로전공', 40), ('연계전공', 9), ('융합전공', 8)]) {
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

  test('release organization baseline remains unchanged during CI repair', () {
    final before =
        jsonDecode(
              fixtureFile(
                'test/fixtures/release_4_0_0_asset_hashes.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final approved =
        jsonDecode(
              fixtureFile(
                'test/fixtures/timetable_asset_changes_after_4_0_0.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final entry in before.entries.where(
      (e) =>
          e.key.startsWith('assets/timetable/organizations/') &&
          !e.key.endsWith('/smu.json') &&
          // Organizations of universities without timetable data were removed.
          fixtureFile(e.key).existsSync(),
    )) {
      expect(
        sha256.convert(fixtureFile(entry.key).readAsBytesSync()).toString(),
        (approved[entry.key] as Map<String, dynamic>?)?['sha256'] ??
            entry.value,
        reason: entry.key,
      );
    }
  });
}
