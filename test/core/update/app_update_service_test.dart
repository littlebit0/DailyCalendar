import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:daily/core/update/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in ['none', 'digest', 'launch', 'portable']) {
    test('deferred update $failure never requests process exit', () async {
      final bytes = [0x4d, 0x5a, 1, 2, 3];
      final gate = Completer<void>();
      var requests = 0;
      var prepared = 0;
      final root = await Directory.systemTemp.createTemp('daily-update-test-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final service = AppUpdateService(
        enabled: true,
        currentVersion: () async => '4.0.0',
        installationEligible: () async => failure != 'portable',
        temporaryDirectory: () async =>
            Directory('${root.path}/download').create(),
        client: MockClient((request) async {
          requests++;
          if (request.url.host == 'api.github.com') {
            return http.Response(
              jsonEncode({
                'tag_name': 'v4.0.1',
                'assets': [
                  {
                    'name': 'daily-windows-4.0.1-setup.exe',
                    'browser_download_url':
                        'https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.1/daily-windows-4.0.1-setup.exe',
                    'digest':
                        'sha256:${sha256.convert(failure == 'digest' ? [1] : bytes)}',
                  },
                ],
              }),
              200,
            );
          }
          await gate.future;
          return http.Response.bytes(bytes, 200);
        }),
        prepareAfterExit: (file, hash) async {
          if (failure == 'launch') throw StateError('helper unavailable');
          expect(await file.readAsBytes(), bytes);
          prepared++;
        },
      );
      final first = service.checkAndInstallIfAvailable();
      final second = service.checkAndInstallIfAvailable();
      expect(identical(first, second), isTrue);
      // A delayed download can coexist with an uncommitted editor/save operation.
      expect(prepared, 0);
      gate.complete();
      await Future.wait([first, second]);
      expect(service.installationPrepared, failure == 'none');
      expect(prepared, failure == 'none' ? 1 : 0);
      if (failure == 'portable') expect(requests, 0);
      if (failure == 'none') {
        final before = requests;
        await service.checkAndInstallIfAvailable();
        expect(requests, before);
      }
    });
  }
  test(
    'helper holds process handle and waits before hash verification and install',
    () {
      final script = windowsDeferredInstallScript(
        processId: 123,
        installerPath: r"C:\temp\a'b\setup.exe",
        expectedSha256: 'abc',
        readyPath: r'C:\temp\ready',
      );
      expect(
        script.indexOf(r'$app.WaitForExit()'),
        lessThan(script.indexOf('Get-FileHash')),
      );
      expect(
        script.indexOf('Get-FileHash'),
        lessThan(script.indexOf('Start-Process')),
      );
      expect(script, contains("a''b"));
      expect(script, contains('/NOCLOSEAPPLICATIONS'));
      expect(script, isNot(contains('Stop-Process')));
    },
  );

  test('detects newer semantic versions', () {
    expect(isNewerVersion('3.0.2', '3.0.1'), isTrue);
    expect(isNewerVersion('3.1.0', '3.0.9'), isTrue);
    expect(isNewerVersion('4.0.0', '3.9.9'), isTrue);
  });

  test('does not update for equal, older, or invalid versions', () {
    expect(isNewerVersion('3.0.1', '3.0.1'), isFalse);
    expect(isNewerVersion('3.0.0', '3.0.1'), isFalse);
    expect(isNewerVersion('invalid', '3.0.1'), isFalse);
  });

  test('runs the Windows auto updater only in release mode', () {
    expect(
      shouldRunWindowsAutoUpdater(
        targetPlatform: TargetPlatform.windows,
        isReleaseMode: true,
      ),
      isTrue,
    );
    expect(
      shouldRunWindowsAutoUpdater(
        targetPlatform: TargetPlatform.windows,
        isReleaseMode: false,
      ),
      isFalse,
    );
    expect(
      shouldRunWindowsAutoUpdater(
        targetPlatform: TargetPlatform.macOS,
        isReleaseMode: true,
      ),
      isFalse,
    );
  });
}
