import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.releaseLookupTimeout = const Duration(seconds: 30),
    this.downloadIdleTimeout = const Duration(seconds: 60),
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

  final Duration releaseLookupTimeout;

  /// Longest wait for the installer response or for its next chunk. The whole
  /// download has no limit, because the file is large.
  final Duration downloadIdleTimeout;

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
      // An unanswered request must not hold every later check behind it.
      final response = await _client
          .get(
            _latestReleaseUri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Daily-Update-Check',
            },
          )
          .timeout(releaseLookupTimeout);
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

  /// The version App Store currently serves to users, or null when it cannot
  /// be read. Store review delays this past the GitHub release, so Apple
  /// devices are only restricted once the update can actually be installed.
  Future<String?> appStoreVersion({
    required bool mac,
    SharedPreferences? preferences,
  }) async {
    try {
      final uri = Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': appleBundleId,
        'country': 'kr',
        if (mac) 'entity': 'macSoftware',
      });
      final response = await _client
          .get(uri, headers: const {'User-Agent': 'Daily-Update-Check'})
          .timeout(releaseLookupTimeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final release = parseAppStoreLookup(response.body);
      if (release == null) return null;
      final url = release.url;
      if (preferences != null && url != null) {
        await preferences.setString(storeUrlKey, url);
      }
      return release.version;
    } on Object {
      return null;
    }
  }

  static const appleBundleId = 'com.littlebit0.daily';

  /// Last App Store page returned by the lookup, opened by the update button.
  static const storeUrlKey = 'update.storeUrl';

  Future<void> _checkAndPrepare() async {
    Directory? directory;
    try {
      // ZIP and Test editions must not silently turn into an installed release.
      if (!await _installationEligible()) return;
      final currentVersion = await _currentVersion();
      // A stalled request must end, so the next start can try again (#855).
      final response = await _client
          .get(
            _latestReleaseUri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Daily-Windows-Updater',
            },
          )
          .timeout(releaseLookupTimeout);
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
      if (!await downloadVerifiedInstaller(
        client: _client,
        uri: uri,
        destination: installer,
        expectedSha256: digest.substring(7).toLowerCase(),
        idleTimeout: downloadIdleTimeout,
      )) {
        return;
      }
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
      // Beside the download folder, which the helper deletes when it ends.
      resultPath: path.join(
        installer.parent.parent.path,
        'daily-update-result.txt',
      ),
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

/// Streams [uri] into [destination] while hashing it, so the installer is
/// never held in memory as a whole. Returns true only when the status, the
/// `MZ` header, the length and the SHA-256 all match and the file is flushed.
/// A false result or a thrown error may leave a partial file; the caller
/// deletes the download directory in that case. A response or a next chunk
/// that takes longer than [idleTimeout] throws a [TimeoutException].
@visibleForTesting
Future<bool> downloadVerifiedInstaller({
  required http.Client client,
  required Uri uri,
  required File destination,
  required String expectedSha256,
  Duration idleTimeout = const Duration(seconds: 60),
}) async {
  final response = await client
      .send(http.Request('GET', uri))
      .timeout(idleTimeout);
  if (response.statusCode != HttpStatus.ok) {
    await response.stream.drain<void>();
    return false;
  }
  Digest? digest;
  final hasher = sha256.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback(
      (digests) => digest = digests.single,
    ),
  );
  final header = <int>[];
  var received = 0;
  // Awaited writes pause the response stream (backpressure) and surface disk
  // errors here instead of as an unhandled IOSink.done error.
  final file = await destination.open(mode: FileMode.write);
  try {
    // Waiting on a disk write pauses the stream and its idle timer with it.
    await for (final chunk in response.stream.timeout(idleTimeout)) {
      if (header.length < 2) {
        header.addAll(chunk.take(2 - header.length));
        if (header.length == 2 && (header[0] != 0x4d || header[1] != 0x5a)) {
          return false;
        }
      }
      received += chunk.length;
      hasher.add(chunk);
      await file.writeFrom(chunk);
    }
    await file.flush();
  } finally {
    // Close before any delete; Windows cannot remove a file that is still open.
    await file.close();
  }
  hasher.close();
  final expectedLength = response.contentLength;
  return header.length == 2 &&
      (expectedLength == null || expectedLength == received) &&
      digest.toString() == expectedSha256;
}

@visibleForTesting
String windowsDeferredInstallScript({
  required int processId,
  required String installerPath,
  required String expectedSha256,
  required String readyPath,
  required String resultPath,
}) {
  String literal(String value) => "'${value.replaceAll("'", "''")}'";
  // The helper only runs on Windows, so parse the path as a Windows path.
  final downloadDirectory = path.windows.dirname(installerPath);
  // Delete only the folder made by createTemp('daily-update-'), never a
  // parent or working directory.
  final removable = path.windows
      .basename(downloadDirectory)
      .startsWith('daily-update-');
  // Never let the installer terminate another instance opened after the wait.
  // The outcome (installer exit code, declined UAC, digest mismatch) is
  // written to [resultPath], and the download folder is always removed (#935).
  return <String>[
    r"$ErrorActionPreference = 'Stop'",
    '\$app = Get-Process -Id $processId -ErrorAction Stop',
    r'$null = $app.Handle',
    '[System.IO.File]::WriteAllText(${literal(readyPath)}, "ready")',
    r'$app.WaitForExit()',
    r"$result = 'not started'",
    'try {',
    '  if ((Get-FileHash -LiteralPath ${literal(installerPath)} -Algorithm SHA256).Hash -ne ${literal(expectedSha256)}) {',
    r"    $result = 'digest mismatch'",
    '  } else {',
    '    \$setup = Start-Process -FilePath ${literal(installerPath)} -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCLOSEAPPLICATIONS" -Wait -PassThru',
    r'    $result = "exit code $($setup.ExitCode)"',
    '  }',
    '} catch {',
    r'  $result = "failed: $($_.Exception.Message)"',
    '} finally {',
    '  try { [System.IO.File]::WriteAllText(${literal(resultPath)}, "\$((Get-Date).ToString(\'o\')) \$result") } catch { }',
    if (removable)
      '  Remove-Item -LiteralPath ${literal(downloadDirectory)} -Recurse -Force -ErrorAction SilentlyContinue',
    '}',
    '',
  ].join('\n');
}

/// Where this platform learns that the installed build is outdated.
enum UpdateSource { appStore, play, github }

UpdateSource updateSourceFor(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => UpdateSource.appStore,
  TargetPlatform.android => UpdateSource.play,
  _ => UpdateSource.github,
};

/// The version and page of the first App Store lookup result, or null.
@visibleForTesting
({String version, String? url})? parseAppStoreLookup(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return null;
  final results = decoded['results'];
  if (results is! List || results.isEmpty) return null;
  final first = results.first;
  if (first is! Map<String, dynamic>) return null;
  final version = first['version'];
  if (version is! String || !RegExp(r'^\d+\.\d+(\.\d+)?$').hasMatch(version)) {
    return null;
  }
  final url = Uri.tryParse(first['trackViewUrl'] as String? ?? '');
  final valid =
      url != null && url.scheme == 'https' && url.host == 'apps.apple.com';
  return (version: version, url: valid ? url.toString() : null);
}

/// The Play versionCode to require, only when Play offers an update to this
/// installation. When Play offers none, the installed versionCode is returned
/// so a stored requirement (e.g. from a halted rollout) is lifted. Sideloaded
/// builds make the lookup throw, which means no answer: nothing changes.
Future<String?> playRequiredVersionCode({
  required Future<String> Function() installedVersionCode,
  Future<AppUpdateInfo> Function()? checkForUpdate,
}) async {
  try {
    final info = await (checkForUpdate ?? InAppUpdate.checkForUpdate)();
    return playRequirement(
      info.updateAvailability,
      info.availableVersionCode,
      await installedVersionCode(),
    );
  } on Object {
    return null;
  }
}

/// Null means Play gave no usable answer, which neither sets nor lifts a limit.
@visibleForTesting
String? playRequirement(
  UpdateAvailability availability,
  int? versionCode,
  String installed,
) => switch (availability) {
  UpdateAvailability.updateAvailable when versionCode != null => '$versionCode',
  UpdateAvailability.updateNotAvailable => installed,
  _ => null,
};

/// Android requirements are versionCodes; an unreadable one never restricts.
bool isNewerVersionCode(String candidate, String current) {
  final candidateCode = int.tryParse(candidate);
  final currentCode = int.tryParse(current);
  return candidateCode != null &&
      currentCode != null &&
      candidateCode > currentCode;
}

/// An unreadable version on either side never counts as newer, so a build
/// that cannot read its own version is not restricted (#890).
bool isNewerVersion(String candidate, String current) {
  final candidateParts = _versionParts(candidate);
  final currentParts = _versionParts(current);
  if (candidateParts == null || currentParts == null) return false;
  for (var index = 0; index < 3; index++) {
    if (candidateParts[index] != currentParts[index]) {
      return candidateParts[index] > currentParts[index];
    }
  }
  return false;
}

List<int>? _versionParts(String version) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(version);
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.tryParse(match.group(2) ?? '') ?? 0,
    int.tryParse(match.group(3) ?? '') ?? 0,
  ];
}
