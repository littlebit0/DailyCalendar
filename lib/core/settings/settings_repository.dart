import 'dart:convert';

import '../../features/timetable/data/timetable_store.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../auth/apple_account.dart';
import '../auth/daily_account.dart';
import '../auth/google_account.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../weather/weather_store.dart';
import '../widgets/lock_screen_wallpaper_service.dart';
import 'app_settings.dart';
import '../../features/onboarding/feature_announcements.dart';
import '../academic/academic_store.dart';
import '../academic/academic_profile.dart';
import '../../features/events/domain/frequent_places.dart';
import '../sync/settings_sync_document.dart';
import '../sync/sync_version.dart';

class SettingsRepository {
  SettingsRepository({
    required SharedPreferences preferences,
    FlutterSecureStorage? secureStorage,
    DateTime Function()? now,
  }) : _preferences = preferences,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _now = now ?? DateTime.now;

  static const _notificationCleanupKey = 'notificationCleanup.v1';
  static const _appliedWidgetActionsKey = 'widgetAppliedActionTokens.v1';
  static const _appliedWidgetActionsLimit = 200;

  /// Widget action tokens already applied to the database. A token that is
  /// delivered again (its acknowledgement could not be saved) must not
  /// overwrite a newer choice the user made in the app.
  Set<String> appliedWidgetActionTokens() =>
      (_preferences.getStringList(_appliedWidgetActionsKey) ?? const <String>[])
          .toSet();

  Future<void> rememberAppliedWidgetActionTokens(
    Iterable<String> tokens,
  ) async {
    final merged = <String>[
      ...(_preferences.getStringList(_appliedWidgetActionsKey) ??
          const <String>[]),
      ...tokens,
    ];
    final trimmed = merged.length > _appliedWidgetActionsLimit
        ? merged.sublist(merged.length - _appliedWidgetActionsLimit)
        : merged;
    await _preferences.setStringList(_appliedWidgetActionsKey, trimmed);
  }

  String? get notificationCleanupJournal =>
      _preferences.getString(_notificationCleanupKey);

  Future<void> saveNotificationCleanupJournal(String? value) async {
    final success = value == null
        ? await _preferences.remove(_notificationCleanupKey)
        : await _preferences.setString(_notificationCleanupKey, value);
    await _preferences.reload();
    if (!success || _preferences.getString(_notificationCleanupKey) != value) {
      throw StateError('알림 정리 기록을 저장하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  static const _notificationIdsKey = 'notificationIds.v2';
  static final _notificationIdTails = Expando<Future<void>>();

  Set<int> retiredLegacyNotificationIds({required bool delivered}) =>
      (_preferences.getStringList('notificationLegacyRetired.v2.$delivered') ??
              const [])
          .map(int.parse)
          .toSet();

  Future<void> retireLegacyNotificationIds(
    Set<int> ids, {
    required bool delivered,
  }) {
    final prior = _notificationIdTails[_preferences] ?? Future<void>.value();
    final operation = prior.then((_) async {
      final all = {
        ...retiredLegacyNotificationIds(delivered: delivered),
        ...ids,
      };
      final key = 'notificationLegacyRetired.v2.$delivered';
      final encoded = all.map((id) => '$id').toList()..sort();
      final success = await _preferences.setStringList(key, encoded);
      await _preferences.reload();
      if (!success ||
          jsonEncode(_preferences.getStringList(key)) != jsonEncode(encoded)) {
        throw StateError('기존 알림 전환 기록을 저장하지 못했습니다.');
      }
    });
    _notificationIdTails[_preferences] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Map<String, int> _notificationIds() {
    final raw = _preferences.getString(_notificationIdsKey);
    final values = raw == null
        ? <String, int>{}
        : Map<String, int>.from(jsonDecode(raw) as Map);
    if (values.values.any((id) => id >= 0 || id < -2147483647) ||
        values.values.toSet().length != values.length) {
      throw StateError('알림 식별 기록을 확인할 수 없습니다.');
    }
    return values;
  }

  int? existingNotificationId(String key) => _notificationIds()[key];

  /// Allocated notification ids whose logical key starts with [prefix].
  Map<String, int> notificationIdsWithPrefix(String prefix) => {
    for (final entry in _notificationIds().entries)
      if (entry.key.startsWith(prefix)) entry.key: entry.value,
  };

  Future<int> notificationId(String key) {
    final prior = _notificationIdTails[_preferences] ?? Future<void>.value();
    final operation = prior.then((_) async {
      final ids = _notificationIds();
      if (ids.containsKey(key)) return ids[key]!;
      // Old hashes are nonnegative. The negative range isolates migration and
      // all new logical keys share this one durable allocation table.
      final next = ids.values.fold<int>(0, (a, b) => a < b ? a : b) - 1;
      if (next < -2147483647) throw StateError('알림 식별 공간이 부족합니다.');
      ids[key] = next;
      final encoded = jsonEncode(ids);
      final success = await _preferences.setString(
        _notificationIdsKey,
        encoded,
      );
      await _preferences.reload();
      if (!success || _preferences.getString(_notificationIdsKey) != encoded) {
        throw StateError('알림 식별 기록을 저장하지 못했습니다.');
      }
      return next;
    });
    _notificationIdTails[_preferences] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  static const _eventFollowUpKey = 'eventFollowUps.v1';
  Future<void> _eventFollowUpTail = Future<void>.value();

  Map<String, dynamic> pendingEventFollowUps() {
    final raw = _preferences.getString(_eventFollowUpKey);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _changeEventFollowUps(
    void Function(Map<String, dynamic>) change,
  ) {
    final operation = _eventFollowUpTail.then((_) async {
      final entries = pendingEventFollowUps();
      change(entries);
      final encoded = jsonEncode(entries);
      final success = await _preferences.setString(_eventFollowUpKey, encoded);
      await _preferences.reload();
      if (!success || _preferences.getString(_eventFollowUpKey) != encoded) {
        throw StateError('일정 후속 처리 기록을 저장하지 못했습니다.');
      }
    });
    _eventFollowUpTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> stageEventFollowUp(
    String id,
    String token,
    List<int> reminders,
  ) => _changeEventFollowUps((entries) {
    final old = entries[id];
    final previous = old is Map
        ? (old['reminders'] as List? ?? const [])
        : const [];
    entries[id] = {
      'token': token,
      'stages': ['notification', 'alarm', 'sync', 'briefing', 'widgets'],
      'reminders': <int>{...previous.whereType<int>(), ...reminders}.toList(),
    };
  });

  Future<void> completeEventFollowUpStage(
    String id,
    String token,
    String stage,
  ) => _changeEventFollowUps((entries) {
    if (entries[id] is Map && entries[id]['token'] == token) {
      final stages = List<String>.from(entries[id]['stages'] as List);
      stages.remove(stage);
      entries[id]['stages'] = stages;
    }
  });

  Future<void> acknowledgeEventFollowUp(String id, String token) =>
      _changeEventFollowUps((entries) {
        if (entries[id] is Map && entries[id]['token'] == token) {
          entries.remove(id);
        }
      });

  final SharedPreferences _preferences;
  late final announcements = FeatureAnnouncementStore(_preferences);
  late final frequentPlaces = FrequentPlaces(_preferences);
  late final weatherStore = WeatherStore(_preferences);
  late final academicStore = AcademicStore(_preferences);
  late final timetableStore = TimetableStore(_preferences, now: _now);
  final FlutterSecureStorage _secureStorage;
  final DateTime Function() _now;
  Future<void> _settingsMutationTail = Future<void>.value();
  var _settingsMutationGeneration = 0;

  int get settingsMutationGeneration => _settingsMutationGeneration;

  String _lmsSuccessKey(String ownerId, String schoolId, String lmsUserId) {
    final identity = jsonEncode([
      ownerId.trim().toLowerCase(),
      schoolId,
      lmsUserId,
    ]);
    return 'daily.lms.lastSuccess.v1.${sha256.convert(utf8.encode(identity))}';
  }

  /// Local check time only; credentials and Drive-synced events do not contain it.
  DateTime? lmsLastSuccess({
    required String ownerId,
    required String schoolId,
    required String lmsUserId,
  }) {
    final owner = ownerId.trim().toLowerCase();
    if (owner.isEmpty ||
        schoolId.isEmpty ||
        lmsUserId.isEmpty ||
        dailyAccount()?.googleAccount?.email.trim().toLowerCase() != owner) {
      return null;
    }
    final raw = _preferences.get(_lmsSuccessKey(owner, schoolId, lmsUserId));
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  Future<void> saveLmsLastSuccess(
    DateTime checkedAt, {
    required String ownerId,
    required String schoolId,
    required String lmsUserId,
    void Function()? validateSession,
  }) {
    final owner = ownerId.trim().toLowerCase();
    final generation = _settingsMutationGeneration;
    void validate() {
      validateSession?.call();
      if (owner.isEmpty ||
          schoolId.isEmpty ||
          lmsUserId.isEmpty ||
          generation != _settingsMutationGeneration ||
          dailyAccount()?.googleAccount?.email.trim().toLowerCase() != owner) {
        throw StateError('LMS check belongs to a different account');
      }
    }

    return _enqueueSettingsMutation(() async {
      validate();
      final key = _lmsSuccessKey(owner, schoolId, lmsUserId);
      final previous = _preferences.getString(key);
      try {
        if (!await _preferences.setString(
          key,
          checkedAt.toUtc().toIso8601String(),
        )) {
          throw StateError('LMS check time write failed');
        }
        validate();
      } catch (_) {
        try {
          if (previous == null) {
            await _preferences.remove(key);
          } else {
            await _preferences.setString(key, previous);
          }
        } catch (_) {
          // Preserve the original failure after best-effort rollback.
        }
        rethrow;
      }
    });
  }

  String _lmsLearningCheckedKey(
    String ownerId,
    String schoolId,
    String lmsUserId,
  ) {
    final identity = jsonEncode([
      ownerId.trim().toLowerCase(),
      schoolId,
      lmsUserId,
    ]);
    return 'daily.lms.learningChecked.v1.${sha256.convert(utf8.encode(identity))}';
  }

  /// When each lecture's learning values were last confirmed by the school
  /// (event id -> UTC time), kept on this device only. A lecture the school did
  /// not report on a later sync keeps its older time, so the app can say which
  /// values may be stale instead of stamping them with the whole sync's time.
  Map<String, DateTime> lmsLearningCheckedAt({
    required String ownerId,
    required String schoolId,
    required String lmsUserId,
  }) {
    final raw = _preferences.get(
      _lmsLearningCheckedKey(ownerId, schoolId, lmsUserId),
    );
    if (raw is! String) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: DateTime.fromMillisecondsSinceEpoch(
              entry.value as int,
              isUtc: true,
            ),
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> saveLmsLearningCheckedAt(
    Map<String, DateTime> checkedAt, {
    required String ownerId,
    required String schoolId,
    required String lmsUserId,
  }) async {
    final key = _lmsLearningCheckedKey(ownerId, schoolId, lmsUserId);
    if (checkedAt.isEmpty) {
      await _preferences.remove(key);
      return;
    }
    await _preferences.setString(
      key,
      jsonEncode({
        for (final entry in checkedAt.entries)
          entry.key: entry.value.toUtc().millisecondsSinceEpoch,
      }),
    );
  }

  static const _defaultReminderKey = 'defaultReminderMinutes';
  static const _defaultReminderListKey = 'defaultReminderMinutesList';
  static const _allDayReminderHourKey = 'allDayReminderHour';
  static const _allDayReminderMinuteKey = 'allDayReminderMinute';
  static const _briefingHourKey = 'morningBriefingHour';
  static const _briefingMinuteKey = 'morningBriefingMinute';
  static const _briefingEnabledKey = 'morningBriefingEnabled';
  static const _weekStartsOnMondayKey = 'weekStartsOnMonday';
  static const _showLunarDatesKey = 'showLunarDates';
  static const _showAdjacentMonthDatesKey = 'showAdjacentMonthDates';
  static const _onboardingCompletedKey = 'onboardingCompleted';
  static const _aiEnabledKey = 'aiEnabled';
  static const _aiComplexOnlyKey = 'aiOnlyForComplexInput';
  static const _blockSensitiveAiKey = 'blockSensitiveAi';
  static const _categoriesKey = 'eventCategories';
  static const _dDayReminderOffsetsKey = 'dDayReminderOffsets';
  static const _appTextSizeKey = 'appTextSize';
  static const _legacyCalendarEventTextSizeKey = 'calendarEventTextSize';
  static const _legacyCalendarDensityKey = 'calendarDensity';
  static const _appStartViewKey = 'appStartView';
  static const _defaultCalendarViewKey = 'defaultCalendarView';
  static const _weekDayLayoutModeKey = 'weekDayLayoutMode';
  static const _calendarEventTitleAlignmentKey = 'calendarEventTitleAlignment';
  static const _calendarEventSortPriorityKey = 'calendarEventSortPriority';
  static const _calendarManualEventOrdersKey = 'calendarManualEventOrders';
  static const _hiddenCategoryIdsKey = 'hiddenCategoryIds';
  static const _calendarShowHolidaysKey = 'calendarShowHolidays';
  static const _calendarHolidayBackgroundEnabledKey =
      'calendarHolidayBackgroundEnabled';
  static const _calendarDdayOnlyKey = 'calendarDdayOnly';
  static const _appLockConfigurationKey = 'appLockConfiguration.v1';
  static const _appLockEnabledKey = 'appLockEnabled';
  static const _appLockBiometricsEnabledKey = 'appLockBiometricsEnabled';
  static const _appLockMethodKey = 'appLockMethod';
  static const _use24HourTimeKey = 'use24HourTime';
  static const _themeModeKey = 'themeMode';
  static const _monthNavigationModeKey = 'monthNavigationMode';
  static const _languageKey = 'language';
  static const _academicProfileKey = 'academicProfile.v1';
  static const _academicProfileOwnerKey = 'academicProfile.owner.v1';
  static const _academicProfileAccountsKey = 'academicProfile.accounts.v1';
  static const _settingsSyncPendingKey = 'settingsSyncPending';
  static const _settingsSyncRevisionKey = 'settingsSyncRevision';
  static const _settingsSyncDocumentKey = 'settingsSyncDocument.v1';
  static const _driveChangeTokenKey = 'driveChangePageToken';
  static const _driveChangeAccountKey = 'driveChangeAccount';
  static const _deviceIdKey = 'deviceId';
  static const _appleUserIdentifierKey = 'appleUserIdentifier';
  static const _appleEmailKey = 'appleEmail';
  static const _appleGivenNameKey = 'appleGivenName';
  static const _appleFamilyNameKey = 'appleFamilyName';
  static const _dailyAccountKey = 'dailyAccount';
  static const _geminiKey = 'geminiApiKey';
  static const _appLockPinHashKey = 'appLockPinHash';
  static const _appLockPinLengthKey = 'appLockPinLength';

  AppSettings load() {
    final rawProfile = _preferences.getString(_academicProfileKey);
    final lock = _loadLockConfiguration();
    return AppSettings(
      academicProfile: rawProfile != null
          ? AcademicProfile.fromJson(
              Map<String, Object?>.from(jsonDecode(rawProfile) as Map),
            )
          : null,
      defaultReminderMinutesList: _loadDefaultReminderMinutes(),
      allDayReminderHour: _preferences.getInt(_allDayReminderHourKey) ?? 9,
      allDayReminderMinute: _preferences.getInt(_allDayReminderMinuteKey) ?? 0,
      morningBriefingHour: _preferences.getInt(_briefingHourKey) ?? 8,
      morningBriefingMinute: _preferences.getInt(_briefingMinuteKey) ?? 0,
      morningBriefingEnabled: _preferences.getBool(_briefingEnabledKey) ?? true,
      weekStartsOnMonday: _preferences.getBool(_weekStartsOnMondayKey) ?? false,
      showLunarDates: _preferences.getBool(_showLunarDatesKey) ?? true,
      showAdjacentMonthDates:
          _preferences.getBool(_showAdjacentMonthDatesKey) ?? true,
      onboardingCompleted:
          _preferences.getBool(_onboardingCompletedKey) ?? false,
      aiEnabled: _preferences.getBool(_aiEnabledKey) ?? false,
      aiOnlyForComplexInput: _preferences.getBool(_aiComplexOnlyKey) ?? true,
      blockSensitiveAi: _preferences.getBool(_blockSensitiveAiKey) ?? true,
      categories: _loadCategories(),
      dDayReminderOffsets: _loadDdayOffsets(),
      appTextSize: AppTextSize.fromName(
        _preferences.getString(_appTextSizeKey) ??
            _preferences.getString(_legacyCalendarEventTextSizeKey),
      ),
      appStartView: AppStartView.fromName(
        _preferences.getString(_appStartViewKey),
      ),
      defaultCalendarView: CalendarViewMode.fromName(
        _preferences.getString(_defaultCalendarViewKey),
      ),
      weekDayLayoutMode: WeekDayLayoutMode.fromName(
        _preferences.getString(_weekDayLayoutModeKey),
      ),
      calendarEventTitleAlignment: CalendarEventTitleAlignment.fromName(
        _preferences.getString(_calendarEventTitleAlignmentKey),
      ),
      calendarEventSortPriority: CalendarEventSortPriority.fromName(
        _preferences.getString(_calendarEventSortPriorityKey),
      ),
      calendarManualEventOrders: _loadCalendarManualEventOrders(),
      hiddenCategoryIds: _loadStringList(_hiddenCategoryIdsKey),
      calendarShowHolidays:
          _preferences.getBool(_calendarShowHolidaysKey) ?? true,
      calendarHolidayBackgroundEnabled:
          _preferences.getBool(_calendarHolidayBackgroundEnabledKey) ?? true,
      calendarDdayOnly: _preferences.getBool(_calendarDdayOnlyKey) ?? false,
      appLockEnabled: lock.enabled,
      appLockBiometricsEnabled: lock.biometrics,
      appLockMethod: lock.method,
      use24HourTime: _preferences.getBool(_use24HourTimeKey) ?? true,
      themeMode: AppThemeMode.fromName(_preferences.getString(_themeModeKey)),
      monthNavigationMode: MonthNavigationMode.fromName(
        _preferences.getString(_monthNavigationModeKey),
      ),
      language: AppLanguage.fromName(_preferences.getString(_languageKey)),
    );
  }

  ({bool enabled, bool biometrics, AppLockMethod method})
  _loadLockConfiguration() {
    final encoded = _preferences.getString(_appLockConfigurationKey);
    if (encoded != null) {
      try {
        final value = jsonDecode(encoded) as Map<String, dynamic>;
        final method = AppLockMethod.values.byName(value['method'] as String);
        return (
          enabled: value['enabled'] as bool,
          biometrics: value['biometrics'] as bool,
          method: method,
        );
      } on Object {
        // Corrupt local lock configuration must not silently disable protection.
        return (enabled: true, biometrics: false, method: AppLockMethod.appPin);
      }
    }
    final biometrics =
        _preferences.getBool(_appLockBiometricsEnabledKey) ?? false;
    return (
      enabled: _preferences.getBool(_appLockEnabledKey) ?? false,
      biometrics: biometrics,
      method: AppLockMethod.fromName(
        _preferences.getString(_appLockMethodKey),
        legacyBiometricsEnabled: biometrics,
      ),
    );
  }

  Future<void> save(
    AppSettings settings, {
    bool markSyncPending = true,
    AppSettings? changedFrom,
  }) {
    return _enqueueSettingsMutation(
      () => _saveSettings(
        settings,
        markSyncPending: markSyncPending,
        changedFrom: changedFrom,
      ),
    );
  }

  /// Adds [category] to the latest list inside the settings queue unless its
  /// id already exists, so a concurrent category edit is never overwritten by
  /// an older snapshot. Completes with the stored category.
  Future<EventCategory> ensureCategory(EventCategory category) async {
    EventCategory? stored;
    await _enqueueSettingsMutation(() async {
      final latest = load();
      stored = latest.categories.where((c) => c.id == category.id).firstOrNull;
      if (stored != null) return;
      await _saveSettings(
        latest.copyWith(categories: [...latest.categories, category]),
        markSyncPending: true,
        changedFrom: latest,
      );
      stored = category;
    });
    return stored!;
  }

  /// Replaces one category in the latest list inside the settings queue, so
  /// concurrent edits to other categories are kept. Completes with the
  /// replaced and new values, or null when [id] is missing.
  Future<({EventCategory previous, EventCategory updated})?> updateCategory(
    String id,
    EventCategory Function(EventCategory current) update, {
    bool Function()? isCurrent,
  }) async {
    ({EventCategory previous, EventCategory updated})? change;
    await _enqueueSettingsMutation(() async {
      // Checked in the queue, after any account switch queued before it.
      if (isCurrent != null && !isCurrent()) {
        throw StateError('Category update cancelled');
      }
      final latest = load();
      final current = latest.categories.where((c) => c.id == id).firstOrNull;
      if (current == null) return;
      final updated = update(current);
      await _saveSettings(
        latest.copyWith(
          categories: [
            for (final c in latest.categories) c.id == id ? updated : c,
          ],
        ),
        markSyncPending: true,
        changedFrom: latest,
      );
      change = (previous: current, updated: updated);
    });
    return change;
  }

  /// Shows or hides one category in the latest hidden list inside the
  /// settings queue, keeping concurrent changes to other categories.
  Future<void> setCategoryHidden(String id, bool hidden) =>
      _enqueueSettingsMutation(() async {
        final latest = load();
        final ids = latest.hiddenCategoryIds.toSet();
        if (!(hidden ? ids.add(id) : ids.remove(id))) return;
        await _saveSettings(
          latest.copyWith(hiddenCategoryIds: ids.toList()),
          markSyncPending: true,
          changedFrom: latest,
        );
      });

  /// A stale editor must not write academic details into a different account.
  Future<void> saveAcademicProfile(
    AcademicProfile profile, {
    required String expectedGoogleEmail,
  }) {
    final generation = _settingsMutationGeneration;
    void validate() {
      if (generation != _settingsMutationGeneration ||
          dailyAccount()?.googleAccount?.email.toLowerCase() !=
              expectedGoogleEmail.toLowerCase()) {
        throw StateError('Academic profile account changed');
      }
    }

    return _enqueueSettingsMutation(
      () => _saveAcademicProfile(profile, validate: validate),
    );
  }

  /// Update only LMS connection fields after queued school/category edits have
  /// committed. A finished login must not replace a newer profile snapshot.
  Future<bool> updateLmsConnection({
    required String expectedGoogleEmail,
    required String expectedSchoolId,
    String? userId,
    String? expectedLmsUserId,
    bool allowPrincipalChange = false,
    bool allowReenable = false,
    required bool enabled,
  }) {
    final generation = _settingsMutationGeneration;
    final owner = expectedGoogleEmail.trim().toLowerCase();
    void validate() {
      if (owner.isEmpty ||
          generation != _settingsMutationGeneration ||
          dailyAccount()?.googleAccount?.email.trim().toLowerCase() != owner) {
        throw StateError('LMS connection account changed');
      }
    }

    var changed = false;
    return _enqueueSettingsMutation(() async {
      validate();
      final current = load().academicProfile;
      if (current == null || current.timetableUniversity != expectedSchoolId) {
        return;
      }
      // A restored/automatic session must not overwrite a principal selected
      // by another device while this mutation waited in the settings queue.
      // Only a completed, explicit school login may replace that selection.
      if (!allowPrincipalChange &&
          (current.lmsUserId != expectedLmsUserId ||
              (enabled &&
                  current.lmsIntegrationEnabled == false &&
                  !allowReenable))) {
        return;
      }
      if (userId != null && userId.trim().isEmpty) {
        throw ArgumentError.value(userId, 'userId', 'Must not be empty');
      }
      final next = current.withLmsConnection(userId: userId, enabled: enabled);
      if (next == current) return;
      await _saveAcademicProfile(next, validate: validate);
      changed = true;
    }).then((_) => changed);
  }

  /// Caller already owns the settings mutation queue. Keep profile and its
  /// Drive revision together without nesting another queued operation.
  Future<void> _saveAcademicProfile(
    AcademicProfile profile, {
    required void Function() validate,
  }) async {
    validate();
    final keys = [
      _academicProfileKey,
      _settingsSyncDocumentKey,
      _settingsSyncPendingKey,
      _settingsSyncRevisionKey,
    ];
    final before = {for (final key in keys) key: _preferences.get(key)};
    try {
      final current = load();
      await _saveSettings(
        current.copyWith(academicProfile: profile),
        markSyncPending: true,
        changedFrom: current,
      );
      validate();
      if (load().academicProfile != profile ||
          !hasPendingSettingsSync && current.academicProfile != profile) {
        throw StateError('Academic profile persistence incomplete');
      }
    } catch (_) {
      for (final entry in before.entries) {
        try {
          switch (entry.value) {
            case null:
              await _preferences.remove(entry.key);
            case String value:
              await _preferences.setString(entry.key, value);
            case int value:
              await _preferences.setInt(entry.key, value);
            case bool value:
              await _preferences.setBool(entry.key, value);
          }
        } catch (_) {
          /* Preserve the original failure after best-effort rollback. */
        }
      }
      rethrow;
    }
  }

  Future<void> _saveSettings(
    AppSettings settings, {
    required bool markSyncPending,
    required AppSettings? changedFrom,
  }) async {
    final previous = load();
    final changedAt = _now();
    final previousSyncDocument = settingsSyncDocument();
    final baseline = changedFrom ?? previous;
    final previousReminderListJson = jsonEncode(
      previous.defaultReminderMinutesList,
    );
    final baselineReminderListJson = jsonEncode(
      baseline.defaultReminderMinutesList,
    );
    final reminderListJson = jsonEncode(settings.defaultReminderMinutesList);
    final shouldMigrateLegacyReminder =
        !_preferences.containsKey(_defaultReminderListKey) &&
        _preferences.containsKey(_defaultReminderKey);
    if ((baselineReminderListJson != reminderListJson &&
            previousReminderListJson != reminderListJson) ||
        shouldMigrateLegacyReminder) {
      await _preferences.setString(_defaultReminderListKey, reminderListJson);
      if (settings.defaultReminderMinutesList.isEmpty) {
        if (_preferences.containsKey(_defaultReminderKey)) {
          await _preferences.remove(_defaultReminderKey);
        }
      } else if (_preferences.getInt(_defaultReminderKey) !=
          settings.defaultReminderMinutesList.first) {
        await _preferences.setInt(
          _defaultReminderKey,
          settings.defaultReminderMinutesList.first,
        );
      }
    }
    if (baseline.allDayReminderHour != settings.allDayReminderHour &&
        previous.allDayReminderHour != settings.allDayReminderHour) {
      await _preferences.setInt(
        _allDayReminderHourKey,
        settings.allDayReminderHour,
      );
    }
    if (baseline.allDayReminderMinute != settings.allDayReminderMinute &&
        previous.allDayReminderMinute != settings.allDayReminderMinute) {
      await _preferences.setInt(
        _allDayReminderMinuteKey,
        settings.allDayReminderMinute,
      );
    }
    if (baseline.morningBriefingHour != settings.morningBriefingHour &&
        previous.morningBriefingHour != settings.morningBriefingHour) {
      await _preferences.setInt(_briefingHourKey, settings.morningBriefingHour);
    }
    if (baseline.morningBriefingMinute != settings.morningBriefingMinute &&
        previous.morningBriefingMinute != settings.morningBriefingMinute) {
      await _preferences.setInt(
        _briefingMinuteKey,
        settings.morningBriefingMinute,
      );
    }
    if (baseline.morningBriefingEnabled != settings.morningBriefingEnabled &&
        previous.morningBriefingEnabled != settings.morningBriefingEnabled) {
      await _preferences.setBool(
        _briefingEnabledKey,
        settings.morningBriefingEnabled,
      );
    }
    if (baseline.weekStartsOnMonday != settings.weekStartsOnMonday &&
        previous.weekStartsOnMonday != settings.weekStartsOnMonday) {
      await _preferences.setBool(
        _weekStartsOnMondayKey,
        settings.weekStartsOnMonday,
      );
    }
    if (baseline.showLunarDates != settings.showLunarDates &&
        previous.showLunarDates != settings.showLunarDates) {
      await _preferences.setBool(_showLunarDatesKey, settings.showLunarDates);
    }
    if (baseline.showAdjacentMonthDates != settings.showAdjacentMonthDates &&
        previous.showAdjacentMonthDates != settings.showAdjacentMonthDates) {
      await _preferences.setBool(
        _showAdjacentMonthDatesKey,
        settings.showAdjacentMonthDates,
      );
    }
    if (baseline.onboardingCompleted != settings.onboardingCompleted &&
        previous.onboardingCompleted != settings.onboardingCompleted) {
      await _preferences.setBool(
        _onboardingCompletedKey,
        settings.onboardingCompleted,
      );
    }
    if (baseline.aiEnabled != settings.aiEnabled &&
        previous.aiEnabled != settings.aiEnabled) {
      await _preferences.setBool(_aiEnabledKey, settings.aiEnabled);
    }
    if (baseline.aiOnlyForComplexInput != settings.aiOnlyForComplexInput &&
        previous.aiOnlyForComplexInput != settings.aiOnlyForComplexInput) {
      await _preferences.setBool(
        _aiComplexOnlyKey,
        settings.aiOnlyForComplexInput,
      );
    }
    if (baseline.blockSensitiveAi != settings.blockSensitiveAi &&
        previous.blockSensitiveAi != settings.blockSensitiveAi) {
      await _preferences.setBool(
        _blockSensitiveAiKey,
        settings.blockSensitiveAi,
      );
    }
    final previousCategoriesJson = jsonEncode(
      previous.categories.map((category) => category.toJson()).toList(),
    );
    final baselineCategoriesJson = jsonEncode(
      baseline.categories.map((category) => category.toJson()).toList(),
    );
    final categoriesJson = jsonEncode(
      settings.categories.map((category) => category.toJson()).toList(),
    );
    if (baselineCategoriesJson != categoriesJson &&
        previousCategoriesJson != categoriesJson) {
      await _preferences.setString(_categoriesKey, categoriesJson);
    }
    final previousDdayOffsetsJson = jsonEncode(previous.dDayReminderOffsets);
    final baselineDdayOffsetsJson = jsonEncode(baseline.dDayReminderOffsets);
    final ddayOffsetsJson = jsonEncode(settings.dDayReminderOffsets);
    if (baselineDdayOffsetsJson != ddayOffsetsJson &&
        previousDdayOffsetsJson != ddayOffsetsJson) {
      await _preferences.setString(_dDayReminderOffsetsKey, ddayOffsetsJson);
    }
    final shouldMigrateLegacyTextSize =
        !_preferences.containsKey(_appTextSizeKey) &&
        _preferences.containsKey(_legacyCalendarEventTextSizeKey);
    if ((baseline.appTextSize != settings.appTextSize &&
            previous.appTextSize != settings.appTextSize) ||
        shouldMigrateLegacyTextSize) {
      await _preferences.setString(_appTextSizeKey, settings.appTextSize.name);
    }
    if (baseline.monthNavigationMode != settings.monthNavigationMode &&
        previous.monthNavigationMode != settings.monthNavigationMode) {
      await _preferences.setString(
        _monthNavigationModeKey,
        settings.monthNavigationMode.name,
      );
    }
    if (_preferences.containsKey(_legacyCalendarEventTextSizeKey)) {
      await _preferences.remove(_legacyCalendarEventTextSizeKey);
    }
    if (_preferences.containsKey(_legacyCalendarDensityKey)) {
      await _preferences.remove(_legacyCalendarDensityKey);
    }
    if (baseline.appStartView != settings.appStartView &&
        previous.appStartView != settings.appStartView) {
      await _preferences.setString(
        _appStartViewKey,
        settings.appStartView.name,
      );
    }
    if (baseline.defaultCalendarView != settings.defaultCalendarView &&
        previous.defaultCalendarView != settings.defaultCalendarView) {
      await _preferences.setString(
        _defaultCalendarViewKey,
        settings.defaultCalendarView.name,
      );
    }
    if (baseline.weekDayLayoutMode != settings.weekDayLayoutMode &&
        previous.weekDayLayoutMode != settings.weekDayLayoutMode) {
      await _preferences.setString(
        _weekDayLayoutModeKey,
        settings.weekDayLayoutMode.name,
      );
    }
    if (baseline.calendarEventTitleAlignment !=
            settings.calendarEventTitleAlignment &&
        previous.calendarEventTitleAlignment !=
            settings.calendarEventTitleAlignment) {
      await _preferences.setString(
        _calendarEventTitleAlignmentKey,
        settings.calendarEventTitleAlignment.name,
      );
    }
    if (baseline.calendarEventSortPriority !=
            settings.calendarEventSortPriority &&
        previous.calendarEventSortPriority !=
            settings.calendarEventSortPriority) {
      await _preferences.setString(
        _calendarEventSortPriorityKey,
        settings.calendarEventSortPriority.name,
      );
    }
    final previousManualOrdersJson = jsonEncode(
      previous.calendarManualEventOrders.map(
        (date, order) => MapEntry(date, order.toJson()),
      ),
    );
    final baselineManualOrdersJson = jsonEncode(
      baseline.calendarManualEventOrders.map(
        (date, order) => MapEntry(date, order.toJson()),
      ),
    );
    final manualOrdersJson = jsonEncode(
      settings.calendarManualEventOrders.map(
        (date, order) => MapEntry(date, order.toJson()),
      ),
    );
    if (baselineManualOrdersJson != manualOrdersJson &&
        previousManualOrdersJson != manualOrdersJson) {
      await _preferences.setString(
        _calendarManualEventOrdersKey,
        manualOrdersJson,
      );
    }
    final previousHiddenCategoriesJson = jsonEncode(previous.hiddenCategoryIds);
    final baselineHiddenCategoriesJson = jsonEncode(baseline.hiddenCategoryIds);
    final hiddenCategoriesJson = jsonEncode(settings.hiddenCategoryIds);
    if (baselineHiddenCategoriesJson != hiddenCategoriesJson &&
        previousHiddenCategoriesJson != hiddenCategoriesJson) {
      await _preferences.setString(_hiddenCategoryIdsKey, hiddenCategoriesJson);
    }
    if (baseline.calendarShowHolidays != settings.calendarShowHolidays &&
        previous.calendarShowHolidays != settings.calendarShowHolidays) {
      await _preferences.setBool(
        _calendarShowHolidaysKey,
        settings.calendarShowHolidays,
      );
    }
    if (baseline.calendarHolidayBackgroundEnabled !=
            settings.calendarHolidayBackgroundEnabled &&
        previous.calendarHolidayBackgroundEnabled !=
            settings.calendarHolidayBackgroundEnabled) {
      await _preferences.setBool(
        _calendarHolidayBackgroundEnabledKey,
        settings.calendarHolidayBackgroundEnabled,
      );
    }
    if (baseline.calendarDdayOnly != settings.calendarDdayOnly &&
        previous.calendarDdayOnly != settings.calendarDdayOnly) {
      await _preferences.setBool(
        _calendarDdayOnlyKey,
        settings.calendarDdayOnly,
      );
    }
    for (final legacyKey in const [
      'hideSensitiveEvents',
      'hideSensitiveNotifications',
      'privateEventHidingConfigured',
    ]) {
      if (_preferences.containsKey(legacyKey)) {
        await _preferences.remove(legacyKey);
      }
    }
    if (baseline.appLockEnabled != settings.appLockEnabled ||
        baseline.appLockBiometricsEnabled !=
            settings.appLockBiometricsEnabled ||
        baseline.appLockMethod != settings.appLockMethod) {
      final encoded = jsonEncode({
        'enabled': baseline.appLockEnabled != settings.appLockEnabled
            ? settings.appLockEnabled
            : previous.appLockEnabled,
        'biometrics':
            baseline.appLockBiometricsEnabled !=
                settings.appLockBiometricsEnabled
            ? settings.appLockBiometricsEnabled
            : previous.appLockBiometricsEnabled,
        'method':
            (baseline.appLockMethod != settings.appLockMethod
                    ? settings.appLockMethod
                    : previous.appLockMethod)
                .name,
      });
      try {
        final saved = await _preferences.setString(
          _appLockConfigurationKey,
          encoded,
        );
        // The plugin updates its cache even when its platform write fails.
        await _preferences.reload();
        if (!saved ||
            _preferences.getString(_appLockConfigurationKey) != encoded) {
          throw StateError('App lock configuration was not persisted');
        }
      } on Object {
        await _preferences.reload();
        rethrow;
      }
    }
    if (baseline.use24HourTime != settings.use24HourTime &&
        previous.use24HourTime != settings.use24HourTime) {
      await _preferences.setBool(_use24HourTimeKey, settings.use24HourTime);
    }
    if (baseline.themeMode != settings.themeMode &&
        previous.themeMode != settings.themeMode) {
      await _preferences.setString(_themeModeKey, settings.themeMode.name);
    }
    if (baseline.language != settings.language &&
        previous.language != settings.language) {
      await _preferences.setString(_languageKey, settings.language.name);
    }
    if (baseline.academicProfile != settings.academicProfile &&
        previous.academicProfile != settings.academicProfile) {
      final profile = settings.academicProfile;
      final saved = profile == null
          ? await _preferences.remove(_academicProfileKey)
          : await _preferences.setString(
              _academicProfileKey,
              jsonEncode(profile.toJson()),
            );
      if (!saved) throw StateError('Academic profile write failed');
    }
    if (markSyncPending &&
        canonicalSyncJson(syncSettingsValues(previous)) !=
            canonicalSyncJson(syncSettingsValues(load()))) {
      final document = previousSyncDocument.recordChanges(
        before: syncSettingsValues(previous),
        after: syncSettingsValues(load()),
        changedAt: changedAt,
        deviceId: await deviceId(),
      );
      final documentSaved = await _preferences.setString(
        _settingsSyncDocumentKey,
        canonicalSyncJson(document.toJson()),
      );
      if (!documentSaved) {
        throw StateError('Settings sync document write failed');
      }
      final revisionSaved = await _preferences.setInt(
        _settingsSyncRevisionKey,
        settingsSyncRevision + 1,
      );
      if (!revisionSaved) throw StateError('Settings revision write failed');
      if (!hasPendingSettingsSync) {
        if (!await _preferences.setBool(_settingsSyncPendingKey, true)) {
          throw StateError('Settings pending state write failed');
        }
      }
    }
  }

  bool get hasPendingSettingsSync =>
      _preferences.getBool(_settingsSyncPendingKey) ?? false;

  int get settingsSyncRevision =>
      _preferences.getInt(_settingsSyncRevisionKey) ?? 0;

  SettingsSyncDocument settingsSyncDocument() {
    final raw = _preferences.getString(_settingsSyncDocumentKey);
    if (raw != null) {
      return SettingsSyncDocument.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    }
    return hasPendingSettingsSync
        ? SettingsSyncDocument.legacy(syncSettingsValues(load()))
        : const SettingsSyncDocument();
  }

  Future<bool> mergeSettingsSyncDocument(
    SettingsSyncDocument remote,
    AppSettings Function(Map<String, Object?> values, AppSettings current)
    decode, {
    void Function()? validateSession,
  }) async {
    var changed = false;
    await _enqueueSettingsMutation(() async {
      validateSession?.call();
      final current = load();
      final merged = settingsSyncDocument().merge(remote);
      final target = decode(
        merged.values(syncSettingsValues(current)),
        current,
      );
      changed =
          canonicalSyncJson(syncSettingsValues(current)) !=
          canonicalSyncJson(syncSettingsValues(target));
      await _saveSettings(target, markSyncPending: false, changedFrom: null);
      await _preferences.setString(
        _settingsSyncDocumentKey,
        canonicalSyncJson(merged.toJson()),
      );
      await _preferences.setBool(
        _settingsSyncPendingKey,
        !merged.sameAs(remote),
      );
    });
    return changed;
  }

  Future<bool> acknowledgeSettingsSyncDocument(
    SettingsSyncDocument uploaded, {
    void Function()? validateSession,
  }) async {
    var acknowledged = false;
    await _enqueueSettingsMutation(() async {
      validateSession?.call();
      final current = settingsSyncDocument();
      final merged = current.merge(uploaded);
      final values = syncSettingsValues(load());
      acknowledged =
          merged.sameAs(uploaded) &&
          canonicalSyncJson(merged.values(values)) == canonicalSyncJson(values);
      if (acknowledged) {
        await _preferences.setString(
          _settingsSyncDocumentKey,
          canonicalSyncJson(merged.toJson()),
        );
        await _preferences.setBool(_settingsSyncPendingKey, false);
      }
    });
    return acknowledged;
  }

  Future<void> markSettingsSyncedIfRevision(int revision) {
    return _enqueueSettingsMutation(() async {
      if (settingsSyncRevision != revision) {
        return;
      }
      await _preferences.setBool(_settingsSyncPendingKey, false);
    });
  }

  /// Applies a downloaded settings snapshot only while the local settings
  /// state observed before the download is still current.
  ///
  /// [buildRestoredSettings] runs inside the settings mutation queue so it can
  /// preserve device-local fields from the latest persisted snapshot.
  Future<bool> applyRestoredSettingsIfUnchanged({
    required int expectedRevision,
    required int expectedMutationGeneration,
    required AppSettings Function(AppSettings current) buildRestoredSettings,
  }) {
    var applied = false;
    return _enqueueSettingsMutation(() async {
      if (hasPendingSettingsSync ||
          settingsSyncRevision != expectedRevision ||
          settingsMutationGeneration != expectedMutationGeneration) {
        return;
      }
      final restored = buildRestoredSettings(load());
      await _saveSettings(restored, markSyncPending: false, changedFrom: null);
      applied = true;
    }).then((_) => applied);
  }

  String? driveChangePageToken(String accountEmail) {
    final storedAccount = _preferences.getString(_driveChangeAccountKey);
    if (storedAccount == null ||
        storedAccount.toLowerCase() != accountEmail.trim().toLowerCase()) {
      return null;
    }
    final token = _preferences.getString(_driveChangeTokenKey)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Future<void> saveDriveChangePageToken({
    required String accountEmail,
    required String pageToken,
  }) async {
    await _preferences.setString(
      _driveChangeAccountKey,
      accountEmail.trim().toLowerCase(),
    );
    await _preferences.setString(_driveChangeTokenKey, pageToken.trim());
  }

  Future<void> clearDriveChangePageToken() async {
    await _preferences.remove(_driveChangeTokenKey);
    await _preferences.remove(_driveChangeAccountKey);
  }

  List<int> _loadDefaultReminderMinutes() {
    final raw = _preferences.getString(_defaultReminderListKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return normalizeReminderMinutes(decoded.whereType<int>());
        }
      } on FormatException {
        // Fall through to the legacy single-value setting.
      }
    }
    return normalizeReminderMinutes([
      _preferences.getInt(_defaultReminderKey) ?? 60,
    ]);
  }

  Future<void> completeOnboarding() async {
    await _preferences.setBool(_onboardingCompletedKey, true);
  }

  Future<String> deviceId() async {
    final existing = _preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = const Uuid().v4();
    await _preferences.setString(_deviceIdKey, created);
    return created;
  }

  AppleAccount? appleAccount() {
    final userIdentifier = _preferences.getString(_appleUserIdentifierKey);
    if (userIdentifier == null || userIdentifier.trim().isEmpty) {
      return null;
    }
    return AppleAccount(
      userIdentifier: userIdentifier,
      email: _stringOrNull(_preferences.getString(_appleEmailKey)),
      givenName: _stringOrNull(_preferences.getString(_appleGivenNameKey)),
      familyName: _stringOrNull(_preferences.getString(_appleFamilyNameKey)),
    );
  }

  DailyAccount? dailyAccount() {
    final stored = _storedDailyAccount();
    if (stored != null) {
      return stored;
    }
    final apple = appleAccount();
    if (apple == null) {
      return null;
    }
    return DailyAccount(id: const Uuid().v4(), appleAccount: apple);
  }

  bool get hasStoredDailyAccount => _storedDailyAccount() != null;

  Future<void> saveAppleAccount(AppleAccount account) async {
    final dailyAccount = _currentOrNewDailyAccount().copyWith(
      appleAccount: account,
    );
    await _saveDailyAccount(dailyAccount);
    await _preferences.setString(
      _appleUserIdentifierKey,
      account.userIdentifier,
    );
    await _setNullableString(_appleEmailKey, account.email);
    await _setNullableString(_appleGivenNameKey, account.givenName);
    await _setNullableString(_appleFamilyNameKey, account.familyName);
  }

  Future<void> deleteAppleAccount() async {
    await _preferences.remove(_appleUserIdentifierKey);
    await _preferences.remove(_appleEmailKey);
    await _preferences.remove(_appleGivenNameKey);
    await _preferences.remove(_appleFamilyNameKey);
    final dailyAccount = _storedDailyAccount();
    if (dailyAccount != null) {
      await _saveDailyAccount(dailyAccount.copyWith(clearAppleAccount: true));
    }
  }

  Future<void> saveGoogleAccount(GoogleAccount account) =>
      _enqueueSettingsMutation(() => _switchGoogleAccount(account));

  Future<void> deleteGoogleAccount() =>
      _enqueueSettingsMutation(() => _switchGoogleAccount(null));

  /// Academic details belong to a Google account. Other settings retain their
  /// existing device-wide behavior. Keep inactive profiles and their exact LWW
  /// registers locally until that account returns, including pending edits.
  Future<void> _switchGoogleAccount(GoogleAccount? account) async {
    String? email(String? value) => value?.trim().toLowerCase();
    final currentAccount = _storedDailyAccount();
    final previousEmail = email(currentAccount?.googleAccount?.email);
    final nextEmail = email(account?.email);
    final owner =
        _preferences.getString(_academicProfileOwnerKey) ?? previousEmail;
    final keys = [
      _dailyAccountKey,
      _academicProfileKey,
      _academicProfileOwnerKey,
      _academicProfileAccountsKey,
      _settingsSyncDocumentKey,
      _settingsSyncPendingKey,
      _settingsSyncRevisionKey,
      _driveChangeTokenKey,
      _driveChangeAccountKey,
    ];
    final before = {for (final key in keys) key: _preferences.get(key)};
    try {
      if (owner != nextEmail || previousEmail != nextEmail) {
        final raw = _preferences.getString(_academicProfileAccountsKey);
        final cache = raw == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final profile = load().academicProfile;
        final document = settingsSyncDocument();
        final activeRegister =
            document.fields['academicProfile'] ??
            (profile == null
                ? null
                : SettingsSyncValue(profile.toJson(), null, ''));
        if (profile != null || activeRegister != null) {
          // An ownerless legacy profile is never assigned to an arbitrary new
          // login. Retain it in quarantine instead of discarding or uploading it.
          cache[owner ?? '_unassigned'] = {
            'profile': profile?.toJson(),
            'register': activeRegister?.toJson(),
            'pending': hasPendingSettingsSync,
          };
        }
        final selected = nextEmail == null ? null : cache[nextEmail];
        final selectedProfile = selected?['profile'] == null
            ? null
            : AcademicProfile.fromJson(
                Map<String, Object?>.from(selected['profile'] as Map),
              );
        final selectedRegister = selected?['register'] == null
            ? null
            : SettingsSyncValue.fromJson(
                Map<String, Object?>.from(selected['register'] as Map),
              );
        if (activeRegister != null || selected != null || profile != null) {
          final remainingPending =
              hasPendingSettingsSync &&
              document.fields.keys.any((key) => key != 'academicProfile');
          await _writeAcademicAccountValue(
            _academicProfileAccountsKey,
            canonicalSyncJson(cache),
          );
          await _writeAcademicAccountValue(
            _academicProfileKey,
            selectedProfile == null
                ? null
                : jsonEncode(selectedProfile.toJson()),
          );
          await _writeAcademicAccountValue(
            _settingsSyncDocumentKey,
            canonicalSyncJson(
              document.withField('academicProfile', selectedRegister).toJson(),
            ),
          );
          await _writeAcademicAccountValue(
            _settingsSyncPendingKey,
            remainingPending || selected?['pending'] == true,
          );
          await _writeAcademicAccountValue(
            _settingsSyncRevisionKey,
            settingsSyncRevision + 1,
          );
        }
      }
      await _writeAcademicAccountValue(_academicProfileOwnerKey, nextEmail);
      final nextAccount = account == null
          ? currentAccount?.copyWith(clearGoogleAccount: true)
          : _currentOrNewDailyAccount().copyWith(googleAccount: account);
      await _writeAcademicAccountValue(
        _dailyAccountKey,
        nextAccount?.hasProviders == true
            ? jsonEncode(nextAccount!.toJson())
            : null,
      );
      if (account == null) {
        await _writeAcademicAccountValue(_driveChangeTokenKey, null);
        await _writeAcademicAccountValue(_driveChangeAccountKey, null);
      }
    } catch (_) {
      for (final entry in before.entries) {
        try {
          await _writeAcademicAccountValue(entry.key, entry.value);
        } catch (_) {
          // Preserve the first failure after attempting every rollback write.
        }
      }
      rethrow;
    }
  }

  Future<void> _writeAcademicAccountValue(String key, Object? value) async {
    final saved = switch (value) {
      null => await _preferences.remove(key),
      String value => await _preferences.setString(key, value),
      int value => await _preferences.setInt(key, value),
      bool value => await _preferences.setBool(key, value),
      _ => throw StateError('Invalid academic account cache'),
    };
    if (!saved) throw StateError('Academic account change was not persisted');
  }

  Future<void> deleteDailyAccount() async {
    await _preferences.remove(_dailyAccountKey);
    await _preferences.remove(_appleUserIdentifierKey);
    await _preferences.remove(_appleEmailKey);
    await _preferences.remove(_appleGivenNameKey);
    await _preferences.remove(_appleFamilyNameKey);
  }

  Future<String?> geminiApiKey() {
    return _secureStorage.read(key: _geminiKey);
  }

  Future<void> saveGeminiApiKey(String value) {
    return _secureStorage.write(key: _geminiKey, value: value.trim());
  }

  Future<void> deleteGeminiApiKey() {
    return _deleteSecureStorageKey(_geminiKey);
  }

  Future<void> saveAppLockPin(String pin) async {
    await _secureStorage.write(key: _appLockPinHashKey, value: _hashPin(pin));
    await _secureStorage.write(
      key: _appLockPinLengthKey,
      value: '${pin.length}',
    );
  }

  Future<void> deleteAppLockPin() async {
    await _deleteSecureStorageKey(_appLockPinHashKey);
    await _deleteSecureStorageKey(_appLockPinLengthKey);
  }

  // A verified legacy PIN needs only length metadata; do not rewrite its hash.
  Future<void> saveAppLockPinLength(int length) async {
    if (length < 4) throw ArgumentError.value(length, 'length');
    await _secureStorage.write(key: _appLockPinLengthKey, value: '$length');
  }

  Future<int?> appLockPinLength() async {
    final raw = await _secureStorage.read(key: _appLockPinLengthKey);
    final length = int.tryParse(raw ?? '');
    return length != null && length >= 4 ? length : null;
  }

  Future<bool> verifyAppLockPin(String pin) async {
    final stored = await _secureStorage.read(key: _appLockPinHashKey);
    return stored != null && stored == _hashPin(pin);
  }

  Future<void> resetAll() {
    academicStore.invalidate();
    timetableStore.invalidate();
    _settingsMutationGeneration += 1;
    return _enqueueSettingsMutation(_resetAll);
  }

  Future<void> _resetAll() async {
    await academicStore.clear();
    await timetableStore.clearLocal();
    await LockScreenWallpaperService.reset();
    await weatherStore.clear();
    await frequentPlaces.clear();
    await _preferences.remove(_defaultReminderKey);
    await _preferences.remove(_defaultReminderListKey);
    await _preferences.remove(_allDayReminderHourKey);
    await _preferences.remove(_allDayReminderMinuteKey);
    await _preferences.remove(_briefingHourKey);
    await _preferences.remove(_briefingMinuteKey);
    await _preferences.remove(_briefingEnabledKey);
    await _preferences.remove(_weekStartsOnMondayKey);
    await _preferences.remove(_showLunarDatesKey);
    await _preferences.remove(_showAdjacentMonthDatesKey);
    await _preferences.remove(_onboardingCompletedKey);
    await _preferences.remove(_aiEnabledKey);
    await _preferences.remove(_aiComplexOnlyKey);
    await _preferences.remove(_blockSensitiveAiKey);
    await _preferences.remove(_categoriesKey);
    await _preferences.remove(_dDayReminderOffsetsKey);
    await _preferences.remove(_appTextSizeKey);
    await _preferences.remove(_legacyCalendarEventTextSizeKey);
    await _preferences.remove(_legacyCalendarDensityKey);
    await _preferences.remove(_appStartViewKey);
    await _preferences.remove(_defaultCalendarViewKey);
    await _preferences.remove(_weekDayLayoutModeKey);
    await _preferences.remove(_calendarEventTitleAlignmentKey);
    await _preferences.remove(_calendarEventSortPriorityKey);
    await _preferences.remove(_calendarManualEventOrdersKey);
    await _preferences.remove(_hiddenCategoryIdsKey);
    await _preferences.remove(_calendarShowHolidaysKey);
    await _preferences.remove(_calendarHolidayBackgroundEnabledKey);
    await _preferences.remove(_calendarDdayOnlyKey);
    await _preferences.remove('hideSensitiveEvents');
    await _preferences.remove('hideSensitiveNotifications');
    await _preferences.remove('privateEventHidingConfigured');
    await _preferences.remove(_appLockEnabledKey);
    await _preferences.remove(_appLockBiometricsEnabledKey);
    await _preferences.remove(_appLockMethodKey);
    await _preferences.remove(_appLockConfigurationKey);
    await _preferences.remove(_use24HourTimeKey);
    await _preferences.remove(_themeModeKey);
    await _preferences.remove(_monthNavigationModeKey);
    await _preferences.remove(_languageKey);
    await _preferences.remove(_academicProfileKey);
    await _preferences.remove(_academicProfileOwnerKey);
    await _preferences.remove(_academicProfileAccountsKey);
    await _preferences.remove(_settingsSyncPendingKey);
    await _preferences.remove(_settingsSyncRevisionKey);
    await _preferences.remove(_settingsSyncDocumentKey);
    await clearDriveChangePageToken();
    await _preferences.remove(_deviceIdKey);
    await deleteDailyAccount();
    await deleteGeminiApiKey();
    await deleteAppLockPin();
  }

  Future<void> _enqueueSettingsMutation(Future<void> Function() mutation) {
    final operation = _settingsMutationTail.then((_) => mutation());
    _settingsMutationTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _deleteSecureStorageKey(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (error) {
      if (!_isMissingSecureStorageEntitlement(error)) {
        rethrow;
      }
    }
  }

  bool _isMissingSecureStorageEntitlement(PlatformException error) {
    final details = error.details?.toString().toLowerCase() ?? '';
    final message = error.message?.toLowerCase() ?? '';
    final code = error.code.toLowerCase();
    return code.contains('-34018') ||
        details.contains('-34018') ||
        message.contains('-34018') ||
        message.contains('entitlement');
  }

  Map<String, CalendarManualEventOrder> _loadCalendarManualEventOrders() {
    final raw = _preferences.getString(_calendarManualEventOrdersKey);
    if (raw == null || raw.isEmpty) {
      return const <String, CalendarManualEventOrder>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const <String, CalendarManualEventOrder>{};
      }
      final orders = <String, CalendarManualEventOrder>{};
      for (final entry in decoded.entries) {
        final date = entry.key?.toString() ?? '';
        final order = CalendarManualEventOrder.fromJson(entry.value);
        if (date.isNotEmpty && order != null) {
          orders[date] = order;
        }
      }
      return orders;
    } on Object {
      return const <String, CalendarManualEventOrder>{};
    }
  }

  List<EventCategory> _loadCategories() {
    final raw = _preferences.getString(_categoriesKey);
    if (raw == null || raw.isEmpty) {
      return const [EventCategory.basic, EventCategory.holiday];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [EventCategory.basic, EventCategory.holiday];
      }
      final categories = decoded
          .whereType<Map>()
          .map(
            (item) => EventCategory.fromJson(Map<String, Object?>.from(item)),
          )
          .where((category) => category.id.isNotEmpty)
          .toList();
      if (!categories.any(
        (category) => category.id == EventCategory.holiday.id,
      )) {
        categories.add(EventCategory.holiday);
      }
      return categories;
    } on Object {
      return const [EventCategory.basic, EventCategory.holiday];
    }
  }

  List<int> _loadDdayOffsets() {
    final raw = _preferences.getString(_dDayReminderOffsetsKey);
    if (raw == null || raw.isEmpty) {
      return const [-7, -3, -1, 0];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [-7, -3, -1, 0];
      }
      return decoded.whereType<int>().toList();
    } on Object {
      return const [-7, -3, -1, 0];
    }
  }

  List<String> _loadStringList(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded.whereType<String>().toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _setNullableString(String key, String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _preferences.remove(key);
      return;
    }
    await _preferences.setString(key, trimmed);
  }

  DailyAccount? _storedDailyAccount() {
    final raw = _preferences.getString(_dailyAccountKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return DailyAccount.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  DailyAccount _currentOrNewDailyAccount() {
    return _storedDailyAccount() ??
        DailyAccount(id: const Uuid().v4(), appleAccount: appleAccount());
  }

  Future<void> _saveDailyAccount(DailyAccount account) async {
    if (!account.hasProviders) {
      await _preferences.remove(_dailyAccountKey);
      return;
    }
    await _preferences.setString(
      _dailyAccountKey,
      jsonEncode(account.toJson()),
    );
  }

  String? _stringOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}
