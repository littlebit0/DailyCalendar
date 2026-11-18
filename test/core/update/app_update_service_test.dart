import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:daily/core/update/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  group('stalled update requests end (#855)', () {
    const assetUrl =
        'https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.1/daily-windows-4.0.1-setup.exe';
    final release = jsonEncode({
      'tag_name': 'v4.0.1',
      'assets': [
        {
          'name': 'daily-windows-4.0.1-setup.exe',
          'browser_download_url': assetUrl,
          'digest': 'sha256:${sha256.convert([0x4d, 0x5a])}',
        },
      ],
    });

    test('an unanswered release lookup lets a later check ask again', () async {
      var lookups = 0;
      final service = AppUpdateService(
        enabled: true,
        currentVersion: () async => '4.0.0',
        installationEligible: () async => true,
        releaseLookupTimeout: const Duration(milliseconds: 20),
        client: MockClient((request) {
          lookups++;
          return Completer<http.Response>().future;
        }),
      );
      await service.checkAndInstallIfAvailable();
      await service.checkAndInstallIfAvailable();
      expect(lookups, 2);
      expect(service.installationPrepared, isFalse);
    });

    for (final stall in ['before the response', 'between chunks']) {
      test('a download stalled $stall ends and leaves no files', () async {
        final root = await Directory.systemTemp.createTemp('daily-stall-test-');
        final body = StreamController<List<int>>();
        addTearDown(() async {
          // close() only completes once listened; the first case never listens.
          unawaited(body.close());
          if (await root.exists()) await root.delete(recursive: true);
        });
        final download = Directory('${root.path}/download');
        var prepared = 0;
        final service = AppUpdateService(
          enabled: true,
          currentVersion: () async => '4.0.0',
          installationEligible: () async => true,
          temporaryDirectory: () => download.create(),
          downloadIdleTimeout: const Duration(milliseconds: 20),
          prepareAfterExit: (file, hash) async => prepared++,
          client: MockClient.streaming((request, _) {
            if (request.url.host == 'api.github.com') {
              return Future.value(
                http.StreamedResponse(Stream.value(utf8.encode(release)), 200),
              );
            }
            if (stall == 'before the response') {
              return Completer<http.StreamedResponse>().future;
            }
            body.add([0x4d, 0x5a]);
            return Future.value(http.StreamedResponse(body.stream, 200));
          }),
        );
        await service.checkAndInstallIfAvailable();
        expect(service.installationPrepared, isFalse);
        expect(prepared, 0);
        expect(await download.exists(), isFalse);
      });
    }
  });

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
  group('store update sources', () {
    test('chooses the store feed per platform', () {
      expect(updateSourceFor(TargetPlatform.iOS), UpdateSource.appStore);
      expect(updateSourceFor(TargetPlatform.macOS), UpdateSource.appStore);
      expect(updateSourceFor(TargetPlatform.android), UpdateSource.play);
      expect(updateSourceFor(TargetPlatform.windows), UpdateSource.github);
      expect(updateSourceFor(TargetPlatform.linux), UpdateSource.github);
    });

    test('parses the App Store lookup and rejects odd answers', () {
      final body = jsonEncode({
        'resultCount': 1,
        'results': [
          {
            'version': '4.1.1',
            'trackViewUrl':
                'https://apps.apple.com/kr/app/dailycalendar/id6784087335?uo=4',
          },
        ],
      });
      final release = parseAppStoreLookup(body);
      expect(release?.version, '4.1.1');
      expect(release?.url, contains('apps.apple.com'));
      expect(parseAppStoreLookup('{"resultCount":0,"results":[]}'), isNull);
      expect(parseAppStoreLookup('{"results":[{"version":"beta"}]}'), isNull);
      expect(
        parseAppStoreLookup(
          '{"results":[{"version":"4.2.0","trackViewUrl":"https://evil.test"}]}',
        )?.url,
        isNull,
      );
    });

    test('reads the App Store version and remembers its page', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Uri? requested;
      final service = AppUpdateService(
        enabled: false,
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            '{"results":[{"version":"4.2.0","trackViewUrl":"https://apps.apple.com/kr/app/id1"}]}',
            200,
          );
        }),
      );
      expect(
        await service.appStoreVersion(mac: true, preferences: prefs),
        '4.2.0',
      );
      expect(requested?.queryParameters['bundleId'], 'com.littlebit0.daily');
      expect(requested?.queryParameters['entity'], 'macSoftware');
      expect(
        prefs.getString(AppUpdateService.storeUrlKey),
        'https://apps.apple.com/kr/app/id1',
      );
      await service.appStoreVersion(mac: false);
      expect(requested?.queryParameters.containsKey('entity'), isFalse);
    });

    test('an unreachable App Store never yields a version', () async {
      final failing = AppUpdateService(
        enabled: false,
        client: MockClient((_) async => http.Response('', 503)),
      );
      expect(await failing.appStoreVersion(mac: false), isNull);
      final throwing = AppUpdateService(
        enabled: false,
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      expect(await throwing.appStoreVersion(mac: false), isNull);
    });

    test('Play restricts only when it offers an update', () async {
      expect(playRequirement(UpdateAvailability.updateAvailable, 430), '430');
      expect(
        playRequirement(UpdateAvailability.updateNotAvailable, 430),
        isNull,
      );
      expect(playRequirement(UpdateAvailability.unknown, null), isNull);
      expect(playRequirement(UpdateAvailability.updateAvailable, null), isNull);
      // A sideloaded build cannot reach Play; the lookup failure is no limit.
      expect(
        await playRequiredVersionCode(
          checkForUpdate: () async => throw Exception('ERROR_APP_NOT_OWNED'),
        ),
        isNull,
      );
    });

    test('compares Android versionCodes numerically', () {
      expect(isNewerVersionCode('430', '420'), isTrue);
      expect(isNewerVersionCode('420', '420'), isFalse);
      expect(isNewerVersionCode('1000', '999'), isTrue);
      expect(isNewerVersionCode('4.2.1', '420'), isFalse);
    });
  });
}
