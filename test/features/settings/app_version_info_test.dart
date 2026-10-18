import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('version and build number stay separate', () {
    final info = appVersionInfoFromPackage('4.0.0', '400', 'com.example.daily');
    expect(info.version, '4.0.0');
    expect(info.buildNumber, '400');
    expect(info.packageName, 'com.example.daily');
  });

  test('a missing build number is unknown, not the version', () {
    final info = appVersionInfoFromPackage('4.0.0', '', 'pkg');
    expect(info.version, '4.0.0');
    expect(info.buildNumber, 'unknown');
  });

  test('a failing package lookup never invents a build number', () async {
    final info = await resolveAppVersionInfo(
      () => throw StateError('package metadata unavailable'),
    );
    expect(info.version, isNotEmpty);
    expect(info.buildNumber, 'unknown');
    expect(info.buildNumber, isNot(info.version));
    expect(info.packageName, isEmpty);
  });

  test('a successful lookup keeps the real values', () async {
    final info = await resolveAppVersionInfo(
      () async => PackageInfo(
        appName: 'Daily',
        packageName: 'com.littlebit0.daily',
        version: '4.1.2',
        buildNumber: '42',
      ),
    );
    expect(info.version, '4.1.2');
    expect(info.buildNumber, '42');
    expect(info.packageName, 'com.littlebit0.daily');
  });
}
