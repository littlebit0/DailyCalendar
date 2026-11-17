import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_update_service.dart';

/// Remembers on this device that a newer release exists. The flag is never part
/// of the Drive settings document, so another device's version cannot set it.
///
/// Once a newer version is known, no further network request is made: the
/// stored version keeps the restriction until the running build catches up.
class UpdateRequirementController {
  UpdateRequirementController({
    required SharedPreferences preferences,
    required Future<String?> Function() latestVersion,
    Future<String> Function()? currentVersion,
    DateTime Function()? now,
    this.interval = const Duration(hours: 6),
    this.enabled = true,
    this.onDetected,
    this.source = UpdateSource.github,
    bool Function(String candidate, String current)? isNewer,
  }) : _preferences = preferences,
       _latestVersion = latestVersion,
       _currentVersion =
           currentVersion ??
           (() async => (await PackageInfo.fromPlatform()).version),
       _now = now ?? DateTime.now,
       _isNewer = isNewer ?? isNewerVersion;

  static const requiredVersionKey = 'update.requiredVersion';
  static const lastCheckedKey = 'update.lastCheckedAtMs';
  static const requiredSourceKey = 'update.requiredSource';

  final SharedPreferences _preferences;
  final Future<String?> Function() _latestVersion;
  final Future<String> Function() _currentVersion;
  final DateTime Function() _now;
  final bool Function(String candidate, String current) _isNewer;

  /// Which feed [requiredVersion] came from; values from another feed (such
  /// as a GitHub tag stored by an older build) are dropped and re-checked.
  final UpdateSource source;
  final Duration interval;
  final bool enabled;

  /// Runs once when a newer release is first found (e.g. to stage an installer).
  final Future<void> Function()? onDetected;

  /// The newer version that must be installed, or null when up to date.
  final ValueNotifier<String?> requiredVersion = ValueNotifier<String?>(null);

  Timer? _timer;
  bool _started = false;
  Future<void>? _checking;
  DateTime? _lastAttempt;

  Future<void> initialize() => _reconcile();

  /// Starts the periodic check for an app that stays open all day.
  void start() {
    if (!enabled || _started) return;
    _started = true;
    unawaited(check());
  }

  void dispose() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    requiredVersion.dispose();
  }

  /// Re-checks on resume; the stored interval keeps this from polling.
  Future<void> check() {
    if (!enabled) return Future.value();
    return _checking ??= _check().whenComplete(() {
      _checking = null;
      _scheduleNext();
    });
  }

  /// The next check is due one interval after the last answered one, which a
  /// restart or a resume may have moved. A lookup that failed waits a full
  /// interval here; resuming the app can still retry it sooner.
  void _scheduleNext() {
    if (!_started) return;
    _timer?.cancel();
    final checkedMs = _preferences.getInt(lastCheckedKey);
    var delay = interval;
    if (checkedMs != null) {
      final due = DateTime.fromMillisecondsSinceEpoch(
        checkedMs,
      ).add(interval).difference(_now());
      if (due > Duration.zero && due < interval) delay = due;
    }
    _timer = Timer(delay, () => unawaited(check()));
  }

  Future<void> _check() async {
    try {
      await _reconcile();
      if (requiredVersion.value != null) return;
      final now = _now();
      final checkedMs = _preferences.getInt(lastCheckedKey);
      if (checkedMs != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(checkedMs)) <
              interval) {
        return;
      }
      // A failed lookup is retried on the next timer tick or resume, not in a loop.
      final attempt = _lastAttempt;
      if (attempt != null &&
          now.difference(attempt) < const Duration(minutes: 5)) {
        return;
      }
      _lastAttempt = now;
      final latest = await _latestVersion();
      if (latest == null) return;
      await _preferences.setInt(lastCheckedKey, now.millisecondsSinceEpoch);
      if (!_isNewer(latest, await _currentVersion())) return;
      await _preferences.setString(requiredSourceKey, source.name);
      await _preferences.setString(requiredVersionKey, latest);
      requiredVersion.value = latest;
      await onDetected?.call();
    } on Object {
      // An unreachable release feed must never restrict or break the app.
    }
  }

  /// Drops the stored requirement as soon as the running build is new enough.
  Future<void> _reconcile() async {
    final stored = _preferences.getString(requiredVersionKey);
    if (!enabled || stored == null) {
      requiredVersion.value = null;
      return;
    }
    final storedSource =
        _preferences.getString(requiredSourceKey) ?? UpdateSource.github.name;
    if (storedSource != source.name) {
      // Check this platform's store now instead of waiting out the interval.
      await _preferences.remove(lastCheckedKey);
    } else if (_isNewer(stored, await _currentVersion())) {
      requiredVersion.value = stored;
      return;
    }
    await _preferences.remove(requiredVersionKey);
    await _preferences.remove(requiredSourceKey);
    requiredVersion.value = null;
  }
}
