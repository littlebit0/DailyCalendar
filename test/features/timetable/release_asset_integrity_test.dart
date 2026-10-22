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
      expect(actual.keys, everyElement(isIn(baseline.keys)));
      for (final entry in actual.entries) {
        if (pruned.contains(entry.key)) continue;
        expect(entry.value, baseline[entry.key], reason: entry.key);
      }
    },
  );
}
