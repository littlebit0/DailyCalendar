import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../platform/app_build_identity.dart';

/// Fatal: crash, unhandled exception, data that may be lost. Sent on first
/// occurrence. Non-fatal: sent only once it repeats
/// [ErrorReportService.nonFatalThreshold] times, so a single timeout or other
/// transient failure never becomes a report.
enum ErrorReportSeverity { fatal, nonFatal }

class ErrorReportEnvironment {
  const ErrorReportEnvironment({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    required this.deviceType,
    required this.locale,
    required this.timeZone,
    required this.environment,
  });

  final String version;
  final String buildNumber;
  final String platform;
  final String osVersion;
  final String deviceType;
  final String locale;
  final String timeZone;

  /// `debug`, `profile`, `test` (test app package) or `production`.
  final String environment;

  Map<String, String> toJson() => {
    'version': version,
    'buildNumber': buildNumber,
    'platform': platform,
    'osVersion': osVersion,
    'deviceType': deviceType,
    'locale': locale,
    'timeZone': timeZone,
    'environment': environment,
  };
}

/// Integration state only: whether a feature is connected and when Drive last
/// synced. Never account names, schools or event content.
class ErrorReportIntegrations {
  const ErrorReportIntegrations({
    required this.driveLinked,
    required this.lmsConnected,
    this.lastDriveSyncAt,
  });

  final bool driveLinked;
  final bool lmsConnected;
  final DateTime? lastDriveSyncAt;

  Map<String, Object?> toJson() => {
    'driveLinked': driveLinked,
    'lmsConnected': lmsConnected,
    'lastDriveSyncAt': lastDriveSyncAt?.toUtc().toIso8601String(),
  };
}

final _sanitizers = <(RegExp, String Function(Match))>[
  (
    RegExp(r'\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    (m) => '${m[1]} ***',
  ),
  (
    RegExp(
      r'\b(Cookie|Set-Cookie|Authorization)\s*:[^\n]*',
      caseSensitive: false,
    ),
    (m) => '${m[1]}: ***',
  ),
  (
    RegExp(
      r'\b(access_token|refresh_token|id_token|token|password|passwd|pwd|pw|'
      r'cookie|session(?:_?id)?|jsessionid|api[_-]?key|secret|code|user_?id|'
      r"""student_?id|email)(["']?\s*[=:]\s*)["']?[^\s&;,"'}]+""",
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}***',
  ),
  (RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*'), (_) => '***'),
  (RegExp(r'\bya29\.[A-Za-z0-9._-]+'), (_) => '***'),
  (RegExp(r'[^\s@<>()"]+@[^\s@<>()"]+\.[A-Za-z]{2,}'), (_) => '***@***'),
  (
    RegExp(r'(https?://[^\s?#]+)\?[^\s#)]*', caseSensitive: false),
    (m) => '${m[1]}?***',
  ),
  (
    RegExp(
      r'(/Users/|/home/|[A-Za-z]:\\Users\\)[^/\\\s]+',
      caseSensitive: false,
    ),
    (m) => '${m[1]}***',
  ),
  (
    RegExp(
      r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
      caseSensitive: false,
    ),
    (_) => '<uuid>',
  ),
  (RegExp(r'\b[0-9a-f]{16,}\b', caseSensitive: false), (_) => '<hex>'),
  (RegExp(r'\+?\d[\d -]{8,}\d'), (_) => '<number>'),
  (RegExp(r'\d{6,}'), (_) => '<number>'),
  // Quoted values in messages are usually user data (event titles, names,
  // server text), which must not leave the device.
  // An unterminated quote (such as a cut-off JSON value) is masked to the end
  // of its line.
  (RegExp(r'"[^"\n]*(?:"|$)', multiLine: true), (_) => '"***"'),
  (RegExp(r"'[^'\n]*(?:'|$)", multiLine: true), (_) => "'***'"),
];

/// Masks tokens, cookies, credentials, emails, home-folder names, IDs, phone
/// numbers, URL queries and quoted user text. The receiver applies the same
/// rules again before anything is published.
String sanitizeErrorText(String value, {int maxLength = 4000}) {
  var result = value;
  for (final (pattern, replace) in _sanitizers) {
    result = result.replaceAllMapped(pattern, replace);
  }
  result = result.replaceAll(RegExp(r'[\u0000-\u0008\u000b-\u001f]'), '');
  return result.length > maxLength ? result.substring(0, maxLength) : result;
}

const _maxStackFrames = 15;

/// Top frames of [stackTrace], without async gap markers, sanitized.
String sanitizeStackTrace(StackTrace? stackTrace) {
  if (stackTrace == null) return '';
  final frames = stackTrace
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && line != '<asynchronous suspension>')
      .take(_maxStackFrames)
      .join('\n');
  return sanitizeErrorText(frames, maxLength: 6000);
}

/// Stable across occurrences: line/column numbers, paths, IDs and timestamps
/// are dropped so the same bug in a later build keeps the same fingerprint.
String errorFingerprint({
  required String errorType,
  required String sanitizedStackTrace,
  required String sanitizedMessage,
  required String feature,
  required String platform,
}) {
  String normalizeFrame(String line) => line
      .replaceAll(RegExp(r'^#\d+\s+'), '')
      .replaceAll(RegExp(r':\d+(:\d+)?'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final frames = sanitizedStackTrace
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(5)
      .map(normalizeFrame)
      .join('|');
  final identity = [
    errorType,
    // Without frames the message is the only thing telling errors apart.
    frames.isEmpty
        ? sanitizedMessage.replaceAll(RegExp(r'\d+'), '#').trim()
        : frames,
    feature,
    platform,
  ].join('\n');
  return sha256.convert(utf8.encode(identity)).toString().substring(0, 16);
}

class _PendingErrorReport {
  _PendingErrorReport({
    required this.id,
    required this.fingerprint,
    required this.severity,
    required this.feature,
    required this.errorType,
    required this.message,
    required this.stackTrace,
    required this.firstOccurredAt,
    required this.lastOccurredAt,
    required this.occurrenceCount,
    required this.lifecycle,
    required this.environment,
  });

  final String id;
  final String fingerprint;
  ErrorReportSeverity severity;
  final String feature;
  final String errorType;
  final String message;
  final String stackTrace;
  final DateTime firstOccurredAt;
  DateTime lastOccurredAt;
  int occurrenceCount;
  final String lifecycle;

  /// Where the error happened, kept so an app update before sending does not
  /// attribute the error to the new build.
  final Map<String, String> environment;

  static _PendingErrorReport? fromJson(Object? value) {
    if (value is! Map) return null;
    try {
      return _PendingErrorReport(
        id: value['id'] as String,
        fingerprint: value['fingerprint'] as String,
        severity: ErrorReportSeverity.values.byName(
          value['severity'] as String,
        ),
        feature: value['feature'] as String,
        errorType: value['errorType'] as String,
        message: value['message'] as String,
        stackTrace: value['stackTrace'] as String,
        firstOccurredAt: DateTime.parse(value['firstOccurredAt'] as String),
        lastOccurredAt: DateTime.parse(value['lastOccurredAt'] as String),
        occurrenceCount: value['occurrenceCount'] as int,
        lifecycle: value['lifecycle'] as String,
        environment: Map<String, String>.from(value['environment'] as Map),
      );
    } on Object {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'fingerprint': fingerprint,
    'severity': severity.name,
    'feature': feature,
    'errorType': errorType,
    'message': message,
    'stackTrace': stackTrace,
    'firstOccurredAt': firstOccurredAt.toUtc().toIso8601String(),
    'lastOccurredAt': lastOccurredAt.toUtc().toIso8601String(),
    'occurrenceCount': occurrenceCount,
    'lifecycle': lifecycle,
    'environment': environment,
  };
}

/// Collects sanitized error reports, keeps them in a small offline queue and
/// sends them to the Daily receiver, which stores them privately, grouped by
/// fingerprint, like the analytics aggregates. Nothing is published.
///
/// Every public method swallows its own failures: reporting must never become
/// a new cause of app errors.
class ErrorReportService {
  ErrorReportService({
    required SharedPreferences preferences,
    http.Client? httpClient,
    Uri? endpoint,
    DateTime Function()? now,
    Future<ErrorReportEnvironment> Function()? environmentLoader,
    String? buildMode,
  }) : _preferences = preferences,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _endpoint = endpoint ?? _configuredEndpoint,
       _now = now ?? DateTime.now,
       _buildMode = buildMode ?? _currentBuildMode,
       _environmentLoader = environmentLoader ?? _loadEnvironment,
       _enabled = ValueNotifier<bool>(preferences.getBool(_enabledKey) ?? true);

  static final Uri _configuredEndpoint = Uri.parse(
    const String.fromEnvironment(
      'DAILY_ERROR_REPORT_ENDPOINT',
      defaultValue: 'https://littlebit.tail6514a4.ts.net/v1/error-reports',
    ),
  );

  static String get _currentBuildMode => kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  static const _enabledKey = 'errorReportsEnabled';
  static const _queueKey = 'errorReportQueue.v1';
  static const _sentKey = 'errorReportSent.v1';
  static const maxQueuedReports = 20;
  static const queueRetention = Duration(days: 7);
  static const nonFatalThreshold = 3;
  static const fingerprintInterval = Duration(hours: 6);
  static const maxReportsPerDay = 10;

  final SharedPreferences _preferences;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri _endpoint;
  final DateTime Function() _now;
  final String _buildMode;
  final Future<ErrorReportEnvironment> Function() _environmentLoader;
  final ValueNotifier<bool> _enabled;

  /// Google authorization headers of the signed-in Daily account, or null when
  /// nobody is signed in; reports then wait in the queue.
  Future<Map<String, String>?> Function()? authorizationHeaders;
  ErrorReportIntegrations Function()? integrations;

  Future<void> _tail = Future<void>.value();
  bool _recording = false;
  Future<void>? _flushOperation;
  bool _flushAgain = false;

  bool get enabled => _enabled.value;
  ValueListenable<bool> get enabledListenable => _enabled;

  /// Debug builds never report, so deliberate errors during development do
  /// not become production reports.
  bool get _active => enabled && _buildMode != 'debug';

  Future<void> setEnabled(bool value) async {
    _enabled.value = value;
    try {
      await _preferences.setBool(_enabledKey, value);
      if (!value) {
        await _preferences.remove(_queueKey);
        // Again after any record/flush already queued, which recheck the
        // switch before saving but may have saved just before it changed.
        await _enqueue(() => _preferences.remove(_queueKey));
      }
    } on Object {
      // The in-memory switch still stops reporting for this run.
    }
  }

  /// Hooks Flutter framework errors (non-fatal) and uncaught errors
  /// (fatal), keeping any handler that was installed before.
  void installGlobalHandlers() {
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutter?.call(details);
      record(
        details.exception,
        details.stack,
        feature: details.library ?? 'flutter',
        severity: ErrorReportSeverity.nonFatal,
      );
    };
    final dispatcher = PlatformDispatcher.instance;
    final previousPlatform = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      record(error, stack, feature: 'app', severity: ErrorReportSeverity.fatal);
      return previousPlatform?.call(error, stack) ?? false;
    };
  }

  /// Records [error] and tries to send pending reports. Never throws.
  void record(
    Object error,
    StackTrace? stackTrace, {
    required String feature,
    required ErrorReportSeverity severity,
  }) {
    if (!_active || _recording) return;
    _recording = true;
    try {
      final occurredAt = _now().toUtc();
      final errorType = error.runtimeType.toString();
      // A parser error's toString() quotes the source it failed on, which can
      // be calendar data; keep only its message and position.
      final message = sanitizeErrorText(
        error is FormatException
            ? 'FormatException: ${error.message}'
                  '${error.offset == null ? '' : ' (at offset ${error.offset})'}'
            : error.toString(),
        maxLength: 1000,
      );
      final stack = sanitizeStackTrace(stackTrace);
      final safeFeature = sanitizeErrorText(feature, maxLength: 64);
      final lifecycle =
          WidgetsBinding.instance.lifecycleState?.name ?? 'unknown';
      _enqueue(() async {
        final environment = await _environmentLoader();
        final fingerprint = errorFingerprint(
          errorType: errorType,
          sanitizedStackTrace: stack,
          sanitizedMessage: message,
          feature: safeFeature,
          platform: environment.platform,
        );
        final queue = _loadQueue();
        final environmentJson = environment.toJson();
        // Occurrences in another build or OS stay separate reports.
        final existing = queue.where(
          (r) =>
              r.fingerprint == fingerprint &&
              mapEquals(r.environment, environmentJson),
        );
        if (existing.isNotEmpty) {
          final report = existing.first
            ..occurrenceCount += 1
            ..lastOccurredAt = occurredAt;
          if (severity == ErrorReportSeverity.fatal) {
            report.severity = ErrorReportSeverity.fatal;
          }
        } else {
          queue.add(
            _PendingErrorReport(
              id: const Uuid().v4(),
              fingerprint: fingerprint,
              severity: severity,
              feature: safeFeature,
              errorType: errorType,
              message: message,
              stackTrace: stack,
              firstOccurredAt: occurredAt,
              lastOccurredAt: occurredAt,
              occurrenceCount: 1,
              lifecycle: lifecycle,
              environment: environmentJson,
            ),
          );
        }
        if (!_active) return;
        await _saveQueue(queue);
      });
      // Sending runs outside the queue chain, so a slow upload never delays
      // saving the next error.
      unawaited(flush());
    } on Object {
      // Reporting must not raise a second error.
    } finally {
      _recording = false;
    }
  }

  /// Sends due reports. Call on start and resume; reports recorded offline or
  /// before sign-in go out here. A call during a running pass makes it run
  /// once more and completes with it.
  Future<void> flush() {
    final running = _flushOperation;
    if (running != null) {
      _flushAgain = true;
      return running;
    }
    return _flushOperation = () async {
      try {
        do {
          _flushAgain = false;
          await _tail;
          await _flushPass();
        } while (_flushAgain && _active);
      } on Object {
        // Kept in the queue for the next attempt.
      } finally {
        _flushOperation = null;
      }
    }();
  }

  /// Serializes every read-modify-write of the stored queue and sent log.
  Future<void> _enqueue(Future<void> Function() action) {
    return _tail = _tail.then((_) => action()).catchError((Object _) {});
  }

  Future<void> _flushPass() async {
    if (!_active) return;
    for (final report in _loadQueue()) {
      if (report.severity == ErrorReportSeverity.nonFatal &&
          report.occurrenceCount < nonFatalThreshold) {
        continue;
      }
      final now = _now().toUtc();
      final sent = _loadSent();
      final lastSent = DateTime.tryParse(
        sent['fingerprints']?[report.fingerprint]?.toString() ?? '',
      );
      if (lastSent != null && now.difference(lastSent) < fingerprintInterval) {
        continue;
      }
      if (_recentDaily(sent, now).length >= maxReportsPerDay) return;

      final headers = await authorizationHeaders?.call();
      // Opting out while waiting stops every unsent report.
      if (!_active) return;
      final authorization =
          headers?['Authorization'] ?? headers?['authorization'];
      if (authorization == null || !authorization.startsWith('Bearer ')) {
        return;
      }
      final outcome = await _send(report, authorization);
      if (!_active || outcome == _SendOutcome.retryLater) return;
      await _enqueue(() async {
        if (!_active) return;
        final queue = _loadQueue();
        // Occurrences merged in while the request was out keep the report
        // (same delivery ID); the receiver counts only the difference.
        queue.removeWhere(
          (r) =>
              r.id == report.id &&
              (outcome == _SendOutcome.rejected ||
                  r.occurrenceCount == report.occurrenceCount),
        );
        await _saveQueue(queue);
        if (outcome == _SendOutcome.sent) {
          final latest = _loadSent();
          final stamp = _now().toUtc();
          (latest['fingerprints'] ??= <String, Object?>{})[report.fingerprint] =
              stamp.toIso8601String();
          latest['daily'] = [
            ..._recentDaily(latest, stamp).map((t) => t.toIso8601String()),
            stamp.toIso8601String(),
          ];
          await _preferences.setString(_sentKey, jsonEncode(latest));
        }
      });
    }
  }

  static List<DateTime> _recentDaily(Map<String, dynamic> sent, DateTime now) =>
      (sent['daily'] as List? ?? const [])
          .map((value) => DateTime.tryParse(value.toString()))
          .whereType<DateTime>()
          .where((time) => now.difference(time) < const Duration(days: 1))
          .toList();

  Future<_SendOutcome> _send(
    _PendingErrorReport report,
    String authorization,
  ) async {
    final body = jsonEncode({
      'report': {
        'fingerprint': report.fingerprint,
        'severity': report.severity.name,
        'feature': report.feature,
        'errorType': report.errorType,
        'message': report.message,
        'stackTrace': report.stackTrace,
        'firstOccurredAt': report.firstOccurredAt.toIso8601String(),
        'lastOccurredAt': report.lastOccurredAt.toIso8601String(),
        'occurrenceCount': report.occurrenceCount,
        'lifecycle': report.lifecycle,
      },
      'environment': report.environment,
      'integrations':
          (integrations?.call() ??
                  const ErrorReportIntegrations(
                    driveLinked: false,
                    lmsConnected: false,
                  ))
              .toJson(),
    });
    try {
      final response = await _httpClient
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': authorization,
              'Idempotency-Key': report.id,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _SendOutcome.sent;
      }
      // A report the receiver rejects will be rejected again; drop it.
      if (response.statusCode == 400 || response.statusCode == 413) {
        return _SendOutcome.rejected;
      }
      return _SendOutcome.retryLater;
    } on Object {
      return _SendOutcome.retryLater;
    }
  }

  List<_PendingErrorReport> _loadQueue() {
    final cutoff = _now().toUtc().subtract(queueRetention);
    try {
      final decoded = jsonDecode(_preferences.getString(_queueKey) ?? '[]');
      if (decoded is! List) return [];
      return decoded
          .map(_PendingErrorReport.fromJson)
          .whereType<_PendingErrorReport>()
          .where((report) => report.lastOccurredAt.isAfter(cutoff))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _saveQueue(List<_PendingErrorReport> queue) async {
    queue.sort((a, b) => a.lastOccurredAt.compareTo(b.lastOccurredAt));
    final kept = queue.length > maxQueuedReports
        ? queue.sublist(queue.length - maxQueuedReports)
        : queue;
    await _preferences.setString(
      _queueKey,
      jsonEncode(kept.map((report) => report.toJson()).toList()),
    );
  }

  Map<String, dynamic> _loadSent() {
    try {
      final decoded = jsonDecode(_preferences.getString(_sentKey) ?? '{}');
      if (decoded is Map<String, dynamic>) return decoded;
    } on Object {
      // Fall through to an empty record.
    }
    return {};
  }

  void dispose() {
    _enabled.dispose();
    if (_ownsHttpClient) _httpClient.close();
  }

  static Future<ErrorReportEnvironment> _loadEnvironment() async {
    final info = await PackageInfo.fromPlatform();
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Linux',
    };
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final buildMode = _currentBuildMode;
    return ErrorReportEnvironment(
      version: info.version,
      buildNumber: info.buildNumber.isEmpty ? 'unknown' : info.buildNumber,
      platform: platform,
      osVersion: sanitizeErrorText(
        Platform.operatingSystemVersion,
        maxLength: 200,
      ),
      deviceType: platform == 'iOS' || platform == 'Android'
          ? 'mobile'
          : 'desktop',
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      timeZone: 'UTC$sign$hours:$minutes',
      environment: buildMode != 'release'
          ? buildMode
          : isTestAppPackage(info.packageName)
          ? 'test'
          : 'production',
    );
  }
}

enum _SendOutcome { sent, rejected, retryLater }
