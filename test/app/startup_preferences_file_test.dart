// Exercise the exact desktop implementations resolved by shared_preferences.
// ignore_for_file: depend_on_referenced_packages
import 'package:daily/app/startup_gate.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _LinuxPath extends PathProviderLinux {
  @override
  Future<String?> getApplicationSupportPath() async => '/support';
}

class _WindowsPath extends PathProviderWindows {
  @override
  Future<String?> getApplicationSupportPath() async => '/support';
}

void main() {
  for (final windows in [false, true]) {
    for (final contents in <String?>[null, '', '{"flutter.lock":true}']) {
      testWidgets(
        '${windows ? "Windows" : "Linux"} normal preferences startup: $contents',
        (tester) async {
          final fs = MemoryFileSystem();
          final file = fs.file('/support/shared_preferences.json');
          if (contents != null) {
            file.createSync(recursive: true);
            file.writeAsStringSync(contents);
          }
          final previous = SharedPreferencesStorePlatform.instance;
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = windows
              ? (SharedPreferencesWindows()
                  ..fs = fs
                  ..pathProvider = _WindowsPath())
              : (SharedPreferencesLinux()
                  ..fs = fs
                  ..pathProvider = _LinuxPath());
          addTearDown(() {
            SharedPreferences.resetStatic();
            SharedPreferencesStorePlatform.instance = previous;
          });
          await tester.pumpWidget(
            StartupGate(
              initialize: () async {
                final preferences = await SharedPreferences.getInstance();
                return MaterialApp(
                  home: Text('lock: ${preferences.getBool("lock")}'),
                );
              },
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              'lock: ${contents != null && contents.isNotEmpty ? true : null}',
            ),
            findsOneWidget,
          );
          expect(file.existsSync(), contents != null);
          if (contents != null) expect(file.readAsStringSync(), contents);
        },
      );
    }

    testWidgets(
      '${windows ? "Windows" : "Linux"} malformed preferences survive failure and retry reads repaired lock',
      (tester) async {
        final fs = MemoryFileSystem();
        final file = fs.file('/support/shared_preferences.json')
          ..createSync(recursive: true)
          ..writeAsStringSync('{"flutter.lock":');
        final original = file.readAsBytesSync();
        final previous = SharedPreferencesStorePlatform.instance;
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = windows
            ? (SharedPreferencesWindows()
                ..fs = fs
                ..pathProvider = _WindowsPath())
            : (SharedPreferencesLinux()
                ..fs = fs
                ..pathProvider = _LinuxPath());
        addTearDown(() {
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = previous;
        });
        var ready = 0;
        await tester.pumpWidget(
          StartupGate(
            initialize: () async {
              final preferences = await SharedPreferences.getInstance();
              ready++;
              return MaterialApp(
                home: Text('lock: ${preferences.getBool("lock")}'),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(ready, 0);
        expect(file.readAsBytesSync(), original);
        expect(find.byType(FilledButton), findsOneWidget);
        // Simulate repair from known-good settings, never an automatic default reset.
        file.writeAsStringSync('{"flutter.lock":true}');
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(ready, 1);
        expect(find.text('lock: true'), findsOneWidget);
        expect(file.readAsStringSync(), '{"flutter.lock":true}');
      },
    );
  }
}
