import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

export 'dart:io';

const _root = 'test/fixtures/source_audits';
final _manifestBytes = File('$_root/manifest.json').readAsBytesSync();
final _manifest =
    jsonDecode(utf8.decode(_manifestBytes)) as Map<String, dynamic>;
final _fingerprint = sha256.convert(_manifestBytes).toString();
final _cache = Directory(
  '${Directory.systemTemp.path}/daily-source-fixtures-$_fingerprint',
);
bool _prepared = false;

void _prepare() {
  if (_prepared) return;
  // A shared content-addressed cache avoids unpacking gigabytes per test isolate.
  // The OS lock prevents concurrent test processes from reading partial output.
  final lock = File('${_cache.path}.lock').openSync(mode: FileMode.append);
  try {
    lock.lockSync(FileLock.blockingExclusive);
    final ready = File('${_cache.path}/.ready');
    if (!ready.existsSync() || ready.readAsStringSync() != _fingerprint) {
      final result = Process.runSync(
        Platform.isWindows ? 'python' : 'python3',
        ['tool/prepare_test_fixtures.py', '--output', _cache.path],
      );
      if (result.exitCode != 0) {
        throw StateError('Source fixture preparation failed: ${result.stderr}');
      }
    }
    _prepared = true;
  } finally {
    lock.closeSync();
  }
}

// Logical work/ paths are provenance labels only. Never fall back to local work.
File fixtureFile(String path) {
  path = (_manifest['pathAliases'] as Map?)?[path] as String? ?? path;
  for (final recordedRoot in [
    '/Users/kimhwi/Documents/Codex/DailyCalendar/',
    '/Users/kimhwi/Documents/Codex/littlebit0-daily-https-github-com-littlebit0/',
  ]) {
    if (path.startsWith('${recordedRoot}work/')) {
      path = path.substring(recordedRoot.length);
      break;
    }
  }
  if (!path.startsWith('work/')) return File(path);
  _prepare();
  return File('${_cache.path}/$path');
}

Directory fixtureDirectory(String path) {
  if (!path.startsWith('work/')) return Directory(path);
  _prepare();
  return Directory('${_cache.path}/$path');
}

// Historical packets preceded publication; reproduce only that metadata step.
// No educational fields or current product data are modified.
void markHistoricalPublication(Map<String, dynamic> data) {
  data['researchOnly'] = false;
  for (final row in data['courses'] as List? ?? []) {
    final metadata = row['metadata'] as Map?;
    if (metadata != null && metadata.containsKey('researchOnly')) {
      metadata['researchOnly'] = false;
    }
  }
}

final _output = Directory.systemTemp.createTempSync(
  'daily-source-audit-output-',
);
// Generated diagnostics must never overwrite immutable source inputs or assume
// the host has macOS's /private/tmp directory.
File fixtureOutputFile(String logicalName) => File(
  '${_output.path}/${sha256.convert(utf8.encode(logicalName))}-${logicalName.split('/').last}',
);
