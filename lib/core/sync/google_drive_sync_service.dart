import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../../features/events/domain/event_repository.dart';
import '../../features/events/domain/recurrence_rule.dart';
import '../analytics/product_analytics.dart';
import '../notifications/notification_service.dart';
import '../alarms/alarm_service.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import 'google_drive_auth_service.dart';
import 'sync_service.dart';

class GoogleDriveSyncService implements SyncService {
  GoogleDriveSyncService({
    required GoogleDriveAuthService authService,
    required EventRepository eventRepository,
    required NotificationService notificationService,
    AlarmService alarmService = const UnsupportedAlarmService(),
    required SettingsRepository settingsRepository,
    http.Client? httpClient,
    Duration backupRestoreDelay = _defaultBackupRestoreDelay,
    Duration changeSyncDelay = _defaultChangeSyncDelay,
    List<Duration> automaticRetryDelays = _automaticRetryDelays,
    ProductAnalytics analytics = const NoopProductAnalytics(),
    Future<void> Function()? onEventsChanged,
  }) : _authService = authService,
       _eventRepository = eventRepository,
       _notificationService = notificationService,
       _alarmService = alarmService,
       _settingsRepository = settingsRepository,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _backupRestoreDelay = backupRestoreDelay,
       _changeSyncDelay = changeSyncDelay,
       _retryDelays = automaticRetryDelays,
       _analytics = analytics,
       _onEventsChanged = onEventsChanged;

  static const _legacySyncFileName = 'daily-sync-v1.json';
  static const _settingsFileName = 'daily-sync-v2-settings.json';
  static const _eventFilePrefix = 'daily-sync-v2-event-';
  static const _eventFileSuffix = '.json';
  static const _v2FilePrefix = 'daily-sync-v2-';
  static const _driveHost = 'www.googleapis.com';
  static const _defaultChangeSyncDelay = Duration(seconds: 1);
  static const _defaultBackupRestoreDelay = Duration(seconds: 3);
  static const _driveRequestTimeout = Duration(seconds: 10);
  static const _driveRequestConcurrency = 8;
  static const _automaticRetryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  final GoogleDriveAuthService _authService;
  final EventRepository _eventRepository;
  final NotificationService _notificationService;
  final AlarmService _alarmService;
  final SettingsRepository _settingsRepository;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _backupRestoreDelay;
  final Duration _changeSyncDelay;
  final List<Duration> _retryDelays;
  final ProductAnalytics _analytics;
  final Future<void> Function()? _onEventsChanged;
  Future<void>? _syncInFlight;
  StreamSubscription<GoogleDriveAccount?>? _accountSubscription;
  Timer? _changeSyncTimer;
  Timer? _automaticRetryTimer;
  _SyncRequestKind? _automaticRetryKind;
  final _pendingSyncRequests = <_PendingSyncRequest>[];
  final _queuedEventIds = <String>{};
  var _started = false;
  var _automaticRetryIndex = 0;
  var _manualRestoreDepth = 0;

  final statusNotifier = ValueNotifier<GoogleDriveSyncStatus>(
    const GoogleDriveSyncStatus(),
  );
  final settingsRevisionNotifier = ValueNotifier<int>(0);

  @override
  Future<void> start() {
    return _start(runInitialRestore: true);
  }

  Future<void> startListeningOnly({bool flushPendingChanges = true}) {
    return _start(
      runInitialRestore: false,
      flushPendingChanges: flushPendingChanges,
    );
  }

  Future<void> _start({
    required bool runInitialRestore,
    bool flushPendingChanges = true,
  }) async {
    if (_started) {
      if (!runInitialRestore && !flushPendingChanges) {
        return;
      }
      if (runInitialRestore) {
        return syncOnResume();
      }
      return syncPendingChangesNow();
    }
    _started = true;

    await _authService.initialize();
    _accountSubscription = _authService.accountChanges.listen((account) {
      if (account != null) {
        _requestAutomaticChangeCheck();
      }
    });
    if (runInitialRestore) {
      await checkForRemoteChangesNow().catchError((_) {});
    }
    if (flushPendingChanges) {
      await syncPendingChangesNow().catchError((_) {});
    }
  }

  @override
  Future<void> queueEventUpsert(CalendarEvent event) {
    _queuedEventIds.add(event.id);
    _queueChangeSync();
    return Future.value();
  }

  @override
  Future<void> queueEventDelete(String eventId) {
    _queuedEventIds.add(eventId);
    _queueChangeSync();
    return Future.value();
  }

  @override
  Future<void> queueSettingsBackup() {
    _queueChangeSync();
    return Future.value();
  }

  Future<void> syncNow({bool promptIfNecessary = false}) async {
    final eventIds = await _takePendingEventIds();
    await _enqueueSync(
      _SyncRequestKind.backupThenRestore,
      promptIfNecessary: promptIfNecessary,
      eventIds: eventIds,
      includeSettings: _settingsRepository.hasPendingSettingsSync,
    );
  }

  Future<void> syncOnResume({bool promptIfNecessary = false}) async {
    final eventIds = await _takePendingEventIds();
    await _enqueueSync(
      _SyncRequestKind.backupThenDetectRemoteChanges,
      promptIfNecessary: promptIfNecessary,
      eventIds: eventIds,
      includeSettings: _settingsRepository.hasPendingSettingsSync,
      initializeChangeToken: true,
    );
  }

  Future<void> checkForRemoteChangesNow({
    bool promptIfNecessary = false,
    bool initializeChangeToken = true,
  }) {
    return _enqueueSync(
      _SyncRequestKind.detectRemoteChanges,
      promptIfNecessary: promptIfNecessary,
      initializeChangeToken: initializeChangeToken,
    );
  }

  Future<void> backupNow({
    bool promptIfNecessary = false,
    Set<String>? eventIds,
    bool? includeSettings,
  }) {
    final shouldIncludeSettings = includeSettings ?? eventIds == null;
    if (!shouldIncludeSettings && eventIds != null && eventIds.isEmpty) {
      return Future.value();
    }
    return _enqueueSync(
      _SyncRequestKind.backupOnly,
      promptIfNecessary: promptIfNecessary,
      eventIds: eventIds,
      includeSettings: shouldIncludeSettings,
    );
  }

  Future<void> restoreNow({bool promptIfNecessary = false}) async {
    _manualRestoreDepth += 1;
    _changeSyncTimer?.cancel();
    _changeSyncTimer = null;
    var succeeded = false;
    try {
      await _enqueueSync(
        _SyncRequestKind.restoreOnly,
        promptIfNecessary: promptIfNecessary,
        prioritize: true,
      );
      succeeded = true;
    } finally {
      _manualRestoreDepth -= 1;
      if (succeeded && _manualRestoreDepth == 0 && _queuedEventIds.isNotEmpty) {
        _queueChangeSync();
      }
    }
  }

  Future<void> syncPendingChangesNow({
    bool promptIfNecessary = false,
    bool restoreAfterBackup = false,
  }) async {
    final eventIds = await _takePendingEventIds();
    final includeSettings = _settingsRepository.hasPendingSettingsSync;

    if (restoreAfterBackup) {
      await _enqueueSync(
        _SyncRequestKind.backupThenRestore,
        promptIfNecessary: promptIfNecessary,
        eventIds: eventIds,
        includeSettings: includeSettings,
      );
    } else if (eventIds.isNotEmpty || includeSettings) {
      await backupNow(
        promptIfNecessary: promptIfNecessary,
        eventIds: eventIds,
        includeSettings: includeSettings,
      );
    }
  }

  /// Downloads the current v2 event snapshots without writing to the local
  /// repository. Startup schema migration uses this before Drift opens the
  /// database so it can merge remote changes into a validated working copy.
  Future<List<CalendarEvent>?> downloadEventsForMigration() async {
    final headers = await _authService.authorizationHeaders(
      promptIfNecessary: false,
    );
    if (headers == null) {
      return null;
    }

    final remoteFiles = await _listEventFiles(headers);
    final downloaded = await _mapInBatches(remoteFiles.values, (file) async {
      return _downloadEventFile(headers, file.id);
    });
    final eventsById = <String, CalendarEvent>{};
    for (final item in downloaded.whereType<_DownloadedEvent>()) {
      final event = item.event;
      final existing = eventsById[event.id];
      if (existing == null ||
          _effectiveUpdatedAt(event).isAfter(_effectiveUpdatedAt(existing))) {
        eventsById[event.id] = event;
      }
    }
    return eventsById.values.toList(growable: false);
  }

  Future<Set<String>> _takePendingEventIds() async {
    _changeSyncTimer?.cancel();
    final eventIds = Set<String>.from(_queuedEventIds);
    _queuedEventIds.clear();
    final pendingEvents = await _eventRepository.pendingSyncEvents();
    eventIds.addAll(pendingEvents.map((event) => event.id));
    return eventIds;
  }

  Future<void> deleteCloudBackup({bool promptIfNecessary = false}) async {
    _changeSyncTimer?.cancel();
    _queuedEventIds.clear();
    _pendingSyncRequests.clear();
    final inFlight = _syncInFlight;
    if (inFlight != null) {
      await inFlight;
    }

    final headers = await _authService.authorizationHeaders(
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      return;
    }

    final files = <_DriveFile>[
      ...await _listFiles(
        headers,
        "name contains '$_v2FilePrefix' and trashed = false",
      ),
      ...await _listFiles(
        headers,
        "name = '$_legacySyncFileName' and trashed = false",
      ),
    ];

    for (final file in files) {
      final response = await _httpClient
          .delete(
            Uri.https(_driveHost, '/drive/v3/files/${file.id}'),
            headers: headers,
          )
          .timeout(_driveRequestTimeout);
      _throwIfFailed(response);
    }
  }

  Future<void> stop() async {
    _changeSyncTimer?.cancel();
    _automaticRetryTimer?.cancel();
    _changeSyncTimer = null;
    _automaticRetryTimer = null;
    _automaticRetryKind = null;
    _automaticRetryIndex = 0;
    _queuedEventIds.clear();
    _pendingSyncRequests.clear();
    final inFlight = _syncInFlight;
    if (inFlight != null) {
      await inFlight.catchError((_) {});
    }
    await _accountSubscription?.cancel();
    _accountSubscription = null;
    _started = false;
    statusNotifier.value = const GoogleDriveSyncStatus();
  }

  void dispose() {
    _changeSyncTimer?.cancel();
    _automaticRetryTimer?.cancel();
    unawaited(_accountSubscription?.cancel());
    statusNotifier.dispose();
    settingsRevisionNotifier.dispose();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<void> _enqueueSync(
    _SyncRequestKind kind, {
    required bool promptIfNecessary,
    Set<String>? eventIds,
    bool includeSettings = false,
    bool initializeChangeToken = false,
    bool prioritize = false,
  }) {
    final completer = Completer<void>();
    for (final pending in _pendingSyncRequests.reversed) {
      if (pending.canMerge(kind, eventIds)) {
        pending.merge(
          promptIfNecessary: promptIfNecessary,
          eventIds: eventIds,
          includeSettings: includeSettings,
          initializeChangeToken: initializeChangeToken,
          completer: completer,
        );
        return completer.future;
      }
    }

    final request = _PendingSyncRequest(
      kind: kind,
      promptIfNecessary: promptIfNecessary,
      eventIds: eventIds == null ? null : Set<String>.from(eventIds),
      includeSettings: includeSettings,
      initializeChangeToken: initializeChangeToken,
      completers: [completer],
    );
    if (prioritize) {
      _pendingSyncRequests.insert(0, request);
    } else {
      _pendingSyncRequests.add(request);
    }

    if (_syncInFlight == null) {
      _startSyncDrain();
    }
    return completer.future;
  }

  void _startSyncDrain() {
    final future = _drainSyncQueue().whenComplete(() {
      _syncInFlight = null;
      if (_pendingSyncRequests.isNotEmpty) {
        _startSyncDrain();
      }
    });
    _syncInFlight = future;
  }

  Future<void> _drainSyncQueue() async {
    while (_pendingSyncRequests.isNotEmpty) {
      final request = _pendingSyncRequests.removeAt(0);
      try {
        await _runSyncRequest(request);
        for (final completer in request.completers) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      } on Object catch (error, stackTrace) {
        for (final completer in request.completers) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      }
    }
  }

  void _queueChangeSync() {
    _changeSyncTimer?.cancel();
    if (_manualRestoreDepth > 0) {
      _changeSyncTimer = null;
      return;
    }
    _changeSyncTimer = Timer(_changeSyncDelay, _requestQueuedEventBackup);
  }

  void _requestAutomaticChangeCheck() {
    unawaited(checkForRemoteChangesNow().catchError((_) {}));
  }

  void _requestQueuedEventBackup() {
    final eventIds = Set<String>.from(_queuedEventIds);
    _queuedEventIds.clear();
    final includeSettings = _settingsRepository.hasPendingSettingsSync;
    if (eventIds.isEmpty && !includeSettings) {
      return;
    }
    unawaited(
      backupNow(
        eventIds: eventIds,
        includeSettings: includeSettings,
      ).catchError((_) {}),
    );
  }

  Future<void> _runSyncRequest(_PendingSyncRequest request) async {
    final stopwatch = Stopwatch()..start();
    final analyticsOperation = _analyticsOperation(request.kind);
    final analyticsTrigger = _analyticsTrigger(request);
    _recordAnalytics(
      AnalyticsRecord.syncStarted(
        analyticsOperation,
        trigger: analyticsTrigger,
      ),
    );
    final message = switch (request.kind) {
      _SyncRequestKind.backupOnly => '백업 중',
      _SyncRequestKind.restoreOnly => '복원 중',
      _SyncRequestKind.backupThenRestore => '동기화 중',
      _SyncRequestKind.detectRemoteChanges => '다른 기기 변경 확인 중',
      _SyncRequestKind.backupThenDetectRemoteChanges => '동기화 중',
    };
    statusNotifier.value = statusNotifier.value.copyWith(
      syncing: true,
      message: message,
      clearError: true,
    );
    try {
      var completionMessage = switch (request.kind) {
        _SyncRequestKind.backupOnly => '백업 완료',
        _SyncRequestKind.restoreOnly => '복원 완료',
        _SyncRequestKind.backupThenRestore => '동기화 완료',
        _SyncRequestKind.detectRemoteChanges => '최신 상태',
        _SyncRequestKind.backupThenDetectRemoteChanges => '동기화 완료',
      };
      final headers = await _authService.authorizationHeaders(
        promptIfNecessary: request.promptIfNecessary,
      );
      if (headers == null) {
        throw const GoogleDriveAuthException('Google Drive 연결이 필요합니다.');
      }

      switch (request.kind) {
        case _SyncRequestKind.backupOnly:
          final conflicts = await _backup(
            headers,
            eventIds: request.eventIds,
            includeSettings: request.includeSettings,
          );
          if (conflicts > 0) {
            completionMessage = '일부 백업 보류 · 먼저 복원 필요';
          }
          break;
        case _SyncRequestKind.restoreOnly:
          await _restore(headers);
          break;
        case _SyncRequestKind.backupThenRestore:
          final eventIds = request.eventIds;
          if (eventIds != null && eventIds.isNotEmpty) {
            await _backupQueuedEvents(headers, eventIds);
          }
          if (request.includeSettings) {
            await _backupSettings(headers, _settingsRepository.load());
          }
          statusNotifier.value = statusNotifier.value.copyWith(
            message: '복원 준비 중',
          );
          await Future<void>.delayed(_backupRestoreDelay);
          statusNotifier.value = statusNotifier.value.copyWith(message: '복원 중');
          await _restore(headers);
          break;
        case _SyncRequestKind.detectRemoteChanges:
          final restored = await _detectAndRestoreExternalChanges(
            headers,
            initializeIfNeeded: request.initializeChangeToken,
          );
          completionMessage = restored ? '다른 기기 변경 복원 완료' : '최신 상태';
          break;
        case _SyncRequestKind.backupThenDetectRemoteChanges:
          final eventIds = request.eventIds;
          if (eventIds != null && eventIds.isNotEmpty) {
            await _backupQueuedEvents(headers, eventIds);
          }
          if (request.includeSettings) {
            await _backupSettings(headers, _settingsRepository.load());
          }
          statusNotifier.value = statusNotifier.value.copyWith(
            message: '다른 기기 변경 확인 준비 중',
          );
          await Future<void>.delayed(_backupRestoreDelay);
          final restored = await _detectAndRestoreExternalChanges(
            headers,
            initializeIfNeeded: request.initializeChangeToken,
          );
          completionMessage = restored ? '동기화 완료 · 다른 기기 변경 복원' : '동기화 완료';
          break;
      }
      _resetAutomaticRetry(request.kind);
      statusNotifier.value = statusNotifier.value.copyWith(
        syncing: false,
        lastSyncedAt: DateTime.now(),
        message: completionMessage,
        clearError: true,
      );
      _recordAnalytics(
        AnalyticsRecord.sync(
          analyticsOperation,
          trigger: analyticsTrigger,
          outcome: AnalyticsOutcome.succeeded,
          durationMs: stopwatch.elapsedMilliseconds,
        ),
      );
    } on Object catch (error) {
      _scheduleAutomaticRetry(request, error);
      statusNotifier.value = statusNotifier.value.copyWith(
        syncing: false,
        message: '동기화 실패',
        error: _syncErrorMessage(error),
      );
      _recordAnalytics(
        AnalyticsRecord.sync(
          analyticsOperation,
          trigger: analyticsTrigger,
          outcome:
              categorizeAnalyticsError(error) == AnalyticsErrorCode.canceled
              ? AnalyticsOutcome.canceled
              : AnalyticsOutcome.failed,
          durationMs: stopwatch.elapsedMilliseconds,
          errorCode: categorizeAnalyticsError(error),
        ),
      );
      rethrow;
    }
  }

  AnalyticsSyncOperation _analyticsOperation(_SyncRequestKind kind) {
    return switch (kind) {
      _SyncRequestKind.backupOnly => AnalyticsSyncOperation.backup,
      _SyncRequestKind.restoreOnly => AnalyticsSyncOperation.restore,
      _SyncRequestKind.backupThenRestore =>
        AnalyticsSyncOperation.backupThenRestore,
      _SyncRequestKind.detectRemoteChanges =>
        AnalyticsSyncOperation.detectRemoteChanges,
      _SyncRequestKind.backupThenDetectRemoteChanges =>
        AnalyticsSyncOperation.backupThenDetectRemoteChanges,
    };
  }

  AnalyticsTrigger _analyticsTrigger(_PendingSyncRequest request) {
    if (request.promptIfNecessary) return AnalyticsTrigger.manual;
    return switch (request.kind) {
      _SyncRequestKind.backupOnly => AnalyticsTrigger.localChange,
      _SyncRequestKind.backupThenDetectRemoteChanges => AnalyticsTrigger.resume,
      _SyncRequestKind.detectRemoteChanges =>
        request.initializeChangeToken
            ? AnalyticsTrigger.startup
            : AnalyticsTrigger.automatic,
      _ => AnalyticsTrigger.automatic,
    };
  }

  void _recordAnalytics(AnalyticsRecord record) {
    unawaited(_analytics.record(record).catchError((_) {}));
  }

  void _resetAutomaticRetry(_SyncRequestKind completedKind) {
    if (_automaticRetryKind != null && _automaticRetryKind != completedKind) {
      return;
    }
    _automaticRetryTimer?.cancel();
    _automaticRetryTimer = null;
    _automaticRetryKind = null;
    _automaticRetryIndex = 0;
  }

  void _scheduleAutomaticRetry(_PendingSyncRequest request, Object error) {
    if (request.promptIfNecessary ||
        !_isRetryableSyncError(error) ||
        _automaticRetryTimer != null ||
        _automaticRetryIndex >= _retryDelays.length) {
      return;
    }
    _automaticRetryKind = request.kind;
    final delay = _retryDelays[_automaticRetryIndex++];
    _automaticRetryTimer = Timer(delay, () {
      _automaticRetryTimer = null;
      final retry = switch (request.kind) {
        _SyncRequestKind.backupOnly => syncPendingChangesNow(),
        _SyncRequestKind.detectRemoteChanges => checkForRemoteChangesNow(
          initializeChangeToken: request.initializeChangeToken,
        ),
        _SyncRequestKind.backupThenDetectRemoteChanges => syncOnResume(),
        _SyncRequestKind.backupThenRestore => syncPendingChangesNow(
          restoreAfterBackup: true,
        ),
        _SyncRequestKind.restoreOnly => restoreNow(),
      };
      unawaited(retry.catchError((_) {}));
    });
  }

  bool _isRetryableSyncError(Object error) {
    if (error is TimeoutException) {
      return true;
    }
    if (error is GoogleDriveAuthException) {
      return false;
    }
    final text = error.toString().toLowerCase();
    return text.contains('network') ||
        text.contains('socket') ||
        text.contains('host lookup') ||
        text.contains('시간이 초과') ||
        text.contains('요청이 너무 많') ||
        text.contains('서버 응답이 불안정');
  }

  String _syncErrorMessage(Object error) {
    if (error is GoogleDriveAuthException) {
      return error.message;
    }
    if (error is GoogleDriveSyncException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return '네트워크 응답 시간이 초과되었습니다. 연결 상태를 확인한 뒤 다시 시도해 주세요.';
    }
    final text = error.toString().trim();
    if (text.isEmpty) {
      return '동기화를 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    final lower = text.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network')) {
      return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
    }
    return text;
  }

  Future<int> _backup(
    Map<String, String> authHeaders, {
    Set<String>? eventIds,
    required bool includeSettings,
  }) async {
    var conflicts = 0;
    if (eventIds != null && eventIds.isNotEmpty) {
      conflicts = await _backupQueuedEvents(authHeaders, eventIds);
    }
    if (includeSettings) {
      await _backupSettings(authHeaders, _settingsRepository.load());
    }
    return conflicts;
  }

  Future<void> _restore(Map<String, String> authHeaders) async {
    final localSettingsRevision = _settingsRepository.settingsSyncRevision;
    final localSettingsMutationGeneration =
        _settingsRepository.settingsMutationGeneration;
    final remoteSettings = await _downloadRestorableSettings(authHeaders);
    final remoteEvents = await _downloadAllEvents(authHeaders);
    AppSettings? settingsBeforeRestore;
    AppSettings? restoredSettings;
    var settingsWritten = false;
    final keptLocalEventIds = <String>{};
    late final List<EventRestoreMutation> mutations;
    try {
      if (remoteSettings != null) {
        final settingsApplied = await _settingsRepository
            .applyRestoredSettingsIfUnchanged(
              expectedRevision: localSettingsRevision,
              expectedMutationGeneration: localSettingsMutationGeneration,
              buildRestoredSettings: (current) {
                settingsBeforeRestore = current;
                restoredSettings = _restoredSettingsTarget(
                  remoteSettings,
                  current,
                );
                return restoredSettings!;
              },
            );
        settingsWritten =
            settingsApplied &&
            !_sameSettingsSnapshot(restoredSettings!, settingsBeforeRestore!);
      }
      mutations = await _eventRepository.mergeRestoredEventsAtomically(
        remoteEvents,
        resolve: (local, remote) {
          if (local != null && _shouldKeepLocalEvent(local, remote)) {
            keptLocalEventIds.add(local.id);
            return local;
          }
          if (local != null && _sameEventSnapshot(local, remote)) {
            return local.syncStatus == 'synced'
                ? local
                : local.copyWith(syncStatus: 'synced');
          }
          return remote.copyWith(syncStatus: 'synced');
        },
      );
    } on Object {
      if (settingsWritten) {
        await _settingsRepository.applyRestoredSettingsIfUnchanged(
          expectedRevision: localSettingsRevision,
          expectedMutationGeneration: localSettingsMutationGeneration,
          buildRestoredSettings: (_) => settingsBeforeRestore!,
        );
      }
      rethrow;
    }
    if (settingsWritten) {
      settingsRevisionNotifier.value += 1;
    }
    if (keptLocalEventIds.isNotEmpty) {
      _queuedEventIds.addAll(keptLocalEventIds);
      _queueChangeSync();
    }
    await _applyRestoredEventSideEffects(mutations);
    await _refreshWidgets();
  }

  Future<bool> _detectAndRestoreExternalChanges(
    Map<String, String> authHeaders, {
    required bool initializeIfNeeded,
  }) async {
    final accountEmail =
        _authService.currentAccount?.email ??
        _settingsRepository.dailyAccount()?.googleAccount?.email;
    if (accountEmail == null || accountEmail.trim().isEmpty) {
      throw const GoogleDriveAuthException('Google Drive 계정 정보를 확인하지 못했습니다.');
    }

    final savedToken = _settingsRepository.driveChangePageToken(accountEmail);
    if (savedToken == null) {
      if (!initializeIfNeeded) {
        return false;
      }
      final startToken = await _getDriveStartPageToken(authHeaders);
      await _restore(authHeaders);
      await _settingsRepository.saveDriveChangePageToken(
        accountEmail: accountEmail,
        pageToken: startToken,
      );
      return true;
    }

    final batch = await _listDriveChanges(authHeaders, savedToken);
    final dailyChanges = <String, _DriveChange>{};
    for (final change in batch.changes) {
      if (!change.removed && _isDailySyncFileName(change.fileName)) {
        dailyChanges[change.fileId] = change;
      }
    }

    if (dailyChanges.isEmpty) {
      await _settingsRepository.saveDriveChangePageToken(
        accountEmail: accountEmail,
        pageToken: batch.newStartPageToken,
      );
      return false;
    }

    final localDeviceId = await _settingsRepository.deviceId();
    _DownloadedSettings? externalSettings;
    final externalEvents = <CalendarEvent>[];
    for (final change in dailyChanges.values) {
      if (change.fileName == _settingsFileName) {
        final downloaded = await _downloadSettingsFile(
          authHeaders,
          change.fileId,
        );
        if (downloaded != null && downloaded.sourceDeviceId != localDeviceId) {
          externalSettings = downloaded;
        }
        continue;
      }
      if (_eventIdFromFileName(change.fileName) == null) {
        continue;
      }
      final downloaded = await _downloadEventFile(authHeaders, change.fileId);
      if (downloaded != null && downloaded.sourceDeviceId != localDeviceId) {
        externalEvents.add(downloaded.event);
      }
    }

    var restored = false;
    if (externalSettings != null) {
      restored = await _applyDownloadedSettings(
        externalSettings,
        expectedLocalRevision: _settingsRepository.settingsSyncRevision,
        expectedMutationGeneration:
            _settingsRepository.settingsMutationGeneration,
      );
    }
    externalEvents.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    for (final event in externalEvents) {
      await _saveRestoredEvent(event.copyWith(syncStatus: 'synced'));
      restored = true;
    }
    if (restored) {
      await _refreshWidgets();
    }
    await _settingsRepository.saveDriveChangePageToken(
      accountEmail: accountEmail,
      pageToken: batch.newStartPageToken,
    );
    return restored;
  }

  bool _isDailySyncFileName(String fileName) {
    return fileName == _settingsFileName ||
        _eventIdFromFileName(fileName) != null;
  }

  Future<String> _getDriveStartPageToken(
    Map<String, String> authHeaders,
  ) async {
    final response = await _httpClient
        .get(
          Uri.https(_driveHost, '/drive/v3/changes/startPageToken'),
          headers: authHeaders,
        )
        .timeout(_driveRequestTimeout);
    _throwIfFailed(response);
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final token = decoded['startPageToken'] as String?;
    if (token == null || token.isEmpty) {
      throw const GoogleDriveSyncException(
        'Google Drive 변경 감지 토큰을 확인하지 못했습니다.',
      );
    }
    return token;
  }

  Future<_DriveChangeBatch> _listDriveChanges(
    Map<String, String> authHeaders,
    String startPageToken,
  ) async {
    final changes = <_DriveChange>[];
    var pageToken = startPageToken;
    String? newStartPageToken;
    do {
      final response = await _httpClient
          .get(
            Uri.https(_driveHost, '/drive/v3/changes', {
              'pageToken': pageToken,
              'spaces': 'appDataFolder',
              'includeRemoved': 'true',
              'pageSize': '1000',
              'fields':
                  'nextPageToken,newStartPageToken,changes(fileId,removed,file(id,name,trashed))',
            }),
            headers: authHeaders,
          )
          .timeout(_driveRequestTimeout);
      _throwIfFailed(response);
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final rawChanges = decoded['changes'];
      if (rawChanges is List) {
        changes.addAll(
          rawChanges
              .whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .map(_DriveChange.tryFromJson)
              .whereType<_DriveChange>(),
        );
      }
      final nextPageToken = decoded['nextPageToken'] as String?;
      newStartPageToken = decoded['newStartPageToken'] as String?;
      if (nextPageToken == null || nextPageToken.isEmpty) {
        break;
      }
      pageToken = nextPageToken;
    } while (true);

    if (newStartPageToken == null || newStartPageToken.isEmpty) {
      throw const GoogleDriveSyncException(
        'Google Drive 변경 감지 상태를 갱신하지 못했습니다.',
      );
    }
    return _DriveChangeBatch(
      changes: changes,
      newStartPageToken: newStartPageToken,
    );
  }

  Future<void> _refreshWidgets() async {
    try {
      await _onEventsChanged?.call();
    } on Object {
      // Widget refresh is best-effort and must not fail account sync.
    }
  }

  Future<void> _backupSettings(
    Map<String, String> authHeaders,
    AppSettings localSettings,
  ) async {
    final revision = _settingsRepository.settingsSyncRevision;
    final sourceDeviceId = await _settingsRepository.deviceId();
    final settingsFile = await _findFileByName(authHeaders, _settingsFileName);
    await _uploadJsonFile(
      authHeaders,
      fileName: _settingsFileName,
      fileId: settingsFile?.id,
      jsonBody: _encodeSettingsFile(
        localSettings,
        sourceDeviceId: sourceDeviceId,
      ),
    );
    if (_sameSettingsSnapshot(_settingsRepository.load(), localSettings)) {
      await _settingsRepository.markSettingsSyncedIfRevision(revision);
    }
  }

  Future<_DownloadedSettings?> _downloadRestorableSettings(
    Map<String, String> authHeaders,
  ) async {
    if (_settingsRepository.hasPendingSettingsSync) {
      return null;
    }
    final settingsFile = await _findFileByName(authHeaders, _settingsFileName);
    if (settingsFile == null) {
      return null;
    }
    return _downloadSettingsFile(authHeaders, settingsFile.id);
  }

  Future<bool> _applyDownloadedSettings(
    _DownloadedSettings remoteSettings, {
    required int expectedLocalRevision,
    required int expectedMutationGeneration,
  }) async {
    final applied = await _settingsRepository.applyRestoredSettingsIfUnchanged(
      expectedRevision: expectedLocalRevision,
      expectedMutationGeneration: expectedMutationGeneration,
      buildRestoredSettings: (current) =>
          _restoredSettingsTarget(remoteSettings, current),
    );
    if (!applied) {
      return false;
    }
    settingsRevisionNotifier.value += 1;
    return true;
  }

  AppSettings _restoredSettingsTarget(
    _DownloadedSettings remoteSettings,
    AppSettings localSettings,
  ) {
    return remoteSettings.settings.copyWith(
      onboardingCompleted: localSettings.onboardingCompleted,
      appLockEnabled: localSettings.appLockEnabled,
      appLockBiometricsEnabled: localSettings.appLockBiometricsEnabled,
      appLockMethod: localSettings.appLockMethod,
      language: localSettings.language,
      appTextSize: remoteSettings.hasAppTextSize
          ? remoteSettings.settings.appTextSize
          : localSettings.appTextSize,
      appStartView: remoteSettings.hasAppStartView
          ? remoteSettings.settings.appStartView
          : localSettings.appStartView,
      weekDayLayoutMode: remoteSettings.hasWeekDayLayoutMode
          ? remoteSettings.settings.weekDayLayoutMode
          : localSettings.weekDayLayoutMode,
      calendarEventTitleAlignment: remoteSettings.hasCalendarEventTitleAlignment
          ? remoteSettings.settings.calendarEventTitleAlignment
          : localSettings.calendarEventTitleAlignment,
      calendarEventSortPriority: remoteSettings.hasCalendarEventSortPriority
          ? remoteSettings.settings.calendarEventSortPriority
          : localSettings.calendarEventSortPriority,
      calendarManualEventOrders: remoteSettings.hasCalendarManualEventOrders
          ? mergeCalendarManualEventOrders(
              localSettings.calendarManualEventOrders,
              remoteSettings.settings.calendarManualEventOrders,
            )
          : localSettings.calendarManualEventOrders,
      calendarHolidayBackgroundEnabled:
          remoteSettings.hasCalendarHolidayBackgroundEnabled
          ? remoteSettings.settings.calendarHolidayBackgroundEnabled
          : localSettings.calendarHolidayBackgroundEnabled,
    );
  }

  Future<List<CalendarEvent>> _downloadAllEvents(
    Map<String, String> authHeaders,
  ) async {
    final remoteFiles = await _listEventFiles(authHeaders);
    final remoteById = <String, CalendarEvent>{};

    final downloadedEvents = await _mapInBatches(remoteFiles.entries, (
      entry,
    ) async {
      return MapEntry(
        entry.key,
        await _downloadEventFile(authHeaders, entry.value.id),
      );
    });

    if (remoteFiles.isNotEmpty) {
      statusNotifier.value = statusNotifier.value.copyWith(
        message: '복원 중 · 일정 ${remoteFiles.length}개 확인',
      );
    }

    for (final entry in downloadedEvents) {
      final downloadedEvent = entry.value;
      if (downloadedEvent == null) {
        continue;
      }
      final remoteEvent = downloadedEvent.event;
      final existing = remoteById[entry.key];
      if (existing == null ||
          _effectiveUpdatedAt(
            remoteEvent,
          ).isAfter(_effectiveUpdatedAt(existing))) {
        remoteById[entry.key] = remoteEvent;
      }
    }

    final remoteEvents = remoteById.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return remoteEvents;
  }

  Future<void> _applyRestoredEventSideEffects(
    Iterable<EventRestoreMutation> mutations,
  ) async {
    for (final mutation in mutations) {
      final previous = mutation.previous;
      final current = mutation.current;
      if (previous != null && _sameEventSnapshot(previous, current)) {
        continue;
      }
      try {
        await _notificationService.cancelEventReminder(
          current.id,
          reminderMinutesBeforeList: _combinedReminderMinutes(
            previous,
            current,
          ),
        );
        if (current.deletedAt == null) {
          await _notificationService.scheduleEventReminder(current);
        }
        await _alarmService.cancelEventAlarm(current.id);
        if (current.deletedAt == null) {
          await _alarmService.scheduleEventAlarm(current);
        }
      } on Object {
        // Restored calendar data remains authoritative. Notification and alarm
        // reconciliation is retried when the app next initializes.
      }
    }
  }

  Future<int> _backupQueuedEvents(
    Map<String, String> authHeaders,
    Set<String> eventIds,
  ) async {
    final remoteFileById = await _listEventFilesForIds(authHeaders, eventIds);
    final localDeviceId = await _settingsRepository.deviceId();
    final List<int> conflictCounts = await _mapInBatches<String, int>(
      eventIds,
      (eventId) async {
        final local = await _eventRepository.findById(eventId);
        if (local == null) {
          return 0;
        }

        final remoteFile = remoteFileById[eventId];
        if (remoteFile != null) {
          final remote = await _downloadEventFile(authHeaders, remoteFile.id);
          if (remote != null &&
              remote.sourceDeviceId != localDeviceId &&
              _remoteEventWinsUploadConflict(
                local: local,
                remote: remote.event,
                localDeviceId: localDeviceId,
                remoteDeviceId: remote.sourceDeviceId,
              )) {
            // A backup operation must never mutate local data. Keep the local
            // revision pending so an explicit restore can resolve the conflict.
            return 1;
          }
        }

        await _uploadEventFile(authHeaders, local, remoteFile);
        await _saveSyncedEvent(local);
        return 0;
      },
    );
    var conflictCount = 0;
    for (final count in conflictCounts) {
      conflictCount += count;
    }
    return conflictCount;
  }

  bool _remoteEventWinsUploadConflict({
    required CalendarEvent local,
    required CalendarEvent remote,
    required String localDeviceId,
    required String? remoteDeviceId,
  }) {
    final updatedComparison = _effectiveUpdatedAt(
      remote,
    ).compareTo(_effectiveUpdatedAt(local));
    if (updatedComparison != 0) {
      return updatedComparison > 0;
    }
    if (_sameEventSnapshot(local, remote)) {
      return false;
    }
    return (remoteDeviceId ?? '').compareTo(localDeviceId) > 0;
  }

  Future<List<T>> _mapInBatches<S, T>(
    Iterable<S> items,
    Future<T> Function(S item) mapper,
  ) async {
    final source = items.toList();
    final result = <T>[];
    for (
      var index = 0;
      index < source.length;
      index += _driveRequestConcurrency
    ) {
      final end = min(index + _driveRequestConcurrency, source.length);
      result.addAll(await Future.wait(source.sublist(index, end).map(mapper)));
    }
    return result;
  }

  Future<Map<String, _DriveFile>> _listEventFilesForIds(
    Map<String, String> authHeaders,
    Set<String> eventIds,
  ) async {
    if (eventIds.isEmpty) {
      return {};
    }
    final nameQuery = eventIds
        .map(_eventFileName)
        .map((name) => "name = '${_escapeDriveQueryString(name)}'")
        .join(' or ');
    final files = await _listFiles(
      authHeaders,
      '($nameQuery) and trashed = false',
      pageSize: eventIds.length,
    );
    final result = <String, _DriveFile>{};
    for (final file in files) {
      final eventId = _eventIdFromFileName(file.name);
      if (eventId != null) {
        result[eventId] = file;
      }
    }
    return result;
  }

  String _escapeDriveQueryString(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  Future<void> _saveSyncedEvent(CalendarEvent event) async {
    final existing = await _eventRepository.findById(event.id);
    if (existing == null) {
      return;
    }
    if (jsonEncode(_eventToJson(existing)) != jsonEncode(_eventToJson(event))) {
      // A newer local edit landed while this upload was in flight. Keep that
      // revision pending instead of replacing it with the uploaded snapshot.
      return;
    }
    await _eventRepository.markSynced(event.id);
  }

  Future<void> _saveRestoredEvent(CalendarEvent event) async {
    final existing = await _eventRepository.findById(event.id);
    if (existing != null && _shouldKeepLocalEvent(existing, event)) {
      _queuedEventIds.add(existing.id);
      _queueChangeSync();
      return;
    }
    if (existing != null && _sameEventSnapshot(existing, event)) {
      if (existing.syncStatus != 'synced') {
        await _eventRepository.markSynced(existing.id);
      }
      return;
    }
    await _eventRepository.save(event);
    await _notificationService.cancelEventReminder(
      event.id,
      reminderMinutesBeforeList: _combinedReminderMinutes(existing, event),
    );
    if (event.deletedAt == null) {
      await _notificationService.scheduleEventReminder(event);
    }
    await _alarmService.cancelEventAlarm(event.id);
    if (event.deletedAt == null) {
      await _alarmService.scheduleEventAlarm(event);
    }
  }

  bool _shouldKeepLocalEvent(
    CalendarEvent existing,
    CalendarEvent restoredSnapshot,
  ) {
    final localUpdatedAt = _effectiveUpdatedAt(existing);
    final restoredUpdatedAt = _effectiveUpdatedAt(restoredSnapshot);
    if (localUpdatedAt.isAfter(restoredUpdatedAt)) {
      return true;
    }

    if (existing.syncStatus == 'synced') {
      return false;
    }

    return jsonEncode(_eventToJson(existing)) !=
        jsonEncode(_eventToJson(restoredSnapshot));
  }

  bool _sameEventSnapshot(CalendarEvent left, CalendarEvent right) {
    return jsonEncode(_eventToJson(left)) == jsonEncode(_eventToJson(right));
  }

  bool _sameSettingsSnapshot(AppSettings left, AppSettings right) {
    return jsonEncode(_settingsToJson(left)) ==
        jsonEncode(_settingsToJson(right));
  }

  DateTime _effectiveUpdatedAt(CalendarEvent event) {
    final deletedAt = event.deletedAt;
    if (deletedAt != null && deletedAt.isAfter(event.updatedAt)) {
      return deletedAt;
    }
    return event.updatedAt;
  }

  Future<Map<String, _DriveFile>> _listEventFiles(
    Map<String, String> authHeaders,
  ) async {
    final files = await _listFiles(
      authHeaders,
      "name contains '$_eventFilePrefix' and trashed = false",
    );
    final result = <String, _DriveFile>{};
    for (final file in files) {
      final eventId = _eventIdFromFileName(file.name);
      if (eventId != null) {
        result[eventId] = file;
      }
    }
    return result;
  }

  Future<_DriveFile?> _findFileByName(
    Map<String, String> authHeaders,
    String name,
  ) async {
    final files = await _listFiles(
      authHeaders,
      "name = '$name' and trashed = false",
      pageSize: 1,
    );
    return files.isEmpty ? null : files.first;
  }

  Future<List<_DriveFile>> _listFiles(
    Map<String, String> authHeaders,
    String query, {
    int pageSize = 1000,
  }) async {
    final files = <_DriveFile>[];
    String? pageToken;
    do {
      final queryParameters = {
        'spaces': 'appDataFolder',
        'q': query,
        'fields': 'nextPageToken,files(id,name,modifiedTime)',
        'pageSize': '$pageSize',
      };
      final token = pageToken;
      if (token != null) {
        queryParameters['pageToken'] = token;
      }
      final response = await _httpClient
          .get(
            Uri.https(_driveHost, '/drive/v3/files', queryParameters),
            headers: authHeaders,
          )
          .timeout(_driveRequestTimeout);
      _throwIfFailed(response);

      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final rawFiles = decoded['files'];
      if (rawFiles is List) {
        files.addAll(
          rawFiles
              .whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .map(_DriveFile.tryFromJson)
              .whereType<_DriveFile>(),
        );
      }
      pageToken = decoded['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return files;
  }

  Future<_DownloadedEvent?> _downloadEventFile(
    Map<String, String> authHeaders,
    String fileId,
  ) async {
    final response = await _httpClient
        .get(
          Uri.https(_driveHost, '/drive/v3/files/$fileId', {'alt': 'media'}),
          headers: authHeaders,
        )
        .timeout(_driveRequestTimeout);
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final event = decoded['event'];
    final parsedEvent = _eventFromJson(
      event is Map ? Map<String, Object?>.from(event) : decoded,
    );
    if (parsedEvent == null) {
      throw const GoogleDriveSyncException('Google Drive 일정 백업 데이터가 손상되었습니다.');
    }
    return _DownloadedEvent(
      event: parsedEvent,
      sourceDeviceId: decoded['sourceDeviceId'] as String?,
    );
  }

  Future<_DownloadedSettings?> _downloadSettingsFile(
    Map<String, String> authHeaders,
    String fileId,
  ) async {
    final response = await _httpClient
        .get(
          Uri.https(_driveHost, '/drive/v3/files/$fileId', {'alt': 'media'}),
          headers: authHeaders,
        )
        .timeout(_driveRequestTimeout);
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final settings = decoded['settings'];
    if (settings is! Map) {
      throw const GoogleDriveSyncException('Google Drive 설정 백업 데이터가 손상되었습니다.');
    }
    final settingsJson = Map<String, Object?>.from(settings);
    return _DownloadedSettings(
      settings: _settingsFromJson(settingsJson),
      sourceDeviceId: decoded['sourceDeviceId'] as String?,
      hasAppTextSize:
          settingsJson.containsKey('appTextSize') ||
          settingsJson.containsKey('calendarEventTextSize'),
      hasAppStartView: settingsJson.containsKey('appStartView'),
      hasWeekDayLayoutMode: settingsJson.containsKey('weekDayLayoutMode'),
      hasCalendarEventTitleAlignment: settingsJson.containsKey(
        'calendarEventTitleAlignment',
      ),
      hasCalendarEventSortPriority: settingsJson.containsKey(
        'calendarEventSortPriority',
      ),
      hasCalendarManualEventOrders: settingsJson.containsKey(
        'calendarManualEventOrders',
      ),
      hasCalendarHolidayBackgroundEnabled: settingsJson.containsKey(
        'calendarHolidayBackgroundEnabled',
      ),
    );
  }

  Future<void> _uploadEventFile(
    Map<String, String> authHeaders,
    CalendarEvent event,
    _DriveFile? remoteFile,
  ) async {
    final sourceDeviceId = await _settingsRepository.deviceId();
    await _uploadJsonFile(
      authHeaders,
      fileName: _eventFileName(event.id),
      fileId: remoteFile?.id,
      jsonBody: _encodeEventFile(event, sourceDeviceId: sourceDeviceId),
    );
  }

  Future<void> _uploadJsonFile(
    Map<String, String> authHeaders, {
    required String fileName,
    required String jsonBody,
    String? fileId,
  }) async {
    if (fileId != null) {
      final response = await _httpClient
          .patch(
            Uri.https(_driveHost, '/upload/drive/v3/files/$fileId', {
              'uploadType': 'media',
              'fields': 'id',
            }),
            headers: {
              ...authHeaders,
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: utf8.encode(jsonBody),
          )
          .timeout(_driveRequestTimeout);
      _throwIfFailed(response);
      return;
    }

    final boundary = 'daily-sync-v2-${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': ['appDataFolder'],
    });
    final body = utf8.encode(
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$metadata\r\n'
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$jsonBody\r\n'
      '--$boundary--\r\n',
    );

    final response = await _httpClient
        .post(
          Uri.https(_driveHost, '/upload/drive/v3/files', {
            'uploadType': 'multipart',
            'fields': 'id',
          }),
          headers: {
            ...authHeaders,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body,
        )
        .timeout(_driveRequestTimeout);
    _throwIfFailed(response);
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw GoogleDriveSyncException(_driveRequestErrorMessage(response));
  }

  String _driveRequestErrorMessage(http.Response response) {
    final body = response.body.toLowerCase();
    if (response.statusCode == 401 ||
        body.contains('invalid_grant') ||
        body.contains('invalid_token')) {
      return 'Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.';
    }
    if (response.statusCode == 403 ||
        body.contains('insufficient') ||
        body.contains('permission')) {
      return 'Google Drive 권한이 부족합니다. 다시 연결해 권한을 승인해 주세요.';
    }
    if (response.statusCode == 404) {
      return 'Google Drive 백업 파일을 찾지 못했습니다. 다시 동기화해 주세요.';
    }
    if (response.statusCode == 409) {
      return 'Google Drive 백업 상태가 바뀌었습니다. 다시 동기화해 주세요.';
    }
    if (response.statusCode == 429) {
      return 'Google Drive 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (response.statusCode >= 500) {
      return 'Google Drive 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.';
    }
    return 'Google Drive 동기화를 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

  String _encodeEventFile(
    CalendarEvent event, {
    required String sourceDeviceId,
  }) {
    return jsonEncode({
      'schemaVersion': 2,
      'type': 'event',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceDeviceId': sourceDeviceId,
      'event': _eventToJson(event),
    });
  }

  String _encodeSettingsFile(
    AppSettings settings, {
    required String sourceDeviceId,
  }) {
    return jsonEncode({
      'schemaVersion': 2,
      'type': 'settings',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceDeviceId': sourceDeviceId,
      'settings': _settingsToJson(settings),
    });
  }

  String _eventFileName(String eventId) {
    return '$_eventFilePrefix$eventId$_eventFileSuffix';
  }

  String? _eventIdFromFileName(String fileName) {
    if (!fileName.startsWith(_eventFilePrefix) ||
        !fileName.endsWith(_eventFileSuffix)) {
      return null;
    }
    return fileName.substring(
      _eventFilePrefix.length,
      fileName.length - _eventFileSuffix.length,
    );
  }

  Map<String, Object?> _eventToJson(CalendarEvent event) {
    final normalized = event.normalizeAllDayBounds();
    return {
      'id': normalized.id,
      'title': normalized.title,
      'memo': normalized.memo,
      'location': normalized.location,
      'url': normalized.url,
      'weather': normalized.weather,
      'startAt': _dateTimeToJson(normalized.startAt, normalized.allDay),
      'endAt': _dateTimeToJson(normalized.endAt, normalized.allDay),
      if (normalized.allDay) ...{
        'startDate': _dateOnlyToJson(normalized.startAt),
        'endDate': _dateOnlyToJson(normalized.endAt),
      },
      'allDay': normalized.allDay,
      'category': normalized.category.name,
      'categoryLabel': normalized.category.label,
      'categoryLocked': normalized.category.locked,
      'colorValue': normalized.colorValue,
      'reminderMinutesBefore': normalized.reminderMinutesBefore,
      'reminderMinutesBeforeList': normalized.reminderMinutesBeforeList,
      'recurrenceFrequency': normalized.recurrence.frequency.name,
      'recurrenceInterval': normalized.recurrence.interval,
      'recurrenceUntil': normalized.recurrence.until?.toUtc().toIso8601String(),
      'recurrenceCount': normalized.recurrence.count,
      'recurrenceExcludedDates': normalized.recurrence.excludedDates
          .map((date) => DateTime(date.year, date.month, date.day))
          .map((date) => date.toUtc().toIso8601String())
          .toList(),
      'createdAt': normalized.createdAt.toUtc().toIso8601String(),
      'updatedAt': normalized.updatedAt.toUtc().toIso8601String(),
      'deletedAt': normalized.deletedAt?.toUtc().toIso8601String(),
      'deviceId': normalized.deviceId,
      'showDday': normalized.showDday,
      'completed': normalized.completed,
      'alarmEnabled': normalized.alarmEnabled,
      'allDayAlarmMinutes': normalized.allDayAlarmMinutes,
    };
  }

  CalendarEvent? _eventFromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final allDay = json['allDay'] as bool? ?? false;
    final startAt = allDay
        ? _readAllDayDate(json['startDate'] ?? json['startAt'])
        : _readDate(json['startAt']);
    final endAt = allDay
        ? _readAllDayDate(json['endDate'] ?? json['endAt'])
        : _readDate(json['endAt']);
    final createdAt = _readDate(json['createdAt']);
    final updatedAt = _readDate(json['updatedAt']);
    if (id == null ||
        startAt == null ||
        endAt == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    final colorValue = json['colorValue'] as int?;
    final category = _categoryFromJson(json, colorValue);
    return CalendarEvent(
      id: id,
      title: json['title'] as String? ?? 'New event',
      memo: json['memo'] as String?,
      location: json['location'] as String?,
      url: json['url'] as String?,
      weather: json['weather'] as String?,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      category: category,
      colorValue: colorValue ?? category.colorValue,
      reminderMinutesBeforeList: _reminderMinutesFromJson(json),
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.fromName(
          json['recurrenceFrequency'] as String?,
        ),
        interval: json['recurrenceInterval'] as int? ?? 1,
        until: _readDate(json['recurrenceUntil']),
        count: json['recurrenceCount'] as int?,
        excludedDates: _dateListValue(json['recurrenceExcludedDates']),
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: _readDate(json['deletedAt']),
      deviceId: json['deviceId'] as String? ?? '',
      syncStatus: 'synced',
      showDday: json['showDday'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      alarmEnabled: json['alarmEnabled'] as bool? ?? false,
      allDayAlarmMinutes: json['allDayAlarmMinutes'] as int? ?? 9 * 60,
    ).normalizeAllDayBounds();
  }

  String _dateTimeToJson(DateTime value, bool allDay) {
    if (allDay) {
      return DateTime(value.year, value.month, value.day).toIso8601String();
    }
    return value.toUtc().toIso8601String();
  }

  String _dateOnlyToJson(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _readDate(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  DateTime? _readAllDayDate(Object? value) {
    if (value is! String) {
      return null;
    }
    final datePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (datePrefix != null) {
      final year = int.parse(datePrefix.group(1)!);
      final month = int.parse(datePrefix.group(2)!);
      final day = int.parse(datePrefix.group(3)!);
      final date = DateTime(year, month, day);
      if (date.year == year && date.month == month && date.day == day) {
        return date;
      }
    }
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  List<DateTime> _dateListValue(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map((date) => date.toLocal())
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList();
  }

  EventCategory _categoryFromJson(Map<String, Object?> json, int? colorValue) {
    final rawCategory = json['category'] as String?;
    final label = json['categoryLabel'] as String?;
    if (label != null && label.isNotEmpty) {
      return EventCategory.fromJson({
        'id': rawCategory ?? '',
        'label': label,
        'colorValue': colorValue,
        'locked': json['categoryLocked'] as bool? ?? false,
      });
    }
    return EventCategory.fromStored(rawCategory, colorValue: colorValue);
  }

  Map<String, Object?> _settingsToJson(AppSettings settings) {
    return {
      'defaultReminderMinutes': settings.defaultReminderMinutes,
      'defaultReminderMinutesList': settings.defaultReminderMinutesList,
      'allDayReminderHour': settings.allDayReminderHour,
      'allDayReminderMinute': settings.allDayReminderMinute,
      'morningBriefingHour': settings.morningBriefingHour,
      'morningBriefingMinute': settings.morningBriefingMinute,
      'morningBriefingEnabled': settings.morningBriefingEnabled,
      'weekStartsOnMonday': settings.weekStartsOnMonday,
      'showLunarDates': settings.showLunarDates,
      'showAdjacentMonthDates': settings.showAdjacentMonthDates,
      'onboardingCompleted': settings.onboardingCompleted,
      'aiEnabled': settings.aiEnabled,
      'aiOnlyForComplexInput': settings.aiOnlyForComplexInput,
      'blockSensitiveAi': settings.blockSensitiveAi,
      'categories': settings.categories
          .map((category) => category.toJson())
          .toList(),
      'dDayReminderOffsets': settings.dDayReminderOffsets,
      'appTextSize': settings.appTextSize.name,
      'appStartView': settings.appStartView.name,
      'defaultCalendarView': settings.defaultCalendarView.name,
      'weekDayLayoutMode': settings.weekDayLayoutMode.name,
      'calendarEventTitleAlignment': settings.calendarEventTitleAlignment.name,
      'calendarEventSortPriority': settings.calendarEventSortPriority.name,
      'calendarManualEventOrders': settings.calendarManualEventOrders.map(
        (date, order) => MapEntry(date, order.toJson()),
      ),
      'hiddenCategoryIds': settings.hiddenCategoryIds,
      'calendarShowHolidays': settings.calendarShowHolidays,
      'calendarHolidayBackgroundEnabled':
          settings.calendarHolidayBackgroundEnabled,
      'calendarDdayOnly': settings.calendarDdayOnly,
      'use24HourTime': settings.use24HourTime,
      'themeMode': settings.themeMode.name,
      'monthNavigationMode': settings.monthNavigationMode.name,
    };
  }

  AppSettings _settingsFromJson(Map<String, Object?> json) {
    return AppSettings(
      defaultReminderMinutesList: json.containsKey('defaultReminderMinutesList')
          ? _intListValue(json['defaultReminderMinutesList'], const <int>[])
          : <int>[_intValue(json['defaultReminderMinutes'], 60)],
      allDayReminderHour: _intValue(json['allDayReminderHour'], 9),
      allDayReminderMinute: _intValue(json['allDayReminderMinute'], 0),
      morningBriefingHour: _intValue(json['morningBriefingHour'], 8),
      morningBriefingMinute: _intValue(json['morningBriefingMinute'], 0),
      morningBriefingEnabled: json['morningBriefingEnabled'] as bool? ?? true,
      weekStartsOnMonday: json['weekStartsOnMonday'] as bool? ?? false,
      showLunarDates: json['showLunarDates'] as bool? ?? true,
      showAdjacentMonthDates: json['showAdjacentMonthDates'] as bool? ?? true,
      monthNavigationMode: MonthNavigationMode.fromName(
        json['monthNavigationMode'] as String?,
      ),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      aiEnabled: json['aiEnabled'] as bool? ?? false,
      aiOnlyForComplexInput: json['aiOnlyForComplexInput'] as bool? ?? true,
      blockSensitiveAi: json['blockSensitiveAi'] as bool? ?? true,
      categories: _categoriesFromJson(json['categories']),
      dDayReminderOffsets: _intListValue(json['dDayReminderOffsets'], const [
        -7,
        -3,
        -1,
        0,
      ]),
      appTextSize: AppTextSize.fromName(
        json['appTextSize'] as String? ??
            json['calendarEventTextSize'] as String?,
      ),
      appStartView: AppStartView.fromName(json['appStartView'] as String?),
      defaultCalendarView: CalendarViewMode.fromName(
        json['defaultCalendarView'] as String?,
      ),
      weekDayLayoutMode: WeekDayLayoutMode.fromName(
        json['weekDayLayoutMode'] as String?,
      ),
      calendarEventTitleAlignment: CalendarEventTitleAlignment.fromName(
        json['calendarEventTitleAlignment'] as String?,
      ),
      calendarEventSortPriority: CalendarEventSortPriority.fromName(
        json['calendarEventSortPriority'] as String?,
      ),
      calendarManualEventOrders: _manualEventOrdersFromJson(
        json['calendarManualEventOrders'],
      ),
      hiddenCategoryIds: _stringListValue(json['hiddenCategoryIds']),
      calendarShowHolidays: json['calendarShowHolidays'] as bool? ?? true,
      calendarHolidayBackgroundEnabled:
          json['calendarHolidayBackgroundEnabled'] as bool? ?? true,
      calendarDdayOnly: json['calendarDdayOnly'] as bool? ?? false,
      use24HourTime: json['use24HourTime'] as bool? ?? true,
      themeMode: AppThemeMode.fromName(json['themeMode'] as String?),
    );
  }

  List<EventCategory> _categoriesFromJson(Object? value) {
    if (value is! List) {
      return const [EventCategory.basic, EventCategory.holiday];
    }
    final categories = value
        .whereType<Map>()
        .map((item) => EventCategory.fromJson(Map<String, Object?>.from(item)))
        .where((category) => category.id.isNotEmpty)
        .toList();
    if (!categories.any(
      (category) => category.id == EventCategory.holiday.id,
    )) {
      categories.add(EventCategory.holiday);
    }
    return categories;
  }

  Map<String, CalendarManualEventOrder> _manualEventOrdersFromJson(
    Object? value,
  ) {
    if (value is! Map) {
      return const <String, CalendarManualEventOrder>{};
    }
    final orders = <String, CalendarManualEventOrder>{};
    for (final entry in value.entries) {
      final date = entry.key?.toString() ?? '';
      final order = CalendarManualEventOrder.fromJson(entry.value);
      if (date.isNotEmpty && order != null) {
        orders[date] = order;
      }
    }
    return orders;
  }

  List<int> _intListValue(Object? value, List<int> fallback) {
    if (value is! List) {
      return fallback;
    }
    final items = value.whereType<int>().toList();
    return items.isEmpty ? fallback : (items..sort());
  }

  List<int> _reminderMinutesFromJson(Map<String, Object?> json) {
    final listValue = json['reminderMinutesBeforeList'];
    if (listValue is List) {
      return normalizeReminderMinutes(listValue.whereType<int>());
    }
    final legacyValue = json['reminderMinutesBefore'];
    if (legacyValue is int) {
      return normalizeReminderMinutes([legacyValue]);
    }
    return const <int>[];
  }

  List<int> _combinedReminderMinutes(
    CalendarEvent? existing,
    CalendarEvent updated,
  ) {
    return normalizeReminderMinutes([
      ...?existing?.reminderMinutesBeforeList,
      ...updated.reminderMinutesBeforeList,
    ]);
  }

  List<String> _stringListValue(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<String>().toList();
  }

  int _intValue(Object? value, int fallback) {
    return value is int ? value : fallback;
  }
}

class GoogleDriveSyncException implements Exception {
  const GoogleDriveSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleDriveSyncStatus {
  const GoogleDriveSyncStatus({
    this.syncing = false,
    this.lastSyncedAt,
    this.message = '',
    this.error,
  });

  final bool syncing;
  final DateTime? lastSyncedAt;
  final String message;
  final String? error;

  GoogleDriveSyncStatus copyWith({
    bool? syncing,
    DateTime? lastSyncedAt,
    String? message,
    String? error,
    bool clearError = false,
  }) {
    return GoogleDriveSyncStatus(
      syncing: syncing ?? this.syncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }
}

enum _SyncRequestKind {
  backupOnly,
  restoreOnly,
  backupThenRestore,
  detectRemoteChanges,
  backupThenDetectRemoteChanges,
}

class _DownloadedSettings {
  const _DownloadedSettings({
    required this.settings,
    required this.hasAppTextSize,
    required this.hasAppStartView,
    required this.hasWeekDayLayoutMode,
    required this.hasCalendarEventTitleAlignment,
    required this.hasCalendarEventSortPriority,
    required this.hasCalendarManualEventOrders,
    required this.hasCalendarHolidayBackgroundEnabled,
    required this.sourceDeviceId,
  });

  final AppSettings settings;
  final bool hasAppTextSize;
  final bool hasAppStartView;
  final bool hasWeekDayLayoutMode;
  final bool hasCalendarEventTitleAlignment;
  final bool hasCalendarEventSortPriority;
  final bool hasCalendarManualEventOrders;
  final bool hasCalendarHolidayBackgroundEnabled;
  final String? sourceDeviceId;
}

class _DownloadedEvent {
  const _DownloadedEvent({required this.event, required this.sourceDeviceId});

  final CalendarEvent event;
  final String? sourceDeviceId;
}

class _PendingSyncRequest {
  _PendingSyncRequest({
    required this.kind,
    required this.promptIfNecessary,
    required this.completers,
    required this.includeSettings,
    required this.initializeChangeToken,
    this.eventIds,
  });

  final _SyncRequestKind kind;
  bool promptIfNecessary;
  bool includeSettings;
  bool initializeChangeToken;
  final Set<String>? eventIds;
  final List<Completer<void>> completers;

  bool canMerge(_SyncRequestKind nextKind, Set<String>? nextEventIds) {
    if (kind != nextKind) {
      return false;
    }
    if (kind == _SyncRequestKind.restoreOnly) {
      return true;
    }
    return (eventIds == null) == (nextEventIds == null);
  }

  void merge({
    required bool promptIfNecessary,
    required Set<String>? eventIds,
    required bool includeSettings,
    required bool initializeChangeToken,
    required Completer<void> completer,
  }) {
    this.promptIfNecessary = this.promptIfNecessary || promptIfNecessary;
    this.includeSettings = this.includeSettings || includeSettings;
    this.initializeChangeToken =
        this.initializeChangeToken || initializeChangeToken;
    if (eventIds != null) {
      this.eventIds?.addAll(eventIds);
    }
    completers.add(completer);
  }
}

class _DriveChangeBatch {
  const _DriveChangeBatch({
    required this.changes,
    required this.newStartPageToken,
  });

  final List<_DriveChange> changes;
  final String newStartPageToken;
}

class _DriveChange {
  const _DriveChange({
    required this.fileId,
    required this.fileName,
    required this.removed,
  });

  static _DriveChange? tryFromJson(Map<String, Object?> json) {
    final fileId = json['fileId'] as String?;
    final file = json['file'];
    final fileJson = file is Map ? Map<String, Object?>.from(file) : null;
    final fileName = fileJson?['name'] as String?;
    if (fileId == null || fileName == null) {
      return null;
    }
    return _DriveChange(
      fileId: fileId,
      fileName: fileName,
      removed:
          json['removed'] as bool? ?? fileJson?['trashed'] as bool? ?? false,
    );
  }

  final String fileId;
  final String fileName;
  final bool removed;
}

class _DriveFile {
  const _DriveFile({required this.id, required this.name});

  static _DriveFile? tryFromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    if (id == null || name == null) {
      return null;
    }
    return _DriveFile(id: id, name: name);
  }

  final String id;
  final String name;
}
