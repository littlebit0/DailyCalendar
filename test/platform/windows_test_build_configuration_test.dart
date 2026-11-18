import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('native test identity covers Debug and Profile only', () {
    final identity = source('windows/runner/app_identity.h');
    final resources = source('windows/runner/Runner.rc');
    final cmake = source('windows/runner/CMakeLists.txt');
    final main = source('windows/runner/main.cpp');
    final window = source('windows/runner/flutter_window.cpp');

    expect(identity, contains('#ifdef DAILY_TEST_EDITION'));
    expect(identity, contains('L"DailyCalendar Test"'));
    expect(identity, contains('L"DailyCalendar"'));
    expect(
      resources,
      contains('#define DAILY_PRODUCT_NAME "DailyCalendar Test"'),
    );
    expect(resources, contains('#define DAILY_PRODUCT_NAME "DailyCalendar"'));
    expect(cmake, contains(r'$<$<CONFIG:Debug>:DAILY_TEST_EDITION>'));
    expect(cmake, contains(r'$<$<CONFIG:Profile>:DAILY_TEST_EDITION>'));
    expect(main, contains('daily::app_identity::kDisplayName'));
    expect(window, contains('daily::app_identity::kOpenTrayLabel'));
  });

  test('test widget storage uses the isolated native identity directory', () {
    final bridge = source('windows/runner/windows_widget_bridge.cpp');

    expect(bridge, contains('daily::app_identity::kWidgetDataDirectoryName'));
  });

  test('Windows test runner defaults to safe Profile side-by-side install', () {
    final script = source('tool/run_windows_test.ps1');

    expect(script, contains("[ValidateSet('Debug', 'Profile')]"));
    expect(script, contains("[string] \$BuildMode = 'Profile'"));
    expect(script, contains(r'build\windows\x64\runner\$buildModeName'));
    expect(
      script,
      contains(r"@('build', 'windows', $buildModeFlag, '--no-pub')"),
    );
    expect(script, contains(r'-FlutterArgs $buildArgs'));
    expect(
      script,
      contains("@('ProductName', 'FileDescription', 'InternalName')"),
    );
    expect(script, contains(r'Get-ChildItem -LiteralPath $sourceBundle'));
    expect(script, contains(r'data\app.so'));
    expect(script, contains(r'data\flutter_assets\kernel_blob.bin'));
    expect(script, contains(r'$sourceVersion.IsDebug -ne $false'));
    expect(script, contains("Join-Path \$programsRoot 'DailyCalendar Test'"));
    expect(script, contains("'DailyCalendar Test.exe'"));
    // installer.iss: DefaultDirName={autopf}\DailyCalendar (#936).
    expect(script, contains(r"Join-Path $env:ProgramFiles 'DailyCalendar')"));
    expect(script, isNot(contains(r"'C:\Program Files\Daily'")));
    expect(
      File('tool/windows/installer.iss').readAsStringSync(),
      contains(r'DefaultDirName={autopf}\DailyCalendar'),
    );
    expect(script, contains('DailyCalendar Test.lnk'));
    expect(script, contains('Refusing to target the production installation'));
    expect(script, contains(r'$productionHashBefore'));
    expect(script, contains(r'$productionHashAfter'));
    expect(script, contains("'.DailyCalendar Test.staging'"));
    expect(script, contains("'.DailyCalendar Test.backup'"));
    expect(script, contains('Rollback install root'));
    // A failed backup move must leave the previous test app in place (#936).
    final backupMove = script.indexOf(
      r'Move-Item -LiteralPath $installRoot -Destination $backupRoot',
    );
    final moved = script.indexOf(r'$previousMoved = $true');
    final installed = script.indexOf(r'$newInstalled = $true');
    expect(backupMove, greaterThan(0));
    expect(moved, greaterThan(backupMove));
    expect(installed, greaterThan(moved));
    expect(
      script,
      contains(
        r'if ($newInstalled -and (Test-Path -LiteralPath $installRoot))',
      ),
    );
    expect(script, contains(r'if ($previousMoved -and'));
  });
}
