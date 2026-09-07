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
    expect(workflow, contains('3ab44a04827cb218654f34c67779291b256d2950'));
    expect(
      setup,
      contains('3A:B4:4A:04:82:7C:B2:18:65:4F:34:C6:77:79:29:1B:25:6D:29:50'),
    );
    expect(workflow, contains('secrets.ANDROID_KEYSTORE_BASE64'));
    expect(
      workflow,
      contains(
        '--dart-define=DAILY_ANALYTICS_ENDPOINT=https://littlebit.tail6514a4.ts.net/v1/events',
      ),
    );
    expect(
      workflow,
      contains(
        '--dart-define=DAILY_BUG_REPORT_ENDPOINT=https://littlebit.tail6514a4.ts.net/v1/bug-reports',
      ),
    );
    expect(setup, contains('Android GitHub release APK OAuth client'));
    expect(
      setup,
      contains('Android current macOS development machine debug OAuth client'),
    );
  });
}
