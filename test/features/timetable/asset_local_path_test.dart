import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled JSON assets contain no home-directory absolute paths', () {
    // Bundled assets ship in every installer; provenance must be a public URL
    // or a repository-relative path, never a developer machine path.
    // The lookbehind skips URL paths such as https://host/home/.
    final homePath = RegExp(
      r'(?<![A-Za-z0-9.])/(Users|home)/|[A-Za-z]:\\+Users\\',
    );
    final offenders = [
      for (final file
          in Directory('assets')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.json')))
        if (homePath.hasMatch(file.readAsStringSync()))
          file.path.replaceAll('\\', '/'),
    ];
    expect(offenders, isEmpty);
  });
}
