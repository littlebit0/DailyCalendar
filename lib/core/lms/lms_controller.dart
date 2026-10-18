import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/events/application/event_command_service.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_repository.dart';
import '../analytics/product_analytics.dart';
import '../settings/settings_repository.dart';
import 'lms_login_analytics.dart';
import 'lms_models.dart';
import 'lms_sync_service.dart';
import 'lms_web_session.dart';
import 'lms_credentials_store.dart';

/// Coordinates one school browser with the current Daily account. Merely reading
/// this controller never starts a browser or a network request.
class LmsController extends ChangeNotifier {
  LmsController({
    required SettingsRepository settings,
    required EventRepository repository,
    required EventCommandService commands,
    LmsWebSession Function(String owner, String school)? createSession,
    FutureOr<void> Function()? onIntegrationChanged,
    LmsCredentialsStore? credentialsStore,
    ProductAnalytics analytics = const NoopProductAnalytics(),
  }) : _credentials = credentialsStore ?? LmsCredentialsStore(),
       _loginReporter = LmsLoginReporter(analytics),
       _settings = settings,
       _onIntegrationChanged = onIntegrationChanged,
       _createSession =
           createSession ??
           ((owner, school) =>
               LmsWebSession(ownerId: owner, schoolId: school)) {
    sync = LmsSyncService(
      settings: settings,
      repository: repository,
      commands: commands,
      fetchHtml: (uri) async {
        final active = _session;
        if (active == null) {
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        }
        return active.fetchHtml(uri);
      },
      readSession: _readIdentity,
      isAuthenticationError: (error) =>
          error is LmsWebSessionException &&
          error.code == LmsWebSessionError.authenticationRequired,
    );
    sync.addListener(_notify);
  }

  final LmsCredentialsStore _credentials;
  final _automaticAttempts = <String>{};
  bool automaticLoginPaused = false;
  LmsLoginFailure? lastLoginFailure;
  String? _credentialKey;
  String? _localLoginUsername;
  bool _localLoginLoading = false;
  bool _localLoginReadFailed = false;
  int _credentialRevision = 0;

  String? get localLoginUsername =>
      _credentialKey == _desiredKey ? _localLoginUsername : null;
  bool get localLoginLoading =>
      _credentialKey == _desiredKey && _localLoginLoading;
  bool get localLoginReadFailed =>
      _credentialKey == _desiredKey && _localLoginReadFailed;

  /// Read device-local identity without exposing passwords or starting login.
  Future<void> loadLocalLoginInfo() async {
    final key = _desiredKey;
    final revision = ++_credentialRevision;
    if (_credentialKey != key) _localLoginUsername = null;
    _credentialKey = key;
    _localLoginReadFailed = false;
    _localLoginLoading = key != null;
    _notify();
    if (key == null) return;
    final owner = _settings.dailyAccount()!.googleAccount!.email;
    final school = schoolId!;
    bool valid() =>
        !_disposed && revision == _credentialRevision && key == _desiredKey;
    try {
      final stored = await _credentials.read(owner, school);
      if (!valid()) return;
      _localLoginUsername = stored?.username;
      automaticLoginPaused = stored?.paused ?? false;
    } catch (_) {
      if (!valid()) return;
      _localLoginReadFailed = true;
    } finally {
      if (valid()) {
        _localLoginLoading = false;
        _notify();
      }
    }
  }

  final SettingsRepository _settings;
  final FutureOr<void> Function()? _onIntegrationChanged;
  final LmsWebSession Function(String, String) _createSession;
  late final LmsSyncService sync;
  LmsWebSession? _session;
  String? _key;
  String? _restoredPrincipal;
  int _generation = 0;
  bool _disposed = false;
  bool _restoring = false;
  bool _stored = false;
  bool _disconnecting = false;
  bool _queuedForce = false;
  bool _forceCurrentRefresh = false;
  bool _networkRefreshStarted = false;
  Future<void>? _operation;
  Future<void>? _disconnectOperation;
  Timer? _timer;
  bool _foreground = false;
  bool _preparingLogin = false;
  bool _configuringAutomaticLogin = false;
  bool? _configuredIntegrationEnabled;
  String? _configuredLmsUserId;

  String? get schoolId => _settings.load().academicProfile?.timetableUniversity;
  // Only the adapter verified against actual authenticated responses is enabled.
  static bool supportsSchool(String? schoolId) => schoolId == 'smu';
  bool get supported => supportsSchool(schoolId);
  bool get restoring => _restoring || _disconnecting;
  bool get connected =>
      !_disconnecting &&
      _settings.load().academicProfile?.lmsIntegrationEnabled != false &&
      _key == _desiredKey &&
      _matchesSelectedPrincipal(_session?.principalId ?? _restoredPrincipal) &&
      (_stored || _session?.isAuthenticated == true);
  bool get needsLogin => sync.state == LmsSyncState.needsLogin;
  LmsWebSession? get session => _session;

  String? get _desiredKey {
    final owner = _settings.dailyAccount()?.googleAccount?.email;
    if (owner == null || !supported) return null;
    return '${normalizeLmsOwner(owner)}|$schoolId';
  }

  LmsSyncSession? _readIdentity() {
    final current = _session;
    final principal = current?.principalId ?? _restoredPrincipal;
    if (_disconnecting ||
        current == null ||
        principal == null ||
        !_matchesSelectedPrincipal(principal) ||
        _desiredKey != _key) {
      return null;
    }
    return LmsSyncSession(
      schoolId: current.schoolId,
      ownerId: current.ownerId,
      lmsUserId: principal,
      baseUrl: current.baseUrl,
      generation: _generation,
    );
  }

  bool isEventVisible(CalendarEvent event) => sync.isEventVisible(event);

  /// Called synchronously as soon as account/profile settings change, so stale
  /// in-flight results and cached rows stop being eligible before any await.
  void settingsChanged() {
    final profile = _settings.load().academicProfile;
    final enabled = profile?.lmsIntegrationEnabled;
    final selected = profile?.lmsUserId;
    if (_key == _desiredKey &&
        _configuredIntegrationEnabled == enabled &&
        _configuredLmsUserId == selected) {
      return;
    }
    _configuredIntegrationEnabled = enabled;
    _configuredLmsUserId = selected;
    _generation++;
    if (_credentialKey != _desiredKey) {
      _credentialRevision++;
      _credentialKey = null;
      _localLoginUsername = null;
      _localLoginLoading = false;
      _localLoginReadFailed = false;
      unawaited(loadLocalLoginInfo());
    }
    automaticLoginPaused = false;
    lastLoginFailure = null;
    _restoredPrincipal = null;
    _stored = false;
    _restoring = false;
    sync.invalidateSession();
    _notify();
    if (_foreground) unawaited(refresh());
  }

  void setForeground(bool active) {
    _foreground = active;
    _timer?.cancel();
    _timer = null;
    if (active) {
      _timer = Timer.periodic(LmsSyncService.refreshInterval, (_) {
        unawaited(refresh());
      });
    }
  }

  Future<void> refresh({bool force = false}) {
    if (_disposed || _disconnecting) return Future.value();
    final running = _operation;
    if (running != null) {
      // A force request before collection starts belongs to the upcoming
      // snapshot. Once collection has started, retain the trailing refresh:
      // the user's newly submitted quiz may postdate an already-read page.
      if (force && !_networkRefreshStarted) {
        _forceCurrentRefresh = true;
      } else {
        _queuedForce = _queuedForce || force;
      }
      return running.then<void>((_) async {
        if (_disposed || _disconnecting) return;
        final forceAgain = _queuedForce;
        _queuedForce = false;
        if (forceAgain || _key != _desiredKey) {
          await refresh(force: forceAgain);
        }
      });
    }
    _forceCurrentRefresh = force;
    _networkRefreshStarted = false;
    final operation = _refresh(force: force).catchError((Object error) {
      if (_disposed) return;
      _restoring = false;
      sync.markRestoreFailed(
        authenticationRequired:
            error is LmsWebSessionException &&
            error.code == LmsWebSessionError.authenticationRequired,
      );
      _notify();
    });
    _operation = operation;
    return operation.whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
  }

  Future<void> saveAutomaticLogin(String username, String password) async {
    final owner = _settings.dailyAccount()?.googleAccount?.email;
    final school = schoolId;
    if (owner == null || !supported || school == null) return;
    lastLoginFailure = null;
    try {
      await _credentials.save(
        owner,
        school,
        LmsLocalCredentials(username, password),
      );
    } catch (_) {
      if (!_disposed && _desiredKey == '${normalizeLmsOwner(owner)}|$school') {
        lastLoginFailure = LmsLoginFailure.secureStorage;
        _notify();
      }
      rethrow;
    }
    if (_disposed || _desiredKey != '${normalizeLmsOwner(owner)}|$school') {
      return;
    }
    _credentialRevision++;
    _credentialKey = _desiredKey;
    _localLoginUsername = username.trim();
    _localLoginLoading = false;
    _localLoginReadFailed = false;
    _automaticAttempts.remove(_desiredKey);
    automaticLoginPaused = false;
    _notify();
    _configuringAutomaticLogin = true;
    try {
      await refresh(force: true);
    } finally {
      _configuringAutomaticLogin = false;
    }
  }

  Future<void> removeAutomaticLogin() async {
    final owner = _settings.dailyAccount()?.googleAccount?.email;
    final school = schoolId;
    if (owner == null || school == null) return;
    await _credentials.delete(owner, school);
    if (_disposed || _desiredKey != '${normalizeLmsOwner(owner)}|$school') {
      return;
    }
    _credentialRevision++;
    _credentialKey = _desiredKey;
    _localLoginUsername = null;
    _localLoginLoading = false;
    _localLoginReadFailed = false;
    automaticLoginPaused = false;
    lastLoginFailure = null;
    _notify();
  }

  Future<bool> _tryAutomaticLogin(
    LmsWebSession current,
    bool Function() valid,
  ) async {
    final key = _desiredKey;
    if (_preparingLogin || key == null || !valid()) return false;
    if (_automaticAttempts.contains(key)) {
      _reportAutomaticSkip(key, AnalyticsLmsSkipReason.attemptLimit);
      return false;
    }
    LmsLocalCredentials? credentials;
    try {
      credentials = await _credentials.read(current.ownerId, current.schoolId);
    } catch (_) {
      if (valid()) {
        lastLoginFailure = LmsLoginFailure.secureStorage;
        _reportAutomatic(
          AnalyticsLmsStage.credentials,
          AnalyticsLmsResult.failed,
          cause: LmsLoginFailure.secureStorage,
        );
      } else {
        _reportAutomatic(
          AnalyticsLmsStage.credentials,
          AnalyticsLmsResult.canceled,
        );
      }
      return false;
    } // Keychain failure must not destroy normal session/cache.
    if (!valid()) {
      _reportAutomatic(
        AnalyticsLmsStage.credentials,
        AnalyticsLmsResult.canceled,
      );
      return false;
    }
    if (credentials == null) {
      _reportAutomaticSkip(key, AnalyticsLmsSkipReason.noCredentials);
      return false;
    }
    automaticLoginPaused = credentials.paused;
    if (credentials.paused) {
      _reportAutomaticSkip(key, AnalyticsLmsSkipReason.paused);
      return false;
    }
    _automaticAttempts.add(
      key,
    ); // Never automatically repeat a login this process.
    _restoring = true;
    lastLoginFailure = null;
    _notify();
    final bool success;
    try {
      success = await current.loginAutomatically(
        credentials,
        expectedPrincipal: _settings.load().academicProfile?.lmsUserId,
      );
    } catch (error) {
      if (valid()) {
        lastLoginFailure =
            current.lastAutomaticLoginFailure ??
            LmsLoginFailure.fromError(error);
        _reportAutomatic(
          AnalyticsLmsStage.authentication,
          AnalyticsLmsResult.failed,
          cause: lastLoginFailure,
        );
      } else {
        _reportAutomatic(
          AnalyticsLmsStage.authentication,
          AnalyticsLmsResult.canceled,
        );
      }
      _reportedAutomaticError = error;
      rethrow;
    }
    if (!valid()) {
      // The account or session changed while the school was answering.
      _reportAutomatic(
        AnalyticsLmsStage.authentication,
        AnalyticsLmsResult.canceled,
      );
      return false;
    }
    if (!success) {
      lastLoginFailure =
          current.lastAutomaticLoginFailure ??
          LmsLoginFailure.authenticationUnconfirmed;
      _reportAutomatic(
        AnalyticsLmsStage.authentication,
        AnalyticsLmsResult.failed,
        cause: lastLoginFailure,
      );
      await _credentials.save(
        current.ownerId,
        current.schoolId,
        LmsLocalCredentials(
          credentials.username,
          credentials.password,
          paused: true,
        ),
      );
      if (!valid()) return false;
      automaticLoginPaused = true;
      sync.markRestoreFailed(authenticationRequired: true);
      return false;
    }
    lastLoginFailure = null;
    _stored = current.isAuthenticated;
    _restoredPrincipal = current.principalId;
    _reportAutomatic(AnalyticsLmsStage.session, AnalyticsLmsResult.succeeded);
    await _saveConnection(current, enabled: true);
    if (!valid()) return false;
    await _refreshAuthenticatedSession(current, valid, force: true);
    return true;
  }

  final LmsLoginReporter _loginReporter;
  final Set<String> _reportedAutomaticSkips = {};

  /// The error whose automatic attempt already has its terminal outcome, so the
  /// outer recovery does not re-enter and emit a second one.
  Object? _reportedAutomaticError;

  void _reportAutomatic(
    AnalyticsLmsStage stage,
    AnalyticsLmsResult result, {
    LmsLoginFailure? cause,
  }) => _loginReporter.report(
    method: AnalyticsLmsMethod.automatic,
    stage: stage,
    result: result,
    cause: cause,
  );

  /// A skipped automatic login is not a failure. It is reported once per
  /// account/school and reason so repeated refreshes do not repeat it.
  void _reportAutomaticSkip(String key, AnalyticsLmsSkipReason reason) {
    if (!_reportedAutomaticSkips.add('$key:${reason.name}')) return;
    _loginReporter.report(
      method: AnalyticsLmsMethod.automatic,
      stage: AnalyticsLmsStage.credentials,
      result: AnalyticsLmsResult.skipped,
      skipReason: reason,
    );
  }

  Future<void> _refresh({required bool force}) async {
    await loadLocalLoginInfo();
    if (_disposed || _disconnecting) return;
    await sync.applyConfiguredCategory();
    final desired = _desiredKey;
    if (_key != desired) {
      _generation++;
      final old = _session;
      _restoredPrincipal = null;
      _stored = false;
      sync.invalidateSession();
      final activationGeneration = _generation;
      // Keep the old handle until cleanup succeeds. A failed retirement must
      // remain retryable, and must not activate a new owner in an uncleared
      // browser environment. Its old key makes it invisible immediately.
      await old?.retire();
      if (_disposed ||
          _disconnecting ||
          activationGeneration != _generation ||
          _desiredKey != desired) {
        return;
      }
      _session = null;
      _key = desired;
      if (desired == null) return;
      _session = _createSession(
        normalizeLmsOwner(_settings.dailyAccount()!.googleAccount!.email),
        schoolId!,
      );
    }
    final current = _session;
    if (current == null || current.isLoginVisible) return;
    _configuredIntegrationEnabled = _settings
        .load()
        .academicProfile
        ?.lmsIntegrationEnabled;
    _configuredLmsUserId = _settings.load().academicProfile?.lmsUserId;
    if (_configuredIntegrationEnabled == false && !_configuringAutomaticLogin) {
      _stored = false;
      if (!_preparingLogin) await current.close();
      // prepareLogin only creates a handle. Reconnection becomes enabled after
      // the user's official login has actually verified a principal.
      return;
    }
    final generation = _generation;
    bool valid() =>
        !_disposed &&
        generation == _generation &&
        identical(current, _session) &&
        _key == _desiredKey;
    _restoring = !current.isAuthenticated;
    _notify();
    try {
      if (current.isAuthenticated &&
          !_matchesSelectedPrincipal(current.principalId)) {
        _stored = false;
        _restoredPrincipal = _configuredLmsUserId;
        await current.close();
        if (valid()) sync.markRestoreFailed(authenticationRequired: true);
        return;
      }
      if (!current.isAuthenticated) {
        final stored = await current.hasStoredSession();
        if (!valid()) return;
        _stored = stored;
        _restoredPrincipal = current.storedPrincipalId;
        if (!_matchesSelectedPrincipal(_restoredPrincipal)) {
          _stored = false;
          _restoredPrincipal = _configuredLmsUserId;
          sync.markRestoreFailed(authenticationRequired: true);
          if (!stored) await _tryAutomaticLogin(current, valid);
          return;
        }
        if (!stored) {
          sync.markRestoreFailed(authenticationRequired: true);
          await _tryAutomaticLogin(current, valid);
          return;
        }
        if (!valid()) return;
        await current.prepare();
      }
      if (!valid()) return;
      _stored = current.isAuthenticated;
      _restoredPrincipal = current.principalId ?? _restoredPrincipal;
      if (current.isAuthenticated) {
        lastLoginFailure = null;
        await _saveConnection(current, enabled: true);
      }
      if (!valid()) return;
      await _refreshAuthenticatedSession(
        current,
        valid,
        force: force || _forceCurrentRefresh,
      );
    } catch (error) {
      if (valid()) {
        final expired =
            error is LmsWebSessionException &&
            error.code == LmsWebSessionError.authenticationRequired;
        if (expired) _stored = false;
        sync.markRestoreFailed(authenticationRequired: expired);
        if (expired && !identical(error, _reportedAutomaticError)) {
          try {
            await _tryAutomaticLogin(current, valid);
          } catch (_) {
            if (valid()) sync.markRestoreFailed();
          }
        }
      }
    } finally {
      if (valid()) {
        _restoring = false;
        _notify();
      }
    }
  }

  // A successful credential submission needs the same bounded cookie recovery
  // as restored/manual sessions when the first school read redirects.
  Future<void> _refreshAuthenticatedSession(
    LmsWebSession current,
    bool Function() valid, {
    required bool force,
  }) async {
    if (!valid()) return;
    _restoring = false;
    _networkRefreshStarted = true;
    await sync.refresh(force: force);
    if (valid() && sync.state == LmsSyncState.ready) {
      current.acknowledgeSuccessfulRefresh();
    }
    if (!valid() || sync.state != LmsSyncState.needsLogin) return;
    // fetchHtml requests recovery only after a previously authenticated GET
    // was rejected. The session consumes that request once, using only its
    // own saved cookies and verified root identity, never SSO credentials.
    _restoring = true;
    _notify();
    final recovered = await current.recoverAuthentication();
    if (!valid()) return;
    _stored = current.isAuthenticated;
    _restoredPrincipal = current.principalId ?? _restoredPrincipal;
    _restoring = false;
    if (recovered) {
      await _saveConnection(current, enabled: true);
      if (valid()) await sync.refresh(force: true);
      if (valid() && sync.state == LmsSyncState.ready) {
        current.acknowledgeSuccessfulRefresh();
      }
      if (valid()) _stored = current.isAuthenticated;
    }
    if (valid() && sync.state == LmsSyncState.needsLogin) {
      await _tryAutomaticLogin(current, valid);
    }
  }

  /// Prepares the account-scoped object; the caller alone presents the visible
  /// official school login. Automatic credential submission is suppressed here.
  Future<LmsWebSession?> prepareLogin() async {
    _preparingLogin = true;
    lastLoginFailure = null;
    try {
      await refresh();
    } finally {
      _preparingLogin = false;
    }
    if (_disposed || _key != _desiredKey) return null;
    return _session;
  }

  Future<void> loginCompleted(LmsWebSession loginSession) async {
    if (_disposed ||
        !identical(loginSession, _session) ||
        _key != _desiredKey ||
        !loginSession.isAuthenticated) {
      return;
    }
    lastLoginFailure = null;
    _generation++;
    _restoredPrincipal = loginSession.principalId;
    _stored = true;
    await _saveConnection(
      loginSession,
      enabled: true,
      allowPrincipalChange: true,
    );
    if (_disposed ||
        !identical(loginSession, _session) ||
        _key != _desiredKey) {
      return;
    }
    sync.invalidateSession();
    await refresh(force: true);
  }

  Future<void> disconnect() {
    final running = _disconnectOperation;
    if (running != null) return running;
    final operation = _disconnect();
    _disconnectOperation = operation;
    return operation.whenComplete(() => _disconnectOperation = null);
  }

  Future<void> _disconnect() async {
    _disconnecting = true;
    lastLoginFailure = null;
    _restoring = false;
    _queuedForce = false;
    _generation++;
    _stored = false;
    _restoredPrincipal = null;
    final current = _session;
    _session = null;
    _key = null;
    sync.invalidateSession();
    try {
      try {
        if (current != null) await _saveConnection(current, enabled: false);
      } finally {
        try {
          if (current != null) {
            await _credentials.delete(current.ownerId, current.schoolId);
            if (_desiredKey == '${current.ownerId}|${current.schoolId}') {
              _credentialRevision++;
              _credentialKey = _desiredKey;
              _localLoginUsername = null;
              _localLoginLoading = false;
              _localLoginReadFailed = false;
            }
          }
        } finally {
          try {
            await current?.disconnect();
          } finally {
            await current?.retire();
          }
        }
      }
    } finally {
      _disconnecting = false;
      _notify();
    }
  }

  Future<void> _saveConnection(
    LmsWebSession current, {
    required bool enabled,
    bool allowPrincipalChange = false,
  }) async {
    final owner = _settings.dailyAccount()?.googleAccount?.email;
    final profile = _settings.load().academicProfile;
    if (owner == null ||
        normalizeLmsOwner(owner) != current.ownerId ||
        profile?.timetableUniversity != current.schoolId ||
        (enabled && !current.isAuthenticated) ||
        (!allowPrincipalChange &&
            enabled &&
            !_matchesSelectedPrincipal(current.principalId))) {
      return;
    }
    final principal = enabled ? current.principalId : null;
    final next = profile!.withLmsConnection(
      userId: principal,
      enabled: enabled,
    );
    if (next == profile) return;
    _configuredIntegrationEnabled = enabled;
    _configuredLmsUserId = next.lmsUserId;
    final changed = await _settings.updateLmsConnection(
      expectedGoogleEmail: owner,
      expectedSchoolId: current.schoolId,
      userId: principal,
      enabled: enabled,
      expectedLmsUserId: profile.lmsUserId,
      allowPrincipalChange: allowPrincipalChange,
      allowReenable: _configuringAutomaticLogin,
    );
    if (_disposed || !changed) return;
    await _onIntegrationChanged?.call();
  }

  bool _matchesSelectedPrincipal(String? principal) {
    final selected = _settings.load().academicProfile?.lmsUserId;
    return selected == null || principal == selected;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    sync.removeListener(_notify);
    sync.dispose();
    unawaited(_session?.retire().catchError((_) {}));
    super.dispose();
  }
}

/// A presentation-only reference keeps widget export independent of the command
/// service graph. It cannot create an LMS controller while commands are running.
class LmsPresentationState {
  LmsPresentationState({bool Function(CalendarEvent)? cachedVisibility})
    : _cachedVisibility = cachedVisibility;
  final bool Function(CalendarEvent)? _cachedVisibility;
  LmsController? controller;

  bool isEventVisible(CalendarEvent event) =>
      controller?.isEventVisible(event) ??
      _cachedVisibility?.call(event) ??
      (event.lms == null && !event.id.startsWith('lms:'));

  DateTime? get verifiedAt => controller?.sync.lastSuccess;
}
