import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'source_fixture.dart';

void main() {
  const source = 'work/university-research/checkpoint72-source-manifest.json';
  test('archived source bytes match the committed provenance manifest', () {
    final manifest =
        jsonDecode(
              File(
                'test/fixtures/source_audits/manifest.json',
              ).readAsStringSync(),
            )
            as Map;
    final file = fixtureFile(source);
    expect(file.path, isNot(source));
    expect(
      sha256.convert(file.readAsBytesSync()).toString(),
      manifest['files'][source],
    );
  });
  test(
    'unknown research input stays missing instead of reading local work',
    () {
      expect(
        fixtureFile('work/ci-unregistered-input.json').existsSync(),
        isFalse,
      );
    },
  );
  test(
    'unknown absolute research input never falls back to the original machine',
    () {
      const recorded =
          '/Users/kimhwi/Documents/Codex/littlebit0-daily-https-github-com-littlebit0/work/ci-unregistered-input.json';
      final file = fixtureFile(recorded);
      expect(file.path, isNot(recorded));
      expect(file.existsSync(), isFalse);
    },
  );
  test('ordinary product files still resolve directly', () {
    expect(
      fixtureFile('assets/timetable/catalog.json').path,
      'assets/timetable/catalog.json',
    );
  });
}
