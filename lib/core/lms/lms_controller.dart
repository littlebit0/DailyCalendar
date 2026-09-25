import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/events/application/event_command_service.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_repository.dart';
import '../settings/settings_repository.dart';
import 'lms_models.dart';
import 'lms_sync_service.dart';
import 'lms_web_session.dart';

/// Coordinates one school browser with the current Daily account. Merely reading
/// this controller never starts a browser or a network request.
class LmsController extends ChangeNotifier {
  LmsController({
    required SettingsRepository settings,
    required EventRepository repository,
    required EventCommandService commands,
    LmsWebSession Function(String owner, String school)? createSession,
  }) : _settings = settings,
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

  final SettingsRepository _settings;
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
  Future<void>? _operation;
  Future<void>? _disconnectOperation;
  Timer? _timer;
  bool _foreground = false;

  String? get schoolId => _settings.load().academicProfile?.timetableUniversity;
  // Only the adapter verified against actual authenticated responses is enabled.
  bool get supported => schoolId == 'smu';
  bool get restoring => _restoring || _disconnecting;
  bool get connected =>
      !_disconnecting &&
      _key == _desiredKey &&
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

  bool isEventVisible(CalendarEvent event) =>
      !(event.lms != null && restoring) && sync.isEventVisible(event);

  /// Called synchronously as soon as account/profile settings change, so stale
  /// in-flight results and cached rows stop being eligible before any await.
  void settingsChanged() {
    if (_key == _desiredKey) return;
    _generation++;
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
      _queuedForce = _queuedForce || force;
      return running.then<void>((_) async {
        if (_disposed || _disconnecting) return;
        final forceAgain = _queuedForce;
        _queuedForce = false;
        if (forceAgain || _key != _desiredKey) {
          await refresh(force: forceAgain);
        }
      });
    }
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

  Future<void> _refresh({required bool force}) async {
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
    final generation = _generation;
    bool valid() =>
        !_disposed &&
        generation == _generation &&
        identical(current, _session) &&
        _key == _desiredKey;
    _restoring = !current.isAuthenticated;
    _notify();
    try {
      if (!current.isAuthenticated) {
        final stored = await current.hasStoredSession();
        if (!valid()) return;
        _stored = stored;
        if (!stored) return;
        _restoredPrincipal = current.storedPrincipalId;
        if (!valid()) return;
        await current.prepare();
      }
      if (!valid()) return;
      _stored = current.isAuthenticated;
      _restoredPrincipal = current.principalId ?? _restoredPrincipal;
      _restoring = false;
      await sync.refresh(force: force);
    } catch (error) {
      if (valid()) {
        final expired =
            error is LmsWebSessionException &&
            error.code == LmsWebSessionError.authenticationRequired;
        if (expired) _stored = false;
        sync.markRestoreFailed(authenticationRequired: expired);
      }
    } finally {
      if (valid()) {
        _restoring = false;
        _notify();
      }
    }
  }

  /// Prepares the account-scoped object; the caller alone presents the visible
  /// official school login. No credentials are filled or submitted by Daily.
  Future<LmsWebSession?> prepareLogin() async {
    await refresh();
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
    _generation++;
    _restoredPrincipal = loginSession.principalId;
    _stored = true;
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
      await current?.disconnect();
      await current?.retire();
    } finally {
      _disconnecting = false;
      _notify();
    }
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
  LmsController? controller;

  bool isEventVisible(CalendarEvent event) =>
      controller?.isEventVisible(event) ??
      (event.lms == null && !event.id.startsWith('lms:'));

  DateTime? get verifiedAt {
    final current = controller;
    if (current == null ||
        current.restoring ||
        current.sync.state != LmsSyncState.ready) {
      return null;
    }
    return current.sync.lastSuccess;
  }
}
