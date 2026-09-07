import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Android supports tablets and resizable windows', () {
    final manifest = source('android/app/src/main/AndroidManifest.xml');

    expect(manifest, isNot(contains('android:largeScreens="false"')));
    expect(manifest, isNot(contains('android:xlargeScreens="false"')));
    expect(manifest, contains('android:resizeableActivity="true"'));
  });

  test('Android release verifies the OAuth signing certificate', () {
    final workflow = source('.github/workflows/release-installers.yml');
    final setup = source('docs/GOOGLE_DRIVE_SYNC_SETUP.md');

    expect(workflow, contains('Verify Android OAuth signing certificate'));
    expect(workflow, contains('0497a88673a55343d31347bbc3b2ec266573bc0e'));
    expect(setup, contains('Android GitHub release APK OAuth client'));
    expect(
      setup,
      contains('Android current macOS development machine debug OAuth client'),
    );
  });
}
