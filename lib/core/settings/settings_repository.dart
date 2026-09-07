import 'dart:convert';

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
import 'app_settings.dart';

class SettingsRepository {
  SettingsRepository({
    required SharedPreferences preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage;
  Future<void> _settingsMutationTail = Future<void>.value();
  var _settingsMutationGeneration = 0;

  int get settingsMutationGeneration => _settingsMutationGeneration;

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
  static const _appLockEnabledKey = 'appLockEnabled';
  static const _appLockBiometricsEnabledKey = 'appLockBiometricsEnabled';
  static const _appLockMethodKey = 'appLockMethod';
  static const _use24HourTimeKey = 'use24HourTime';
  static const _themeModeKey = 'themeMode';
  static const _monthNavigationModeKey = 'monthNavigationMode';
  static const _languageKey = 'language';
  static const _settingsSyncPendingKey = 'settingsSyncPending';
  static const _settingsSyncRevisionKey = 'settingsSyncRevision';
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
    return AppSettings(
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
      appLockEnabled: _preferences.getBool(_appLockEnabledKey) ?? false,
      appLockBiometricsEnabled:
          _preferences.getBool(_appLockBiometricsEnabledKey) ?? false,
      appLockMethod: AppLockMethod.fromName(
        _preferences.getString(_appLockMethodKey),
        legacyBiometricsEnabled:
            _preferences.getBool(_appLockBiometricsEnabledKey) ?? false,
      ),
      use24HourTime: _preferences.getBool(_use24HourTimeKey) ?? true,
      themeMode: AppThemeMode.fromName(_preferences.getString(_themeModeKey)),
      monthNavigationMode: MonthNavigationMode.fromName(
        _preferences.getString(_monthNavigationModeKey),
      ),
      language: AppLanguage.fromName(_preferences.getString(_languageKey)),
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

  Future<void> _saveSettings(
    AppSettings settings, {
    required bool markSyncPending,
    required AppSettings? changedFrom,
  }) async {
    final previous = load();
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
    if (baseline.appLockEnabled != settings.appLockEnabled &&
        previous.appLockEnabled != settings.appLockEnabled) {
      await _preferences.setBool(_appLockEnabledKey, settings.appLockEnabled);
    }
    if (baseline.appLockBiometricsEnabled !=
            settings.appLockBiometricsEnabled &&
        previous.appLockBiometricsEnabled !=
            settings.appLockBiometricsEnabled) {
      await _preferences.setBool(
        _appLockBiometricsEnabledKey,
        settings.appLockBiometricsEnabled,
      );
    }
    if (baseline.appLockMethod != settings.appLockMethod &&
        previous.appLockMethod != settings.appLockMethod) {
      await _preferences.setString(
        _appLockMethodKey,
        settings.appLockMethod.name,
      );
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
    if (markSyncPending) {
      await _preferences.setInt(
        _settingsSyncRevisionKey,
        settingsSyncRevision + 1,
      );
      if (!hasPendingSettingsSync) {
        await _preferences.setBool(_settingsSyncPendingKey, true);
      }
    }
  }

  bool get hasPendingSettingsSync =>
      _preferences.getBool(_settingsSyncPendingKey) ?? false;

  int get settingsSyncRevision =>
      _preferences.getInt(_settingsSyncRevisionKey) ?? 0;

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

  Future<void> saveGoogleAccount(GoogleAccount account) async {
    await _saveDailyAccount(
      _currentOrNewDailyAccount().copyWith(googleAccount: account),
    );
  }

  Future<void> deleteGoogleAccount() async {
    final dailyAccount = _storedDailyAccount();
    if (dailyAccount != null) {
      await _saveDailyAccount(dailyAccount.copyWith(clearGoogleAccount: true));
    }
    await clearDriveChangePageToken();
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
    _settingsMutationGeneration += 1;
    return _enqueueSettingsMutation(_resetAll);
  }

  Future<void> _resetAll() async {
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
    await _preferences.remove(_use24HourTimeKey);
    await _preferences.remove(_themeModeKey);
    await _preferences.remove(_monthNavigationModeKey);
    await _preferences.remove(_languageKey);
    await _preferences.remove(_settingsSyncPendingKey);
    await _preferences.remove(_settingsSyncRevisionKey);
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
