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
  group('downloadVerifiedInstaller', () {
    final uri = Uri.parse(
      'https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.1/daily-windows-4.0.1-setup.exe',
    );
    final payload = [0x4d, 0x5a, ...List<int>.generate(70000, (i) => i % 251)];
    final expected = sha256.convert(payload).toString();
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('daily-stream-test-');
    });
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    http.Client chunked(
      List<List<int>> chunks, {
      int status = 200,
      int? contentLength,
      Object? errorAfter,
    }) {
      return MockClient.streaming((request, _) async {
        Stream<List<int>> body() async* {
          for (final chunk in chunks) {
            yield chunk;
          }
          if (errorAfter != null) throw errorAfter;
        }

        return http.StreamedResponse(
          body(),
          status,
          contentLength: contentLength,
        );
      });
    }

    List<List<int>> split(List<int> bytes, int size) => [
      for (var i = 0; i < bytes.length; i += size)
        bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size),
    ];

    Future<bool> run(http.Client client, File file, [String? hash]) =>
        downloadVerifiedInstaller(
          client: client,
          uri: uri,
          destination: file,
          expectedSha256: hash ?? expected,
        );

    test('writes chunked body with the same bytes and digest', () async {
      final file = File('${root.path}/setup.exe');
      // A 1-byte first chunk proves the MZ header is read across chunks.
      final chunks = [
        [payload[0]],
        ...split(payload.sublist(1), 4096),
      ];
      expect(
        await run(chunked(chunks, contentLength: payload.length), file),
        isTrue,
      );
      final written = await file.readAsBytes();
      expect(written, payload);
      expect(sha256.convert(written).toString(), expected);
    });

    test('rejects a digest mismatch', () async {
      final file = File('${root.path}/setup.exe');
      expect(
        await run(
          chunked(split(payload, 4096)),
          file,
          sha256.convert([1]).toString(),
        ),
        isFalse,
      );
    });

    test('rejects a non-MZ body without reading further', () async {
      final file = File('${root.path}/setup.exe');
      var pulled = 0;
      final client = MockClient.streaming((request, _) async {
        Stream<List<int>> body() async* {
          for (final chunk in [
            [0x4d],
            [0x00, 1, 2],
            [3, 4],
          ]) {
            pulled++;
            yield chunk;
          }
        }

        return http.StreamedResponse(body(), 200);
      });
      expect(await run(client, file), isFalse);
      expect(pulled, 2);
    });

    test('rejects a truncated body', () async {
      final file = File('${root.path}/setup.exe');
      final truncated = payload.sublist(0, payload.length - 10);
      expect(
        await run(
          chunked(split(truncated, 4096), contentLength: payload.length),
          file,
          sha256.convert(truncated).toString(),
        ),
        isFalse,
      );
    });

    test('rejects HTTP failure and empty bodies', () async {
      expect(
        await run(
          chunked(split(payload, 4096), status: 404),
          File('${root.path}/a.exe'),
        ),
        isFalse,
      );
      expect(
        await run(
          chunked(const [], contentLength: 0),
          File('${root.path}/b.exe'),
          sha256.convert(const []).toString(),
        ),
        isFalse,
      );
    });

    test('propagates interrupted downloads and disk failures', () async {
      await expectLater(
        run(
          chunked(split(payload, 4096), errorAfter: const SocketException('x')),
          File('${root.path}/c.exe'),
        ),
        throwsA(isA<SocketException>()),
      );
      await expectLater(
        run(
          chunked(split(payload, 4096)),
          File('${root.path}/missing/dir/d.exe'),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test(
      'service removes partial download and skips install on interruption',
      () async {
        final bytes = payload;
        var prepared = 0;
        final download = Directory('${root.path}/download');
        final service = AppUpdateService(
          enabled: true,
          currentVersion: () async => '4.0.0',
          installationEligible: () async => true,
          temporaryDirectory: () => download.create(),
          client: MockClient.streaming((request, _) async {
            if (request.url.host == 'api.github.com') {
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'tag_name': 'v4.0.1',
                      'assets': [
                        {
                          'name': 'daily-windows-4.0.1-setup.exe',
                          'browser_download_url': uri.toString(),
                          'digest': 'sha256:${sha256.convert(bytes)}',
                        },
                      ],
                    }),
                  ),
                ),
                200,
              );
            }
            Stream<List<int>> body() async* {
              yield bytes.sublist(0, 4096);
              throw const SocketException('reset');
            }

            return http.StreamedResponse(body(), 200);
          }),
          prepareAfterExit: (file, hash) async => prepared++,
        );
        await service.checkAndInstallIfAvailable();
        expect(prepared, 0);
        expect(service.installationPrepared, isFalse);
        expect(await download.exists(), isFalse);
      },
    );
  });

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
