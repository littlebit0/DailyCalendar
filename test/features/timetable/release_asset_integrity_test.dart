import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CI repairs preserve every release timetable and organization asset',
    () {
      final baseline =
          jsonDecode(
                File(
                  'test/fixtures/release_4_0_0_asset_hashes.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
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
      // every other file must still match the release exactly.
      final approved =
          jsonDecode(
                File(
                  'test/fixtures/timetable_asset_changes_after_4_0_0.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(actual, {
        ...baseline,
        for (final entry in approved.entries)
          entry.key: (entry.value as Map<String, dynamic>)['sha256'],
      });
    },
  );
}
