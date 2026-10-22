import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retained timetable and organization assets equal the 4.0.0 release',
    () {
      final baseline =
          jsonDecode(
                File(
                  'test/fixtures/release_4_0_0_asset_hashes.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      // The index files were pruned to the retained universities by design.
      const pruned = {
        'assets/timetable/catalog.json',
        'assets/timetable/term-periods.json',
      };
      final actual = {
        for (final file
            in Directory('assets/timetable')
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.json')))
          file.path.replaceAll('\\', '/'): sha256
              .convert(file.readAsBytesSync())
              .toString(),
      };
      // Data changes approved after the release are listed with their reason;
      // every other retained file must still match the release exactly.
      final approved =
          jsonDecode(
                File(
                  'test/fixtures/timetable_asset_changes_after_4_0_0.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final expected = {
        ...baseline,
        for (final entry in approved.entries)
          entry.key: (entry.value as Map<String, dynamic>)['sha256'],
      };
      expect(actual.keys, everyElement(isIn(expected.keys)));
      for (final entry in actual.entries) {
        if (pruned.contains(entry.key)) continue;
        expect(entry.value, expected[entry.key], reason: entry.key);
      }
    },
  );
}
