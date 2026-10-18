import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
