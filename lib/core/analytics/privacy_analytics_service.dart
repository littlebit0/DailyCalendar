import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'product_analytics.dart';
import '../platform/app_build_identity.dart';

class AnalyticsEnvironment {
  const AnalyticsEnvironment({
    required this.appVersion,
    required this.platform,
    required this.osMajor,
  });

  final String appVersion;
  final String platform;
  final int osMajor;

  Map<String, Object> toJson() => {
    'appVersion': appVersion,
    'platform': platform,
    'osMajor': osMajor,
  };
}

class PrivacyAnalyticsService implements ProductAnalytics {
  static const _productionEndpoint =
      'https://littlebit.tail6514a4.ts.net/v1/events';
  PrivacyAnalyticsService({
    required SharedPreferences preferences,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
    Uri? endpoint,
    Future<AnalyticsEnvironment> Function()? environmentLoader,
    DateTime Function()? now,
    String Function()? idGenerator,
    double Function()? refreshRateProvider,
    bool Function()? foregroundProvider,
    AnalyticsBuildMode? buildMode,
  }) : _preferences = preferences,
       _refreshRateProvider = refreshRateProvider ?? _displayRefreshRate,
       _foregroundProvider = foregroundProvider ?? _appInForeground,
       _buildMode =
           buildMode ??
           (kReleaseMode
               ? AnalyticsBuildMode.release
               : kProfileMode
               ? AnalyticsBuildMode.profile
               : AnalyticsBuildMode.debug),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _endpoint = endpoint ?? _configuredEndpoint,
       _environmentLoader = environmentLoader ?? _loadEnvironment,
       _now = now ?? DateTime.now,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _enabled = ValueNotifier<bool>(
         preferences.getBool(_enabledKey) ?? false,
       ),
       _consentPromptCompleted = ValueNotifier<bool>(
         preferences.getBool(_consentPromptCompletedKey) ??
             preferences.containsKey(_enabledKey),
       );

  static const _consentJournalKey = 'daily.analytics.consent.v1';
  static const _enabledKey = 'anonymousAnalyticsEnabled';
  static const _consentPromptCompletedKey =
      'anonymousAnalyticsConsentPromptCompletedV1';
  static const _queueKey = 'anonymousAnalyticsQueueV1';
  static const _schemaVersion = 1;
  static const _maxQueueLength = 200;
  static const _batchSize = 25;
  static const _maxEventAge = Duration(days: 7);
  static const _requestTimeout = Duration(seconds: 8);
  static const _retryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
    Duration(hours: 1),
  ];
  static final Uri? _configuredEndpoint = _parseConfiguredEndpoint();

  final SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage;
  Future<void> _consentTail = Future<void>.value();
  Future<void> _queueTail = Future<void>.value();
  Future<void>? _initialization;
  int _generation = 0;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri? _endpoint;
  final Future<AnalyticsEnvironment> Function() _environmentLoader;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final double Function() _refreshRateProvider;
  final bool Function() _foregroundProvider;
  final AnalyticsBuildMode _buildMode;
  _FrameWindow? _frameWindow;
  final ValueNotifier<bool> _enabled;
  final ValueNotifier<bool> _consentPromptCompleted;
  late final String _sessionId = _idGenerator();
  AnalyticsEnvironment? _environment;
  List<_QueuedAnalyticsEvent> _queue = [];
  Future<void>? _flushOperation;
  Timer? _retryTimer;
  bool _initialized = false;
  bool _performanceMonitoring = false;

  @override
  bool get enabled => _enabled.value;

  @override
  ValueListenable<bool> get enabledListenable => _enabled;

  @override
  bool get consentPromptCompleted => _consentPromptCompleted.value;

  @override
  ValueListenable<bool> get consentPromptCompletedListenable =>
      _consentPromptCompleted;

  @override
  int get pendingEventCount => _queue.length;

  @override
  Future<void> completeConsentPrompt({required bool enabled}) async {
    await setEnabled(enabled);
    if (!await _preferences.setBool(_consentPromptCompletedKey, true)) {
      throw StateError('분석 동의 안내 완료 상태를 저장하지 못했습니다. 다시 시도해 주세요.');
    }
    await _preferences.reload();
    if (_preferences.getBool(_consentPromptCompletedKey) != true) {
      throw StateError('분석 동의 안내 완료 상태를 확인하지 못했습니다.');
    }
    _consentPromptCompleted.value = true;
  }

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final generation = _generation;
    try {
      final saved = await _secureStorage.read(key: _consentJournalKey);
      if (generation == _generation &&
          (saved == 'off' || (saved != null && saved != 'on'))) {
        _enabled.value = false;
      }
    } on Object {
      // An unreadable consent record never grants collection permission.
      if (generation == _generation) _enabled.value = false;
    }
    try {
      _environment = await _environmentLoader();
    } on Object {
      _environment = AnalyticsEnvironment(
        appVersion: '0.0.0',
        platform: Platform.operatingSystem,
        osMajor: _osMajor(Platform.operatingSystemVersion),
      );
    }
    try {
      _queue = enabled && generation == _generation ? _loadQueue() : [];
      _pruneQueue();
      await _persistQueue();
    } on Object {
      _queue = [];
    }
    _initialized = true;
    try {
      _updatePerformanceMonitoring();
    } on Object {
      _performanceMonitoring = false;
    }
    if (enabled) {
      unawaited(flush().catchError((Object _) {}));
    }
  }

  @override
  Future<void> setEnabled(bool value) {
    final generation = ++_generation;
    // Withdrawal blocks new events and sends immediately, before storage awaits.
    _enabled.value = false;
    _updatePerformanceMonitoring();
    if (!value) {
      _retryTimer?.cancel();
      _queue.clear();
    }
    final operation = _consentTail.then((_) async {
      if (value) {
        // A durable deny record protects a partially completed grant.
        await _writeConsentJournal('off');
        await _writeEnabledPreference(true);
        if (generation != _generation) return;
        await _writeConsentJournal('on');
        if (generation != _generation) return;
        _enabled.value = true;
        _updatePerformanceMonitoring();
        unawaited(flush().catchError((Object _) {}));
      } else {
        var failed = false;
        // Independent stores: attempt both even if either write fails.
        try {
          await _writeConsentJournal('off');
        } on Object {
          failed = true;
        }
        try {
          await _writeEnabledPreference(false);
        } on Object {
          failed = true;
        }
        try {
          await _persistQueue();
        } on Object {
          failed = true;
        }
        if (failed) {
          throw StateError(
            '현재 분석 수집은 중단했습니다. 설정 또는 대기 데이터 저장에 실패했습니다. 앱을 종료하기 전에 다시 끄기를 시도해 주세요.',
          );
        }
      }
    });
    _consentTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _writeConsentJournal(String value) async {
    await _secureStorage.write(key: _consentJournalKey, value: value);
    if (await _secureStorage.read(key: _consentJournalKey) != value) {
      throw StateError('분석 동의 복구 기록 저장 실패');
    }
  }

  Future<void> _writeEnabledPreference(bool value) async {
    final saved = await _preferences.setBool(_enabledKey, value);
    await _preferences.reload();
    if (!saved || _preferences.getBool(_enabledKey) != value) {
      throw StateError('분석 동의 설정 저장 실패');
    }
  }

  @override
  Future<void> deletePendingData() async {
    ++_generation;
    _retryTimer?.cancel();
    _retryTimer = null;
    _queue.clear();
    await _persistQueue();
  }

  @override
  Future<void> record(AnalyticsRecord record) async {
    if (!enabled) return;
    if (!_initialized) await initialize();
    if (!enabled) return;
    final event = _QueuedAnalyticsEvent(
      id: _idGenerator(),
      name: record.name.wireName,
      occurredAt: _now().toUtc(),
      attributes: Map<String, Object>.from(record.attributes),
    );
    if (!isSafeAnalyticsEvent(event.toPayloadJson())) {
      return;
    }
    if (_isRecentDuplicate(event)) return;
    _queue.add(event);
    _pruneQueue();
    try {
      await _persistQueue();
    } on Object {
      return;
    }
    unawaited(flush().catchError((Object _) {}));
  }

  @override
  Future<void> flush() {
    _emitFrameSummary();
    final active = _flushOperation;
    if (active != null) return active;
    final operation = _flushImpl();
    _flushOperation = operation;
    return operation.whenComplete(() {
      if (identical(_flushOperation, operation)) {
        _flushOperation = null;
      }
    });
  }

  Future<void> _flushImpl() async {
    if (!enabled || !_initialized || _queue.isEmpty || _endpoint == null) {
      return;
    }
    if (!_isAllowedEndpoint(_endpoint)) return;
    final now = _now().toUtc();
    final ready = _queue
        .where(
          (event) =>
              event.nextAttemptAt == null || !event.nextAttemptAt!.isAfter(now),
        )
        .take(_batchSize)
        .toList(growable: false);
    if (ready.isEmpty) {
      _scheduleNextRetry();
      return;
    }

    final generation = _generation;
    final environment = _environment ?? await _environmentLoader();
    if (!enabled || generation != _generation) return;
    _environment = environment;
    try {
      final response = await _httpClient
          .post(
            _endpoint,
            headers: const {
              HttpHeaders.contentTypeHeader: 'application/json',
              'X-Daily-Analytics-Schema': '1',
            },
            body: jsonEncode({
              'schemaVersion': _schemaVersion,
              'sessionId': _sessionId,
              'environment': environment.toJson(),
              'events': ready.map((event) => event.toPayloadJson()).toList(),
            }),
          )
          .timeout(_requestTimeout);
      if (!enabled || generation != _generation) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final sentIds = ready.map((event) => event.id).toSet();
        _queue.removeWhere((event) => sentIds.contains(event.id));
      } else if (response.statusCode >= 400 &&
          response.statusCode < 500 &&
          response.statusCode != 408 &&
          response.statusCode != 429) {
        final rejectedIds = ready.map((event) => event.id).toSet();
        _queue.removeWhere((event) => rejectedIds.contains(event.id));
      } else {
        _markFailed(ready);
      }
    } on Object {
      if (!enabled || generation != _generation) return;
      _markFailed(ready);
    }
    await _persistQueue();
    if (_queue.isNotEmpty) {
      _scheduleNextRetry();
    }
  }

  void _markFailed(List<_QueuedAnalyticsEvent> events) {
    final now = _now().toUtc();
    for (final event in events) {
      event.attempts += 1;
      final retryIndex = (event.attempts - 1).clamp(0, _retryDelays.length - 1);
      event.nextAttemptAt = now.add(_retryDelays[retryIndex]);
    }
  }

  void _scheduleNextRetry() {
    _retryTimer?.cancel();
    if (!enabled || _queue.isEmpty || _endpoint == null) return;
    final now = _now().toUtc();
    final next = _queue
        .map((event) => event.nextAttemptAt ?? now)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final delay = next.difference(now);
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(flush().catchError((Object _) {}));
    });
  }

  bool _isRecentDuplicate(_QueuedAnalyticsEvent candidate) {
    if (_queue.isEmpty) return false;
    final previous = _queue.last;
    return previous.name == candidate.name &&
        mapEquals(previous.attributes, candidate.attributes) &&
        candidate.occurredAt.difference(previous.occurredAt).abs() <
            const Duration(seconds: 1);
  }

  List<_QueuedAnalyticsEvent> _loadQueue() {
    final raw = _preferences.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => _QueuedAnalyticsEvent.fromQueueJson(
              Map<String, Object?>.from(item),
            ),
          )
          .whereType<_QueuedAnalyticsEvent>()
          .where((event) => isSafeAnalyticsEvent(event.toPayloadJson()))
          .toList(growable: true);
    } on Object {
      return [];
    }
  }

  void _pruneQueue() {
    final cutoff = _now().toUtc().subtract(_maxEventAge);
    _queue.removeWhere((event) => event.occurredAt.isBefore(cutoff));
    if (_queue.length > _maxQueueLength) {
      _queue = _queue.sublist(_queue.length - _maxQueueLength);
    }
  }

  Future<void> _persistQueue() {
    final generation = _generation;
    final raw = _queue.isEmpty
        ? null
        : jsonEncode(_queue.map((event) => event.toQueueJson()).toList());
    final operation = _queueTail.then((_) async {
      if (generation != _generation) return;
      final saved = raw == null
          ? await _preferences.remove(_queueKey)
          : await _preferences.setString(_queueKey, raw);
      await _preferences.reload();
      if (!saved || _preferences.getString(_queueKey) != raw) {
        throw StateError('전송 대기 분석 데이터를 저장하거나 삭제하지 못했습니다. 다시 시도해 주세요.');
      }
    });
    _queueTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  void _updatePerformanceMonitoring() {
    if (enabled && !_performanceMonitoring) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _performanceMonitoring = true;
    } else if (!enabled && _performanceMonitoring) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
      _performanceMonitoring = false;
    }
  }

  // A window ends after this many frames (about a minute of continuous 60 Hz
  // drawing) or this much wall time, so frame data stays a handful of events.
  static const _frameWindowFrames = 3600;
  static const _frameWindowAge = Duration(minutes: 10);

  static double _displayRefreshRate() {
    final views = PlatformDispatcher.instance.views;
    return views.isEmpty ? 60 : views.first.display.refreshRate;
  }

  static bool _appInForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    // No lifecycle event yet means the first frames of a running app.
    return state == null || state == AppLifecycleState.resumed;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    // Frames drawn while paused, hidden or inactive say nothing about UI jank.
    if (!enabled || timings.isEmpty || !_foregroundProvider()) return;
    final hz = _refreshRateProvider();
    final refreshRate = (hz.isFinite && hz > 0 ? hz : 60.0).round().clamp(
      AnalyticsRecord.minRefreshRateHz,
      AnalyticsRecord.maxRefreshRateHz,
    );
    var window = _frameWindow;
    if (window != null && window.refreshRateHz != refreshRate) {
      _emitFrameSummary();
      window = null;
    }
    window ??= _frameWindow = _FrameWindow(refreshRate, _now());
    // A frame is slow when it needs more than two display periods, i.e. at
    // least one visibly missed refresh at the actual refresh rate.
    final slowAfter = Duration(microseconds: (2000000 / refreshRate).round());
    for (final timing in timings) {
      window.frames++;
      final span = timing.totalSpan;
      if (span > slowAfter) window.slow++;
      if (span.inMilliseconds > window.maxMs) window.maxMs = span.inMilliseconds;
    }
    if (window.frames >= _frameWindowFrames ||
        _now().difference(window.startedAt) >= _frameWindowAge) {
      _emitFrameSummary();
    }
  }

  void _emitFrameSummary() {
    final window = _frameWindow;
    _frameWindow = null;
    if (window == null || window.frames == 0 || !enabled) return;
    unawaited(
      record(
        AnalyticsRecord.frameSummary(
          frameCount: window.frames,
          slowFrameCount: window.slow,
          maxFrameMs: window.maxMs,
          refreshRateHz: window.refreshRateHz,
          buildMode: _buildMode,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (_performanceMonitoring) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }
    _enabled.dispose();
    _consentPromptCompleted.dispose();
    if (_ownsHttpClient) _httpClient.close();
  }

  static Uri? _parseConfiguredEndpoint() {
    const raw = String.fromEnvironment('DAILY_ANALYTICS_ENDPOINT');
    final configured = raw.trim();
    if (configured.isNotEmpty) return Uri.tryParse(configured);
    if (kReleaseMode) return Uri.parse(_productionEndpoint);
    return null;
  }

  static bool _isAllowedEndpoint(Uri endpoint) {
    if (endpoint.scheme == 'https') return true;
    return kDebugMode &&
        endpoint.scheme == 'http' &&
        (endpoint.host == 'localhost' || endpoint.host == '127.0.0.1');
  }

  static Future<AnalyticsEnvironment> _loadEnvironment() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AnalyticsEnvironment(
      appVersion: isTestAppPackage(packageInfo.packageName)
          ? '${packageInfo.version}-test'
          : packageInfo.version,
      platform: Platform.operatingSystem,
      osMajor: _osMajor(Platform.operatingSystemVersion),
    );
  }

  static int _osMajor(String version) {
    final match = RegExp(r'(\d+)').firstMatch(version);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}

class _FrameWindow {
  _FrameWindow(this.refreshRateHz, this.startedAt);

  final int refreshRateHz;
  final DateTime startedAt;
  int frames = 0;
  int slow = 0;
  int maxMs = 0;
}

class _QueuedAnalyticsEvent {
  _QueuedAnalyticsEvent({
    required this.id,
    required this.name,
    required this.occurredAt,
    required this.attributes,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String id;
  final String name;
  final DateTime occurredAt;
  final Map<String, Object> attributes;
  int attempts;
  DateTime? nextAttemptAt;

  Map<String, Object> toPayloadJson() => {
    'eventId': id,
    'name': name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'attributes': attributes,
  };

  Map<String, Object?> toQueueJson() => {
    ...toPayloadJson(),
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
  };

  static _QueuedAnalyticsEvent? fromQueueJson(Map<String, Object?> json) {
    final occurredAt = DateTime.tryParse(json['occurredAt'] as String? ?? '');
    final rawAttributes = json['attributes'];
    if (occurredAt == null || rawAttributes is! Map) return null;
    return _QueuedAnalyticsEvent(
      id: json['eventId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      occurredAt: occurredAt.toUtc(),
      attributes: Map<String, Object>.from(rawAttributes),
      attempts: json['attempts'] as int? ?? 0,
      nextAttemptAt: DateTime.tryParse(
        json['nextAttemptAt'] as String? ?? '',
      )?.toUtc(),
    );
  }
}

bool isSafeAnalyticsBatch(Object? value) {
  if (value is! Map) return false;
  final json = Map<String, Object?>.from(value);
  if (json['schemaVersion'] != 1 || !_isUuid(json['sessionId'])) return false;
  final environment = json['environment'];
  final events = json['events'];
  if (environment is! Map ||
      events is! List ||
      events.isEmpty ||
      events.length > 25) {
    return false;
  }
  final env = Map<String, Object?>.from(environment);
  const platforms = {'ios', 'macos', 'android', 'windows', 'linux'};
  if (!platforms.contains(env['platform']) ||
      env['appVersion'] is! String ||
      !RegExp(
        r'^\d+\.\d+\.\d+(?:\.\d+)?(?:-test)?$',
      ).hasMatch(env['appVersion'] as String) ||
      env['osMajor'] is! int) {
    return false;
  }
  return events.every(isSafeAnalyticsEvent);
}

bool isSafeAnalyticsEvent(Object? value) {
  if (value is! Map) return false;
  final json = Map<String, Object?>.from(value);
  if (!_isUuid(json['eventId']) ||
      DateTime.tryParse(json['occurredAt'] as String? ?? '') == null ||
      json['attributes'] is! Map) {
    return false;
  }
  final name = json['name'] as String?;
  final attributes = Map<String, Object?>.from(json['attributes'] as Map);
  final schema = _analyticsSchemas[name];
  if (schema == null) return false;
  final optional = _analyticsOptionalAttributes[name] ?? const {};
  final keys = attributes.keys.toSet();
  if (!keys.containsAll(schema.keys) ||
      !(schema.keys.toSet()..addAll(optional.keys)).containsAll(keys)) {
    return false;
  }
  for (final entry in attributes.entries) {
    final validator = schema[entry.key] ?? optional[entry.key]!;
    if (!validator(entry.value)) return false;
  }
  if (name == AnalyticsEventName.frameSummary.wireName &&
      (attributes['slowFrameCount'] as int) >
          (attributes['frameCount'] as int)) {
    return false;
  }
  return true;
}

bool _isUuid(Object? value) {
  return value is String &&
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(value);
}

bool _enumValue<T extends Enum>(Object? value, List<T> values) {
  return value is String && values.any((item) => item.name == value);
}

bool _duration(Object? value) =>
    value is int && value >= 0 && value <= AnalyticsRecord.maxDurationMs;
bool _truncatedFlag(Object? value) => value == true;
bool _frameCount(Object? value) => value is int && value >= 0 && value <= 120;
bool _framesInWindow(Object? value) =>
    value is int && value >= 1 && value <= AnalyticsRecord.maxFrameCount;
bool _slowFramesInWindow(Object? value) =>
    value is int && value >= 0 && value <= AnalyticsRecord.maxFrameCount;
bool _refreshRate(Object? value) =>
    value is int &&
    value >= AnalyticsRecord.minRefreshRateHz &&
    value <= AnalyticsRecord.maxRefreshRateHz;

/// Attributes a sender may add on top of the required ones. Older senders omit
/// them, so receivers must accept both shapes.
final _analyticsOptionalAttributes =
    <String, Map<String, bool Function(Object?)>>{
      for (final name in [
        AnalyticsEventName.appLoadCompleted,
        AnalyticsEventName.eventEditorCompleted,
        AnalyticsEventName.eventSaveSucceeded,
        AnalyticsEventName.eventSaveFailed,
        AnalyticsEventName.syncSucceeded,
        AnalyticsEventName.syncFailed,
        AnalyticsEventName.slowInteractionDetected,
        AnalyticsEventName.frameSummary,
      ])
        name.wireName: {'durationTruncated': _truncatedFlag},
    };

final _analyticsSchemas = <String, Map<String, bool Function(Object?)>>{
  AnalyticsEventName.appLoadCompleted.wireName: {'durationMs': _duration},
  AnalyticsEventName.screenView.wireName: {
    'screen': (value) => _enumValue(value, AnalyticsScreen.values),
  },
  AnalyticsEventName.calendarViewChanged.wireName: {
    'view': (value) => _enumValue(value, AnalyticsCalendarView.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
  },
  AnalyticsEventName.eventEditorOpened.wireName: {
    'mode': (value) => _enumValue(value, AnalyticsEditorMode.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
  },
  AnalyticsEventName.eventEditorCompleted.wireName: {
    'mode': (value) => _enumValue(value, AnalyticsEditorMode.values),
    'outcome': (value) => _enumValue(value, AnalyticsOutcome.values),
    'durationMs': _duration,
  },
  AnalyticsEventName.eventSaveSucceeded.wireName: {
    'phase': (value) => _enumValue(value, AnalyticsSavePhase.values),
    'operation': (value) => _enumValue(value, AnalyticsOperation.values),
    'durationMs': _duration,
  },
  AnalyticsEventName.eventSaveFailed.wireName: {
    'phase': (value) => _enumValue(value, AnalyticsSavePhase.values),
    'operation': (value) => _enumValue(value, AnalyticsOperation.values),
    'durationMs': _duration,
    'errorCode': (value) => _enumValue(value, AnalyticsErrorCode.values),
  },
  AnalyticsEventName.featureUsed.wireName: {
    'feature': (value) => _enumValue(value, AnalyticsFeature.values),
    'outcome': (value) => _enumValue(value, AnalyticsOutcome.values),
  },
  AnalyticsEventName.syncStarted.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsSyncOperation.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
  },
  AnalyticsEventName.syncSucceeded.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsSyncOperation.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
    'outcome': (value) => value == AnalyticsOutcome.succeeded.name,
    'durationMs': _duration,
  },
  AnalyticsEventName.syncFailed.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsSyncOperation.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
    'outcome': (value) =>
        value == AnalyticsOutcome.failed.name ||
        value == AnalyticsOutcome.canceled.name,
    'durationMs': _duration,
    'errorCode': (value) => _enumValue(value, AnalyticsErrorCode.values),
  },
  AnalyticsEventName.slowInteractionDetected.wireName: {
    'interaction': (value) => analyticsInteractionValues.contains(value),
    'durationMs': _duration,
    'slowFrameCount': _frameCount,
  },
  AnalyticsEventName.frameSummary.wireName: {
    'frameCount': _framesInWindow,
    'slowFrameCount': _slowFramesInWindow,
    'durationMs': _duration,
    'refreshRateHz': _refreshRate,
    'buildMode': (value) => _enumValue(value, AnalyticsBuildMode.values),
  },
};
