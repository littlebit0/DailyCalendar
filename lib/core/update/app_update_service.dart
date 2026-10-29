import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

@visibleForTesting
bool shouldRunWindowsAutoUpdater({
  required TargetPlatform targetPlatform,
  required bool isReleaseMode,
}) {
  return targetPlatform == TargetPlatform.windows && isReleaseMode;
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Future<String> Function()? currentVersion,
    Future<bool> Function()? installationEligible,
    Future<void> Function(File, String)? prepareAfterExit,
    Future<Directory> Function()? temporaryDirectory,
    bool? enabled,
  }) : _client = client ?? http.Client(),
       _currentVersion =
           currentVersion ??
           (() async => (await PackageInfo.fromPlatform()).version),
       _installationEligible = installationEligible ?? _isInstalledRelease,
       _prepareAfterExit =
           prepareAfterExit ?? _prepareWindowsInstallerAfterExit,
       _temporaryDirectory =
           temporaryDirectory ??
           (() => Directory.systemTemp.createTemp('daily-update-')),
       _enabled =
           enabled ??
           shouldRunWindowsAutoUpdater(
             targetPlatform: defaultTargetPlatform,
             isReleaseMode: kReleaseMode,
           );

  static final _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/littlebit0/DailyCalendar/releases/latest',
  );

  final http.Client _client;
  final Future<String> Function() _currentVersion;
  final Future<bool> Function() _installationEligible;
  final Future<void> Function(File, String) _prepareAfterExit;
  final Future<Directory> Function() _temporaryDirectory;
  final bool _enabled;
  Future<void>? _operation;
  bool _prepared = false;

  bool get installationPrepared => _prepared;

  Future<void> checkAndInstallIfAvailable() {
    if (!_enabled || _prepared) return Future<void>.value();
    return _operation ??= _checkAndPrepare().whenComplete(
      () => _operation = null,
    );
  }

  /// The newest published version, or null when it cannot be read. This only
  /// reads the release feed; it never downloads or installs anything.
  Future<String?> latestReleaseVersion() async {
    try {
      final response = await _client.get(
        _latestReleaseUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Daily-Update-Check',
        },
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final version = (release['tag_name'] as String? ?? '').replaceFirst(
        RegExp(r'^v'),
        '',
      );
      return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ? version : null;
    } on Object {
      return null;
    }
  }

  Future<void> _checkAndPrepare() async {
    Directory? directory;
    try {
      // ZIP and Test editions must not silently turn into an installed release.
      if (!await _installationEligible()) return;
      final currentVersion = await _currentVersion();
      final response = await _client.get(
        _latestReleaseUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Daily-Windows-Updater',
        },
      );
      if (response.statusCode != HttpStatus.ok) {
        return;
      }
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final version = (release['tag_name'] as String? ?? '').replaceFirst(
        RegExp(r'^v'),
        '',
      );
      if (!isNewerVersion(version, currentVersion)) {
        return;
      }
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) return;
      final assetName = 'daily-windows-$version-setup.exe';
      final assets = (release['assets'] as List<dynamic>? ?? const []);
      final asset = assets.cast<Map<String, dynamic>>().where(
        (item) => item['name'] == assetName,
      );
      if (asset.isEmpty) {
        return;
      }
      final downloadUrl = asset.first['browser_download_url'] as String?;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return;
      }
      final uri = Uri.tryParse(downloadUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'github.com' ||
          !uri.path.startsWith(
            '/littlebit0/DailyCalendar/releases/download/',
          )) {
        return;
      }
      final digest = asset.first['digest'];
      if (digest is! String ||
          !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)) {
        return;
      }
      directory = await _temporaryDirectory();
      final installer = File(path.join(directory.path, assetName));
      final download = await _client.get(uri);
      if (download.statusCode != HttpStatus.ok ||
          download.bodyBytes.length < 2 ||
          download.bodyBytes[0] != 0x4d ||
          download.bodyBytes[1] != 0x5a ||
          sha256.convert(download.bodyBytes).toString() !=
              digest.substring(7).toLowerCase()) {
        return;
      }
      await installer.writeAsBytes(download.bodyBytes, flush: true);
      await _prepareAfterExit(installer, digest.substring(7).toLowerCase());
      _prepared = true;
    } on Object {
      // A preparation failure leaves the running application untouched.
    } finally {
      if (!_prepared && directory != null) {
        try {
          await directory.delete(recursive: true);
        } on Object {
          /* retry next check */
        }
      }
    }
  }

  static Future<bool> _isInstalledRelease() async {
    if (!Platform.isWindows) return false;
    final executable = File(Platform.resolvedExecutable);
    if (path.basename(executable.path).toLowerCase() != 'dailycalendar.exe' ||
        !await File(
          path.join(executable.parent.path, 'unins000.exe'),
        ).exists()) {
      return false;
    }
    // Inno's registered directory distinguishes installation from copied ZIPs.
    final result = await Process.run('reg.exe', [
      'query',
      r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A27D9263-2AE6-4E06-B2C5-CFA9ADFE8B2F}_is1',
      '/v',
      'InstallLocation',
      '/reg:64',
    ]);
    if (result.exitCode != 0) return false;
    final match = RegExp(
      r'InstallLocation\s+REG_SZ\s+(.+)',
    ).firstMatch(result.stdout.toString());
    if (match == null) return false;
    return path.windows.normalize(match.group(1)!.trim()).toLowerCase() ==
        path.windows.normalize(executable.parent.path).toLowerCase();
  }

  static Future<void> _prepareWindowsInstallerAfterExit(
    File installer,
    String digest,
  ) async {
    final ready = File(path.join(installer.parent.path, 'ready'));
    final script = windowsDeferredInstallScript(
      processId: pid,
      installerPath: installer.path,
      expectedSha256: digest,
      readyPath: ready.path,
    );
    final bytes = script.codeUnits
        .expand((unit) => [unit & 255, unit >> 8])
        .toList();
    final helper = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      base64Encode(bytes),
    ], mode: ProcessStartMode.detached);
    // This handshake only means the helper is waiting; never report installed.
    for (var attempt = 0; attempt < 50; attempt++) {
      if (await ready.exists()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    helper.kill();
    throw StateError('Update preparation failed');
  }
}

@visibleForTesting
String windowsDeferredInstallScript({
  required int processId,
  required String installerPath,
  required String expectedSha256,
  required String readyPath,
}) {
  String literal(String value) => "'${value.replaceAll("'", "''")}'";
  // Never let the installer terminate another instance opened after the wait.
  return <String>[
    r"$ErrorActionPreference = 'Stop'",
    '\$app = Get-Process -Id $processId -ErrorAction Stop',
    r'$null = $app.Handle',
    '[System.IO.File]::WriteAllText(${literal(readyPath)}, "ready")',
    r'$app.WaitForExit()',
    'if ((Get-FileHash -LiteralPath ${literal(installerPath)} -Algorithm SHA256).Hash -ne ${literal(expectedSha256)}) { exit 1 }',
    'Start-Process -FilePath ${literal(installerPath)} -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCLOSEAPPLICATIONS" -Wait',
    '',
  ].join('\n');
}

bool isNewerVersion(String candidate, String current) {
  final candidateParts = _versionParts(candidate);
  final currentParts = _versionParts(current);
  for (var index = 0; index < 3; index++) {
    if (candidateParts[index] != currentParts[index]) {
      return candidateParts[index] > currentParts[index];
    }
  }
  return false;
}

List<int> _versionParts(String version) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(version);
  if (match == null) {
    return const [0, 0, 0];
  }
  return [
    int.parse(match.group(1)!),
    int.tryParse(match.group(2) ?? '') ?? 0,
    int.tryParse(match.group(3) ?? '') ?? 0,
  ];
}
