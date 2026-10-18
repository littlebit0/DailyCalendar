import 'package:flutter/foundation.dart';

enum AnalyticsScreen {
  onboarding,
  calendar,
  quickView,
  search,
  settings,
  notificationSettings,
  accountSettings,
  eventDetails,
}

enum AnalyticsCalendarView { quickView, week, month, day }

enum AnalyticsEditorMode { create, edit }

enum AnalyticsSavePhase { database, followUp }

enum AnalyticsOperation { create, update, delete, complete, uncomplete }

enum AnalyticsFeature { search, filter, widget, calendarImport, siri, map }

enum AnalyticsSyncOperation {
  backup,
  restore,
  backupThenRestore,
  detectRemoteChanges,
  backupThenDetectRemoteChanges,
}

enum AnalyticsTrigger { automatic, manual, startup, resume, localChange }

/// Points on the way to a usable calendar, measured from the start of the Dart
/// `main` (not the OS process launch). `app_load_completed` is a different,
/// earlier point: it ends when the data migration finishes.
enum AnalyticsStartupMilestone { firstCalendarFrame, localCalendarReady }

/// Why a started sync ended without a success or failure result.
enum AnalyticsSyncAbandonReason { sessionChanged }

enum AnalyticsBuildMode { debug, profile, release }

enum AnalyticsOutcome { succeeded, failed, canceled }

enum AnalyticsErrorCode {
  authenticationRequired,
  canceled,
  timeout,
  network,
  permission,
  validation,
  storage,
  conflict,
  unavailable,
  unknown,
}

enum AnalyticsEventName {
  appLoadCompleted('app_load_completed'),
  screenView('screen_view'),
  calendarViewChanged('calendar_view_changed'),
  eventEditorOpened('event_editor_opened'),
  eventEditorCompleted('event_editor_completed'),
  eventSaveSucceeded('event_save_succeeded'),
  eventSaveFailed('event_save_failed'),
  featureUsed('feature_used'),
  syncStarted('sync_started'),
  syncSucceeded('sync_succeeded'),
  syncFailed('sync_failed'),
  slowInteractionDetected('slow_interaction_detected'),
  frameSummary('frame_summary'),
  startupMilestone('startup_milestone'),
  syncAbandoned('sync_abandoned');

  const AnalyticsEventName(this.wireName);

  final String wireName;
}

@immutable
class AnalyticsRecord {
  const AnalyticsRecord._(this.name, this.attributes);

  factory AnalyticsRecord.appLoad({required int durationMs}) {
    return AnalyticsRecord._(AnalyticsEventName.appLoadCompleted, {
      ..._durationAttributes(durationMs),
    });
  }

  factory AnalyticsRecord.screenView(AnalyticsScreen screen) {
    return AnalyticsRecord._(AnalyticsEventName.screenView, {
      'screen': screen.name,
    });
  }

  factory AnalyticsRecord.calendarViewChanged(
    AnalyticsCalendarView view, {
    required AnalyticsTrigger trigger,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.calendarViewChanged, {
      'view': view.name,
      'trigger': trigger.name,
    });
  }

  factory AnalyticsRecord.eventEditorOpened(
    AnalyticsEditorMode mode, {
    required AnalyticsTrigger trigger,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.eventEditorOpened, {
      'mode': mode.name,
      'trigger': trigger.name,
    });
  }

  factory AnalyticsRecord.eventEditorCompleted(
    AnalyticsEditorMode mode, {
    required AnalyticsOutcome outcome,
    required int durationMs,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.eventEditorCompleted, {
      'mode': mode.name,
      'outcome': outcome.name,
      ..._durationAttributes(durationMs),
    });
  }

  factory AnalyticsRecord.eventSave(
    AnalyticsOperation operation, {
    required bool succeeded,
    required int durationMs,
    AnalyticsErrorCode? errorCode,
    AnalyticsSavePhase phase = AnalyticsSavePhase.database,
  }) {
    return AnalyticsRecord._(
      succeeded
          ? AnalyticsEventName.eventSaveSucceeded
          : AnalyticsEventName.eventSaveFailed,
      {
        'operation': operation.name,
        'phase': phase.name,
        ..._durationAttributes(durationMs),
        if (!succeeded)
          'errorCode': (errorCode ?? AnalyticsErrorCode.unknown).name,
      },
    );
  }

  factory AnalyticsRecord.featureUsed(
    AnalyticsFeature feature, {
    required AnalyticsOutcome outcome,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.featureUsed, {
      'feature': feature.name,
      'outcome': outcome.name,
    });
  }

  factory AnalyticsRecord.sync(
    AnalyticsSyncOperation operation, {
    required AnalyticsTrigger trigger,
    required AnalyticsOutcome outcome,
    required int durationMs,
    AnalyticsErrorCode? errorCode,
    int attempt = 1,
  }) {
    final name = switch (outcome) {
      AnalyticsOutcome.succeeded => AnalyticsEventName.syncSucceeded,
      AnalyticsOutcome.failed ||
      AnalyticsOutcome.canceled => AnalyticsEventName.syncFailed,
    };
    return AnalyticsRecord._(name, {
      'operation': operation.name,
      'trigger': trigger.name,
      'outcome': outcome.name,
      ..._durationAttributes(durationMs),
      if (outcome != AnalyticsOutcome.succeeded)
        'errorCode': (errorCode ?? AnalyticsErrorCode.unknown).name,
      ..._attemptAttributes(attempt),
    });
  }

  /// A started sync that ended because the account or session changed under
  /// it. It is neither a success nor a failure of the sync itself, so it must
  /// not enter a success-rate denominator as a failure (#152).
  factory AnalyticsRecord.syncAbandoned(
    AnalyticsSyncOperation operation, {
    required AnalyticsTrigger trigger,
    required AnalyticsSyncAbandonReason reason,
    required int durationMs,
    int attempt = 1,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.syncAbandoned, {
      'operation': operation.name,
      'trigger': trigger.name,
      'reason': reason.name,
      ..._durationAttributes(durationMs),
      ..._attemptAttributes(attempt),
    });
  }

  factory AnalyticsRecord.syncStarted(
    AnalyticsSyncOperation operation, {
    required AnalyticsTrigger trigger,
    int attempt = 1,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.syncStarted, {
      'operation': operation.name,
      'trigger': trigger.name,
      ..._attemptAttributes(attempt),
    });
  }

  factory AnalyticsRecord.slowInteraction({
    required String interaction,
    required int durationMs,
    int slowFrameCount = 0,
  }) {
    if (!analyticsInteractionValues.contains(interaction)) {
      throw ArgumentError.value(interaction, 'interaction');
    }
    return AnalyticsRecord._(AnalyticsEventName.slowInteractionDetected, {
      'interaction': interaction,
      ..._durationAttributes(durationMs),
      'slowFrameCount': slowFrameCount.clamp(0, 120),
    });
  }

  factory AnalyticsRecord.startupMilestone(
    AnalyticsStartupMilestone milestone, {
    required int durationMs,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.startupMilestone, {
      'milestone': milestone.name,
      ..._durationAttributes(durationMs),
    });
  }

  /// Frame health over a window: [slowFrameCount] of [frameCount] frames took
  /// longer than twice the display's frame budget at [refreshRateHz], so the
  /// ratio is meaningful on 60, 120 and 144 Hz screens alike (#150).
  factory AnalyticsRecord.frameSummary({
    required int frameCount,
    required int slowFrameCount,
    required int maxFrameMs,
    required int refreshRateHz,
    required AnalyticsBuildMode buildMode,
  }) {
    return AnalyticsRecord._(AnalyticsEventName.frameSummary, {
      'frameCount': frameCount.clamp(1, maxFrameCount),
      'slowFrameCount': slowFrameCount.clamp(0, frameCount.clamp(1, maxFrameCount)),
      ..._durationAttributes(maxFrameMs),
      'refreshRateHz': refreshRateHz.clamp(minRefreshRateHz, maxRefreshRateHz),
      'buildMode': buildMode.name,
    });
  }

  static const maxFrameCount = 100000;
  static const minRefreshRateHz = 24;
  static const maxRefreshRateHz = 240;

  final AnalyticsEventName name;
  final Map<String, Object> attributes;

  /// Longest duration sent as-is. Anything above is reported as this value
  /// together with `durationTruncated`, so exactly 120 s stays distinguishable
  /// from a longer run. Records written before this flag existed carry no
  /// `durationTruncated`, so a stored 120000 cannot be read as exact.
  static const maxDurationMs = 120000;

  /// Automatic retries are numbered from 2; the first attempt carries no
  /// `attempt`, which keeps the pre-existing record shape for it.
  static const maxSyncAttempt = 6;

  static Map<String, Object> _attemptAttributes(int attempt) => {
    if (attempt > 1) 'attempt': attempt.clamp(2, maxSyncAttempt),
  };

  static Map<String, Object> _durationAttributes(int value) => {
    'durationMs': value.clamp(0, maxDurationMs),
    if (value > maxDurationMs) 'durationTruncated': true,
  };
}

const analyticsInteractionValues = <String>{
  'app_start',
  'calendar_transition',
  'event_save',
  'search_open',
  'sync',
  'frame_batch',
};

abstract interface class ProductAnalytics {
  ValueListenable<bool> get enabledListenable;
  ValueListenable<bool> get consentPromptCompletedListenable;
  bool get enabled;
  bool get consentPromptCompleted;
  int get pendingEventCount;

  Future<void> initialize();
  Future<void> completeConsentPrompt({required bool enabled});
  Future<void> setEnabled(bool enabled);
  Future<void> deletePendingData();
  Future<void> record(AnalyticsRecord record);
  Future<void> flush();
  void dispose();
}

class NoopProductAnalytics implements ProductAnalytics {
  const NoopProductAnalytics();

  static final ValueNotifier<bool> _disabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _consentCompleted = ValueNotifier<bool>(
    true,
  );

  @override
  bool get consentPromptCompleted => true;

  @override
  ValueListenable<bool> get consentPromptCompletedListenable =>
      _consentCompleted;

  @override
  bool get enabled => false;

  @override
  ValueListenable<bool> get enabledListenable => _disabled;

  @override
  int get pendingEventCount => 0;

  @override
  Future<void> completeConsentPrompt({required bool enabled}) async {}

  @override
  Future<void> deletePendingData() async {}

  @override
  void dispose() {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> record(AnalyticsRecord record) async {}

  @override
  Future<void> setEnabled(bool enabled) async {}
}

AnalyticsErrorCode categorizeAnalyticsError(Object error) {
  final text = '${error.runtimeType} $error'.toLowerCase();
  if (text.contains('cancel')) return AnalyticsErrorCode.canceled;
  if (text.contains('timeout')) return AnalyticsErrorCode.timeout;
  if (text.contains('auth') || text.contains('sign')) {
    return AnalyticsErrorCode.authenticationRequired;
  }
  if (text.contains('socket') ||
      text.contains('network') ||
      text.contains('clientexception')) {
    return AnalyticsErrorCode.network;
  }
  if (text.contains('permission') || text.contains('denied')) {
    return AnalyticsErrorCode.permission;
  }
  if (text.contains('validation') || text.contains('invalid')) {
    return AnalyticsErrorCode.validation;
  }
  if (text.contains('sqlite') || text.contains('storage')) {
    return AnalyticsErrorCode.storage;
  }
  if (text.contains('conflict')) return AnalyticsErrorCode.conflict;
  if (text.contains('unavailable') || text.contains('unsupported')) {
    return AnalyticsErrorCode.unavailable;
  }
  return AnalyticsErrorCode.unknown;
}
