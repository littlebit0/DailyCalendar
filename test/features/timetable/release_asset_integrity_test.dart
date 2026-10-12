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
      expect(actual, baseline);
    },
  );
}
