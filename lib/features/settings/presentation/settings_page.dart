import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/apple_account.dart';
import '../../../core/analytics/product_analytics.dart';
import '../../../core/auth/apple_sign_in_service.dart';
import '../../../core/auth/daily_account.dart';
import '../../../core/auth/google_account.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/security/app_lock_privacy_service.dart';
import '../../../core/siri/siri_shortcut_installer.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/support/bug_report_service.dart';
import '../../../core/sync/google_drive_auth_service.dart';
import '../../../core/sync/google_drive_sync_service.dart';
import '../../../core/theme/daily_ui.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import 'calendar_import_page.dart';
import 'siri_activity_log_page.dart';

const _fallbackAppVersion = '3.0.0';

enum _SettingsDestination {
  notifications,
  account,
  appearance,
  privacy,
  categories,
  ai,
  about,
}

enum _AppStartDestination { quickView, week, month, day }

_AppStartDestination _appStartDestinationFor(AppSettings settings) {
  if (settings.appStartView == AppStartView.quickView) {
    return _AppStartDestination.quickView;
  }
  return switch (settings.defaultCalendarView) {
    CalendarViewMode.week => _AppStartDestination.week,
    CalendarViewMode.month => _AppStartDestination.month,
    CalendarViewMode.day => _AppStartDestination.day,
  };
}

CalendarViewMode? _calendarViewForStartDestination(
  _AppStartDestination destination,
) {
  return switch (destination) {
    _AppStartDestination.quickView => null,
    _AppStartDestination.week => CalendarViewMode.week,
    _AppStartDestination.month => CalendarViewMode.month,
    _AppStartDestination.day => CalendarViewMode.day,
  };
}

bool supportsAdjacentMonthDateSetting(TargetPlatform platform) {
  return platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key}) : _destination = null;

  const SettingsPage._destination({required _SettingsDestination destination})
    : _destination = destination;

  final _SettingsDestination? _destination;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _accountActionTimeout = Duration(seconds: 10);
  static const _logoutAccountReserve = Duration(seconds: 3);
  static const _resetNotificationCleanupTimeout = Duration(seconds: 3);
  static const _windowsSettingsPersistenceDelay = Duration(milliseconds: 240);

  final _apiKeyController = TextEditingController();
  late final Future<_AppVersionInfo> _appVersionInfo;
  var _syncMessage = '';
  var _syncBusy = false;
  var _appleMessage = '';
  var _appleBusy = false;
  var _bugReportBusy = false;
  var _deviceAuthenticationAvailable = false;
  var _biometricAuthenticationAvailable = false;
  AppSettings? _pendingWindowsSettings;
  Future<void> _windowsSettingsSaveTail = Future<void>.value();
  var _windowsSettingsSaveRevision = 0;
  AppleAccount? _appleAccount;
  GoogleDriveAccount? _googleDriveAccount;
  DailyAccount? _dailyAccount;
  var _googleDriveConnectAttempt = 0;
  int? _activeGoogleDriveConnectAttempt;
  Future<void> _categoryReorderSaveQueue = Future<void>.value();
  var _categoryReorderRevision = 0;

  static const _categoryColors = [
    0xff2563eb,
    0xff10b981,
    0xfff59e0b,
    0xffec4899,
    0xff8b5cf6,
    0xff14b8a6,
    0xff64748b,
    0xffef4444,
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final screen = switch (widget._destination) {
        _SettingsDestination.notifications =>
          AnalyticsScreen.notificationSettings,
        _SettingsDestination.account => AnalyticsScreen.accountSettings,
        _SettingsDestination.appearance ||
        _SettingsDestination.privacy ||
        _SettingsDestination.categories ||
        _SettingsDestination.ai ||
        _SettingsDestination.about => AnalyticsScreen.settings,
        null => AnalyticsScreen.settings,
      };
      unawaited(
        ref
            .read(productAnalyticsProvider)
            .record(AnalyticsRecord.screenView(screen))
            .catchError((_) {}),
      );
    });
    _appVersionInfo = _loadAppVersionInfo();
    Future.microtask(() async {
      final key = await ref.read(settingsRepositoryProvider).geminiApiKey();
      final settingsRepository = ref.read(settingsRepositoryProvider);
      AppleAccount? appleAccount;
      GoogleDriveAccount? googleDriveAccount;
      var dailyAccount = settingsRepository.dailyAccount();
      try {
        googleDriveAccount = await ref
            .read(googleDriveAuthServiceProvider)
            .restorePreviousSignIn();
        if (googleDriveAccount != null) {
          final headers = await ref
              .read(googleDriveAuthServiceProvider)
              .authorizationHeaders();
          if (headers == null) {
            googleDriveAccount = null;
          }
        }
        if (googleDriveAccount != null &&
            (dailyAccount?.googleAccount == null &&
                !settingsRepository.hasStoredDailyAccount)) {
          await settingsRepository.saveGoogleAccount(
            GoogleAccount(
              email: googleDriveAccount.email,
              displayName: googleDriveAccount.displayName,
            ),
          );
          dailyAccount = settingsRepository.dailyAccount();
        }
      } on Object {
        // Settings still shows the saved provider connection if restoration fails.
      }
      try {
        appleAccount = await ref
            .read(appleSignInServiceProvider)
            .refreshCurrentAccount();
      } on Object {
        appleAccount = ref.read(appleSignInServiceProvider).currentAccount;
      }
      if (mounted) {
        _apiKeyController.text = key ?? '';
        setState(() {
          _appleAccount = appleAccount;
          _googleDriveAccount = googleDriveAccount;
          _dailyAccount = settingsRepository.dailyAccount();
        });
      }
    });
    Future.microtask(() async {
      final authentication = BiometricAuthService();
      final available = await authentication.isDeviceAuthenticationAvailable();
      final biometricsAvailable = defaultTargetPlatform == TargetPlatform.macOS
          ? await authentication.isBiometricsOrCompanionAvailable()
          : await authentication.isAvailable();
      if (mounted) {
        setState(() {
          _deviceAuthenticationAvailable = available;
          _biometricAuthenticationAvailable = biometricsAvailable;
        });
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    final androidTablet =
        Theme.of(context).platform == TargetPlatform.android &&
        dailyWindowClassFor(windowSize) != DailyWindowClass.compact;
    final storedSettings = ref.watch(appSettingsProvider);
    final settings = defaultTargetPlatform == TargetPlatform.windows
        ? _pendingWindowsSettings ?? storedSettings
        : storedSettings;
    final analytics = ref.watch(productAnalyticsProvider);
    final appleSignInService = ref.watch(appleSignInServiceProvider);
    final account = _dailyAccount;
    final appleAccount = account?.appleAccount ?? _appleAccount;
    final hasAccountConnection = account?.hasProviders ?? false;
    final accountBusy = _appleBusy || _syncBusy;

    final pageTitle = switch (widget._destination) {
      _SettingsDestination.notifications => context.tr('알림 설정'),
      _SettingsDestination.account => context.tr('계정 설정'),
      _SettingsDestination.appearance => context.tr('화면 및 달력'),
      _SettingsDestination.privacy => context.tr('개인정보 및 잠금'),
      _SettingsDestination.categories => context.tr('분류 설정'),
      _SettingsDestination.ai => context.tr('AI 설정'),
      _SettingsDestination.about => context.tr('앱 정보 및 지원'),
      null => context.tr('설정'),
    };
    return Scaffold(
      backgroundColor: DailyUi.pageBackground(context),
      appBar: DailyNavigationBar(title: pageTitle),
      body: ColoredBox(
        color: DailyUi.pageBackground(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                DailyUi.isDesktop || androidTablet ? 24 : 16,
                10,
                DailyUi.isDesktop || androidTablet ? 24 : 16,
                28,
              ),
              children: [
                if (widget._destination == null) ...[
                  _SettingsSection(
                    title: 'Daily',
                    children: [
                      ListTile(
                        key: const ValueKey('account-settings-navigation'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.account_circle_outlined,
                        ),
                        title: Text(context.tr('계정')),
                        subtitle: _SettingsDescription(
                          context.tr('Apple, Google, 동기화 및 계정 관리'),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _openDestination(_SettingsDestination.account),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('notification-settings-navigation'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.notifications_outlined,
                        ),
                        title: Text(context.tr('알림')),
                        subtitle: _SettingsDescription(
                          context.tr('일정 알림, 아침 브리핑, D-day 알림'),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openDestination(
                          _SettingsDestination.notifications,
                        ),
                      ),
                      if (defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.macOS) ...[
                        const Divider(height: 1),
                        ListTile(
                          key: const ValueKey('siri-shortcut-setup'),
                          contentPadding: EdgeInsets.zero,
                          leading: const _SettingsLeadingIcon(
                            Icons.add_link_outlined,
                          ),
                          title: Text(context.tr('Siri 단축어 설정')),
                          subtitle: _SettingsDescription(
                            context.tr('시그널 단축어를 추가하고 Siri에서 Daily 명령을 사용합니다.'),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _showSiriShortcutSetup,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          key: const ValueKey('siri-activity-log-navigation'),
                          contentPadding: EdgeInsets.zero,
                          leading: const _SettingsLeadingIcon(
                            Icons.record_voice_over_outlined,
                          ),
                          title: Text(context.tr('Siri 작업 기록')),
                          subtitle: _SettingsDescription(
                            context.tr('Siri와 자동화로 실행한 Daily 작업을 날짜별로 확인합니다.'),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SiriActivityLogPage(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _SettingsSection(
                    title: context.tr('화면 및 일정'),
                    children: [
                      ListTile(
                        key: const ValueKey('appearance-settings-navigation'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.display_settings_outlined,
                        ),
                        title: Text(context.tr('화면 및 달력')),
                        subtitle: _SettingsDescription(
                          context.tr('언어, 테마, 글자 크기와 달력 표시 방식을 설정합니다.'),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _openDestination(_SettingsDestination.appearance),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('category-settings-navigation'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.category_outlined,
                        ),
                        title: Text(context.tr('분류')),
                        subtitle: _SettingsDescription(
                          context.tr('색상, 표시 여부와 일정 정렬 순서를 관리합니다.'),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _openDestination(_SettingsDestination.categories),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: context.tr('개인정보 및 지원'),
                    children: [
                      ListTile(
                        key: const ValueKey('privacy-settings-navigation'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.privacy_tip_outlined,
                        ),
                        title: Text(context.tr('개인정보 및 잠금')),
                        subtitle: _SettingsDescription(
                          context.tr('익명 분석 데이터와 앱 잠금을 관리합니다.'),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _openDestination(_SettingsDestination.privacy),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('ai-settings-navigation'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.auto_awesome_outlined,
                        ),
                        title: Text(context.tr('AI 설정')),
                        subtitle: _SettingsDescription(
                          context.tr('Daily의 AI 기능 준비 상태를 확인합니다.'),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openDestination(_SettingsDestination.ai),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('about-settings-navigation'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.info_outline_rounded,
                        ),
                        title: Text(context.tr('앱 정보 및 지원')),
                        subtitle: _SettingsDescription(
                          context.tr('버전 정보, GitHub와 버그 제보를 확인합니다.'),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _openDestination(_SettingsDestination.about),
                      ),
                    ],
                  ),
                ],
                if (widget._destination == _SettingsDestination.notifications)
                  _SettingsSection(
                    title: context.tr('알림'),
                    children: [
                      ListTile(
                        key: const ValueKey('system-notification-settings'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.settings_outlined,
                        ),
                        title: Text(context.tr('시스템 알림 설정 열기')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _openNotificationSettings,
                      ),
                      const Divider(height: 1),
                      _DefaultRemindersTile(
                        title: context.tr('기본 일정 알림'),
                        values: settings.defaultReminderMinutesList,
                        presets: const [0, 10, 30, 60, 1440],
                        onChanged: (values) => _save(
                          settings.copyWith(defaultReminderMinutesList: values),
                          changedFrom: settings,
                        ),
                        onCustom: () async {
                          final value = await _showNumberDialog(
                            context: context,
                            title: context.tr('기본 알림 직접 입력'),
                            label: context.tr('몇 분 전에 알릴까요?'),
                            initialValue: settings.defaultReminderMinutes,
                          );
                          if (value != null && value >= 0) {
                            await _save(
                              settings.copyWith(
                                defaultReminderMinutesList:
                                    normalizeReminderMinutes([
                                      ...settings.defaultReminderMinutesList,
                                      value,
                                    ]),
                              ),
                              changedFrom: settings,
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      _TimeTile(
                        title: context.tr('종일 일정 알림 시간'),
                        subtitle: context.tr('종일 일정의 알림 기준 시간'),
                        icon: Icons.event_outlined,
                        hour: settings.allDayReminderHour,
                        minute: settings.allDayReminderMinute,
                        use24HourTime: settings.use24HourTime,
                        onChanged: (time) => _save(
                          settings.copyWith(
                            allDayReminderHour: time.hour,
                            allDayReminderMinute: time.minute,
                          ),
                          changedFrom: settings,
                        ),
                      ),
                      const Divider(height: 1),
                      _TimeFormatTile(
                        use24HourTime: settings.use24HourTime,
                        onChanged: (value) => _save(
                          settings.copyWith(use24HourTime: value),
                          changedFrom: settings,
                        ),
                      ),
                      const Divider(height: 1),
                      _AnimatedSettingsSwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const _SettingsLeadingIcon(
                          Icons.wb_sunny_outlined,
                        ),
                        value: settings.morningBriefingEnabled,
                        title: Text(context.tr('아침 브리핑')),
                        subtitle: _SettingsDescription(
                          context.tr('매일 지정한 시간에 오늘 일정을 알려줍니다.'),
                        ),
                        onChanged: (value) async {
                          final updated = settings.copyWith(
                            morningBriefingEnabled: value,
                          );
                          await _save(updated, changedFrom: settings);
                          if (value) {
                            await ref
                                .read(notificationServiceProvider)
                                .scheduleMorningBriefing(
                                  hour: updated.morningBriefingHour,
                                  minute: updated.morningBriefingMinute,
                                );
                          } else {
                            await ref
                                .read(notificationServiceProvider)
                                .cancelMorningBriefing();
                          }
                        },
                      ),
                      if (settings.morningBriefingEnabled)
                        _TimeTile(
                          title: context.tr('아침 브리핑 시간'),
                          subtitle: context.tr('브리핑을 받을 시간'),
                          icon: Icons.alarm_outlined,
                          hour: settings.morningBriefingHour,
                          minute: settings.morningBriefingMinute,
                          use24HourTime: settings.use24HourTime,
                          onChanged: (time) async {
                            final updated = settings.copyWith(
                              morningBriefingHour: time.hour,
                              morningBriefingMinute: time.minute,
                            );
                            await _save(updated, changedFrom: settings);
                            await ref
                                .read(notificationServiceProvider)
                                .scheduleMorningBriefing(
                                  hour: time.hour,
                                  minute: time.minute,
                                );
                          },
                        ),
                      const Divider(height: 1),
                      _DdayOffsetsTile(
                        offsets: settings.dDayReminderOffsets,
                        onChanged: (offsets) => _save(
                          settings.copyWith(dDayReminderOffsets: offsets),
                          changedFrom: settings,
                        ),
                        onCustom: () async {
                          final value = await _showNumberDialog(
                            context: context,
                            title: context.tr('D-day 알림 직접 입력'),
                            label: context.tr('D-day 기준 일수. 예: -7, 0'),
                            initialValue: -7,
                          );
                          if (value != null) {
                            final offsets = {
                              ...settings.dDayReminderOffsets,
                              value,
                            }.toList()..sort();
                            await _save(
                              settings.copyWith(dDayReminderOffsets: offsets),
                              changedFrom: settings,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                if (widget._destination == _SettingsDestination.appearance)
                  _SettingsSection(
                    title: context.tr('화면'),
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.language_outlined,
                        ),
                        title: Text(context.tr('언어')),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<AppLanguage>(
                            value: settings.language,
                            alignment: AlignmentDirectional.centerEnd,
                            items: AppLanguage.values
                                .map(
                                  (language) => DropdownMenuItem(
                                    value: language,
                                    child: Text(
                                      context.l10n.languageName(language),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (language) {
                              if (language != null) {
                                _save(
                                  settings.copyWith(language: language),
                                  changedFrom: settings,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _ResponsiveSettingsControlRow(
                        icon: Icons.palette_outlined,
                        title: context.tr('테마'),
                        optionCount: AppThemeMode.values.length,
                        wideLabelFlex: 2,
                        wideControlFlex: 5,
                        control: _ThreeWayCapsule<AppThemeMode>(
                          key: const ValueKey('app-theme-mode-slider'),
                          values: AppThemeMode.values,
                          selected: settings.themeMode,
                          labelFor: context.l10n.themeName,
                          onChanged: (mode) => _save(
                            settings.copyWith(themeMode: mode),
                            changedFrom: settings,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (widget._destination == _SettingsDestination.appearance)
                  _SettingsSection(
                    title: context.tr('달력'),
                    children: [
                      if (defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.android) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const _SettingsLeadingIcon(
                            Icons.move_to_inbox_outlined,
                          ),
                          title: Text(context.tr('캘린더 데이터 옮기기')),
                          subtitle: _SettingsDescription(
                            context.tr(
                              defaultTargetPlatform == TargetPlatform.android
                                  ? 'Samsung 캘린더 또는 Google 캘린더에서 가져옵니다.'
                                  : 'Apple 캘린더 또는 Google 캘린더에서 가져옵니다.',
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CalendarImportPage(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      _ResponsiveSettingsControlRow(
                        icon: Icons.calendar_view_week_outlined,
                        title: context.tr('주 시작 요일'),
                        controlWidth: 132,
                        optionCount: 2,
                        control: _ThreeWayCapsule<bool>(
                          key: const ValueKey('week-start-toggle'),
                          values: const [false, true],
                          selected: settings.weekStartsOnMonday,
                          labelFor: (startsOnMonday) =>
                              context.tr(startsOnMonday ? '월' : '일'),
                          onChanged: (value) => _save(
                            settings.copyWith(weekStartsOnMonday: value),
                            changedFrom: settings,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _AnimatedSettingsSwitchListTile(
                        tileKey: const ValueKey('show-lunar-dates-toggle'),
                        contentPadding: EdgeInsets.zero,
                        secondary: const _SettingsLeadingIcon(
                          Icons.nightlight_outlined,
                        ),
                        value: settings.showLunarDates,
                        title: Text(context.tr('음력 표시')),
                        subtitle: _SettingsDescription(
                          context.tr('월 달력의 각 날짜에 음력 날짜를 함께 표시합니다.'),
                        ),
                        onChanged: (value) => _save(
                          settings.copyWith(showLunarDates: value),
                          changedFrom: settings,
                        ),
                      ),
                      if (supportsAdjacentMonthDateSetting(
                        defaultTargetPlatform,
                      )) ...[
                        const Divider(height: 1),
                        _AnimatedSettingsSwitchListTile(
                          tileKey: const ValueKey(
                            'show-adjacent-month-dates-toggle',
                          ),
                          contentPadding: EdgeInsets.zero,
                          secondary: const _SettingsLeadingIcon(
                            Icons.date_range_outlined,
                          ),
                          value:
                              settings.monthNavigationMode ==
                                  MonthNavigationMode.vertical
                              ? false
                              : settings.showAdjacentMonthDates,
                          title: Text(context.tr('인접한 달 날짜 표시')),
                          subtitle: _SettingsDescription(
                            settings.monthNavigationMode ==
                                    MonthNavigationMode.vertical
                                ? context.tr(
                                    '상하 스크롤에서는 월 경계를 명확히 구분하기 위해 사용할 수 없습니다.',
                                  )
                                : context.tr(
                                    '월간 달력의 첫주와 마지막 주에 이전·다음 달을 표시합니다.',
                                  ),
                          ),
                          onChanged:
                              settings.monthNavigationMode ==
                                  MonthNavigationMode.vertical
                              ? null
                              : (value) => _save(
                                  settings.copyWith(
                                    showAdjacentMonthDates: value,
                                  ),
                                  changedFrom: settings,
                                ),
                        ),
                      ],
                      const Divider(height: 1),
                      _ResponsiveSettingsControlRow(
                        icon: Icons.swipe_outlined,
                        title: context.tr('월간 이동 방식'),
                        controlWidth: 224,
                        optionCount: MonthNavigationMode.values.length,
                        control: _ThreeWayCapsule<MonthNavigationMode>(
                          key: const ValueKey('month-navigation-mode-slider'),
                          values: MonthNavigationMode.values,
                          selected: settings.monthNavigationMode,
                          labelFor: context.l10n.navigationName,
                          onChanged: (value) => _save(
                            settings.copyWith(
                              monthNavigationMode: value,
                              showAdjacentMonthDates:
                                  value == MonthNavigationMode.vertical
                                  ? false
                                  : settings.showAdjacentMonthDates,
                            ),
                            changedFrom: settings,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _ResponsiveSettingsControlRow(
                        icon: Icons.home_outlined,
                        title: context.tr('첫 화면'),
                        description: context.tr('앱을 열었을 때 먼저 보여줄 화면'),
                        controlWidth: 248,
                        optionCount: _AppStartDestination.values.length,
                        control: _ThreeWayCapsule<_AppStartDestination>(
                          key: const ValueKey('app-start-view-slider'),
                          values: _AppStartDestination.values,
                          selected: _appStartDestinationFor(settings),
                          labelFor: (destination) => switch (destination) {
                            _AppStartDestination.quickView => context.tr(
                              '빠른 보기',
                            ),
                            _AppStartDestination.week =>
                              context.l10n.compactCalendarViewName(
                                CalendarViewMode.week,
                              ),
                            _AppStartDestination.month =>
                              context.l10n.compactCalendarViewName(
                                CalendarViewMode.month,
                              ),
                            _AppStartDestination.day =>
                              context.l10n.compactCalendarViewName(
                                CalendarViewMode.day,
                              ),
                          },
                          onChanged: (destination) {
                            final calendarView =
                                _calendarViewForStartDestination(destination);
                            _save(
                              settings.copyWith(
                                appStartView: calendarView == null
                                    ? AppStartView.quickView
                                    : AppStartView.calendar,
                                defaultCalendarView:
                                    calendarView ??
                                    settings.defaultCalendarView,
                              ),
                              changedFrom: settings,
                            );
                            if (calendarView != null) {
                              ref
                                      .read(calendarViewModeProvider.notifier)
                                      .state =
                                  calendarView;
                            }
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      _ResponsiveSettingsControlRow(
                        icon: Icons.view_agenda_outlined,
                        title: context.tr('주간·일간 표시 방식'),
                        controlWidth: 168,
                        optionCount: WeekDayLayoutMode.values.length,
                        control: _ThreeWayCapsule<WeekDayLayoutMode>(
                          key: const ValueKey('week-day-layout-mode-slider'),
                          values: WeekDayLayoutMode.values,
                          selected: settings.weekDayLayoutMode,
                          labelFor: (mode) => context.tr(
                            mode == WeekDayLayoutMode.list ? '목록' : '스케줄',
                          ),
                          onChanged: (value) => _save(
                            settings.copyWith(weekDayLayoutMode: value),
                            changedFrom: settings,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _ResponsiveSettingsControlRow(
                        icon: Icons.format_align_center_outlined,
                        title: context.tr('일정 제목 정렬'),
                        controlWidth: 168,
                        optionCount: CalendarEventTitleAlignment.values.length,
                        control: _ThreeWayCapsule<CalendarEventTitleAlignment>(
                          key: const ValueKey('event-title-alignment-slider'),
                          values: CalendarEventTitleAlignment.values,
                          selected: settings.calendarEventTitleAlignment,
                          labelFor: (alignment) => context.tr(
                            alignment == CalendarEventTitleAlignment.leading
                                ? '기본'
                                : '가운데',
                          ),
                          onChanged: (value) => _save(
                            settings.copyWith(
                              calendarEventTitleAlignment: value,
                            ),
                            changedFrom: settings,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _AppTextSizeSlider(
                        textSize: settings.appTextSize,
                        onChanged: (value) => _save(
                          settings.copyWith(appTextSize: value),
                          changedFrom: settings,
                        ),
                      ),
                    ],
                  ),
                if (widget._destination == _SettingsDestination.privacy)
                  _SettingsSection(
                    title: context.tr('개인정보'),
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: analytics.enabledListenable,
                        builder: (context, enabled, _) =>
                            _AnimatedSettingsSwitchListTile(
                              tileKey: const ValueKey(
                                'anonymous-analytics-toggle',
                              ),
                              contentPadding: EdgeInsets.zero,
                              secondary: const _SettingsLeadingIcon(
                                Icons.insights_outlined,
                              ),
                              value: enabled,
                              title: Text(context.tr('익명 사용성 분석 허용')),
                              subtitle: _SettingsDescription(
                                context.tr(
                                  '일정 내용, 검색어, 계정 정보 없이 화면과 기능 사용, 오류 범주, 성능 정보만 수집합니다.',
                                ),
                              ),
                              onChanged: (value) => analytics.setEnabled(value),
                            ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('delete-analytics-data'),
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.delete_sweep_outlined,
                        ),
                        title: Text(context.tr('분석 데이터 삭제')),
                        subtitle: _SettingsDescription(
                          context.tr('이 기기에 전송 대기 중인 익명 분석 데이터를 삭제합니다.'),
                        ),
                        onTap: _deleteAnalyticsData,
                      ),
                      const Divider(height: 1),
                      _AnimatedSettingsSwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const _SettingsLeadingIcon(
                          Icons.lock_outline,
                        ),
                        value: settings.appLockEnabled,
                        title: Text(context.tr('앱 잠금')),
                        subtitle: _SettingsDescription(
                          settings.appLockEnabled
                              ? '앱 실행 시 ${settings.appLockMethod.label}으로 확인합니다.'
                              : context.tr('앱을 다시 열 때 사용자를 확인합니다.'),
                        ),
                        onChanged: (value) => value
                            ? _enableAppLock(settings)
                            : _disableAppLock(settings),
                      ),
                      if (settings.appLockEnabled) ...[
                        const Divider(height: 1),
                        _AppLockMethodSlider(
                          method: settings.appLockMethod,
                          systemAuthenticationAvailable:
                              _deviceAuthenticationAvailable,
                          onChanged: (method) =>
                              _changeAppLockMethod(settings, method),
                        ),
                        if (settings.appLockMethod == AppLockMethod.appPin) ...[
                          const Divider(height: 1),
                          _AnimatedSettingsSwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const _SettingsLeadingIcon(
                              Icons.fingerprint,
                            ),
                            value: settings.appLockBiometricsEnabled,
                            title: Text(context.tr('생체인식 잠금 해제')),
                            subtitle: _SettingsDescription(
                              _biometricAuthenticationAvailable
                                  ? defaultTargetPlatform ==
                                            TargetPlatform.macOS
                                        ? 'PIN 대신 Touch ID 또는 Apple Watch로 잠금을 해제할 수 있습니다.'
                                        : 'PIN 대신 Face ID 또는 Touch ID로 잠금을 해제할 수 있습니다.'
                                  : '이 기기에서 사용할 수 있는 생체인식이 없습니다.',
                            ),
                            onChanged: _biometricAuthenticationAvailable
                                ? (value) =>
                                      _changePinBiometricUnlock(settings, value)
                                : null,
                          ),
                        ],
                      ],
                    ],
                  ),
                if (widget._destination == _SettingsDestination.categories)
                  _SettingsSection(
                    title: context.tr('분류'),
                    children: [
                      ReorderableListView.builder(
                        key: const ValueKey('category-reorder-list'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: settings.categories.length,
                        onReorderItem: (oldIndex, newIndex) =>
                            _reorderCategories(settings, oldIndex, newIndex),
                        itemBuilder: (context, index) {
                          final category = settings.categories[index];
                          return _CategoryTile(
                            key: ValueKey('category-${category.id}'),
                            reorderIndex: index,
                            category: category,
                            visible: !settings.hiddenCategoryIds.contains(
                              category.id,
                            ),
                            onVisibilityChanged: (visible) =>
                                _setCategoryVisible(
                                  settings,
                                  category,
                                  visible,
                                ),
                            onEdit:
                                !category.locked ||
                                    category.id == EventCategory.holiday.id
                                ? () => _editCategory(settings, category)
                                : null,
                            onDelete: category.locked
                                ? null
                                : () => _deleteCategory(settings, category),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _ResponsiveSettingsControlRow(
                        icon: Icons.sort_outlined,
                        title: context.tr('일정 정렬 우선순위'),
                        controlWidth: 188,
                        optionCount: CalendarEventSortPriority.values.length,
                        control: _ThreeWayCapsule<CalendarEventSortPriority>(
                          key: const ValueKey('event-sort-priority-slider'),
                          values: CalendarEventSortPriority.values,
                          selected: settings.calendarEventSortPriority,
                          labelFor: (priority) => context.tr(
                            priority == CalendarEventSortPriority.category
                                ? '분류 우선'
                                : '시간 우선',
                          ),
                          onChanged: (value) => _save(
                            settings.copyWith(calendarEventSortPriority: value),
                            changedFrom: settings,
                          ),
                        ),
                      ),
                      _AnimatedSettingsSwitchListTile(
                        tileKey: const ValueKey('holiday-background-setting'),
                        contentPadding: EdgeInsets.zero,
                        secondary: const _SettingsLeadingIcon(
                          Icons.format_color_fill_outlined,
                        ),
                        value: settings.calendarHolidayBackgroundEnabled,
                        title: Text(context.tr('공휴일 날짜 배경')),
                        subtitle: _SettingsDescription(
                          context.tr('공휴일 분류 색상을 날짜 배경에 표시합니다.'),
                        ),
                        onChanged: (value) => _save(
                          settings.copyWith(
                            calendarHolidayBackgroundEnabled: value,
                          ),
                          changedFrom: settings,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _addCategory(settings),
                          icon: const Icon(Icons.add),
                          label: Text(context.tr('분류 추가')),
                        ),
                      ),
                    ],
                  ),
                if (widget._destination == _SettingsDestination.ai)
                  _SettingsSection(
                    title: 'AI',
                    children: [
                      Opacity(
                        opacity: 0.45,
                        child: IgnorePointer(
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const _SettingsLeadingIcon(
                                  Icons.auto_awesome_outlined,
                                ),
                                title: Text(context.tr('AI 기능')),
                                subtitle: _SettingsDescription(
                                  context.tr('개발 중입니다.'),
                                ),
                              ),
                              _AnimatedSettingsSwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: const _SettingsLeadingIcon(
                                  Icons.psychology_outlined,
                                ),
                                value: settings.aiEnabled,
                                title: Text(context.tr('Gemini 사용')),
                                onChanged: (_) {},
                              ),
                              _AnimatedSettingsSwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: const _SettingsLeadingIcon(
                                  Icons.shield_outlined,
                                ),
                                value: settings.blockSensitiveAi,
                                title: Text(context.tr('민감 문장 AI 차단')),
                                onChanged: (_) {},
                              ),
                              TextField(
                                controller: _apiKeyController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.key_outlined),
                                  labelText: context.tr('Gemini API 키'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                if (widget._destination == _SettingsDestination.account)
                  _SettingsSection(
                    title: context.tr('계정'),
                    children: [
                      _DailyAccountStatus(account: account),
                      const Divider(height: 1),
                      if (appleSignInService.isSupportedPlatform) ...[
                        _AppleSignInSettings(
                          account: appleAccount,
                          busy: _appleBusy,
                          message: _appleMessage,
                          onSignIn: _connectApple,
                          onDisconnect: _disconnectApple,
                        ),
                        const Divider(height: 1),
                      ],
                      _SyncStatusTile(
                        notifier: ref
                            .watch(googleDriveSyncServiceProvider)
                            .statusNotifier,
                      ),
                      const Divider(height: 1),
                      _GoogleDriveSyncSettings(
                        email: account?.googleAccount?.email,
                        sessionConnected: _googleDriveAccount != null,
                        busy: _syncBusy,
                        message: _syncMessage,
                        onConnect: _connectGoogleDrive,
                        onBackup: _backupGoogleDriveNow,
                        onRestore: _restoreGoogleDriveNow,
                        canCancelConnection: _canCancelGoogleDriveConnection,
                        onCancelConnection: _cancelGoogleDriveSignIn,
                        onDisconnect: _disconnectGoogle,
                        hasDailyAccount: hasAccountConnection,
                        onDeleteDailyAccount: _deleteAccount,
                      ),
                      if (hasAccountConnection) ...[
                        const SizedBox(height: 8),
                        _AccountLogoutButton(
                          busy: accountBusy,
                          onPressed: _logoutAccount,
                        ),
                      ],
                    ],
                  ),
                if (widget._destination == _SettingsDestination.about)
                  _SettingsSection(
                    title: context.tr('앱 정보'),
                    children: [
                      _AppVersionTile(
                        versionInfo: _appVersionInfo,
                        onDoubleTap: _openGithubRepository,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const _SettingsLeadingIcon(
                          Icons.bug_report_outlined,
                        ),
                        title: Text(context.tr('버그 제보')),
                        subtitle: _SettingsDescription(
                          context.tr(
                            'Google 로그인 사용자만 GitHub 이슈를 자동 등록할 수 있습니다.',
                          ),
                        ),
                        trailing: _bugReportBusy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _bugReportBusy ? null : _reportBug,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDestination(_SettingsDestination destination) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage._destination(destination: destination),
      ),
    );
  }

  Future<void> _showSiriShortcutSetup() async {
    final opened = await SiriShortcutInstaller.openSignalInstaller();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('시그널 단축어 추가 화면을 열 수 없습니다.'))),
      );
    }
  }

  Future<_AppVersionInfo> _loadAppVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return _AppVersionInfo(
        version: info.version.isEmpty ? _fallbackAppVersion : info.version,
        buildNumber: info.version.isEmpty ? _fallbackAppVersion : info.version,
        packageName: info.packageName,
      );
    } on Object {
      return const _AppVersionInfo(
        version: _fallbackAppVersion,
        buildNumber: _fallbackAppVersion,
      );
    }
  }

  Future<void> _openGithubRepository() async {
    const repositoryUrl = 'https://github.com/littlebit0/Daily';
    final opened = await launchUrl(
      Uri.parse(repositoryUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('GitHub Repository를 열 수 없습니다.'))),
      );
    }
  }

  Future<void> _deleteAnalyticsData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('분석 데이터 삭제')),
        content: Text(
          context.tr(
            '이 기기에 전송 대기 중인 익명 분석 데이터를 삭제할까요? 이미 전송되어 집계된 데이터는 계정이나 기기와 연결되지 않아 특정 사용자를 식별하거나 되돌릴 수 없습니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('삭제')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(productAnalyticsProvider).deletePendingData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('전송 대기 분석 데이터를 삭제했습니다.'))),
    );
  }

  Future<void> _reportBug() async {
    final linkedGoogle = _dailyAccount?.googleAccount;
    final activeGoogle = _googleDriveAccount;
    if (linkedGoogle == null ||
        activeGoogle == null ||
        !_sameEmail(linkedGoogle.email, activeGoogle.email)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Google 로그인이 필요합니다.')),
          content: Text(
            context.tr(
              '버그 제보는 Google 로그인으로 Daily를 사용 중인 경우에만 등록할 수 있습니다. 계정 설정에서 Google 계정을 연결해 주세요.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('확인')),
            ),
          ],
        ),
      );
      return;
    }

    final draft = await showDialog<BugReportDraft>(
      context: context,
      builder: (context) => _BugReportDialog(email: activeGoogle.email),
    );
    if (draft == null || !mounted) return;

    setState(() => _bugReportBusy = true);
    final info = await _appVersionInfo;
    final environment = BugReportEnvironment(
      version: info.version,
      buildNumber: info.buildNumber,
      platform: _platformName(defaultTargetPlatform),
      osVersion: Platform.operatingSystemVersion,
    );
    try {
      final authorizationHeaders = await ref
          .read(googleDriveAuthServiceProvider)
          .authorizationHeaders();
      if (authorizationHeaders == null) {
        throw const BugReportException(
          'google_auth_required',
          'Google 로그인 정보를 확인할 수 없습니다.',
        );
      }
      final submission = await ref
          .read(bugReportServiceProvider)
          .submit(
            draft: draft,
            environment: environment,
            googleAuthorizationHeaders: authorizationHeaders,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('버그 제보를 등록했습니다.')),
          content: Text(
            context.tr(
              'GitHub 이슈 #{number}로 등록되었습니다.',
              args: {'number': '${submission.issueNumber}'},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('닫기')),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(
                  launchUrl(
                    submission.issueUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(context.tr('GitHub에서 보기')),
            ),
          ],
        ),
      );
    } on BugReportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(error.message))));
    } finally {
      if (mounted) setState(() => _bugReportBusy = false);
    }
  }

  String _platformName(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  Future<void> _connectApple() async {
    setState(() {
      _appleBusy = true;
      _appleMessage = context.tr('Apple 로그인 창을 여는 중입니다.');
    });
    try {
      final account = await ref.read(appleSignInServiceProvider).signIn();
      if (!mounted) {
        return;
      }
      if (account == null) {
        setState(() => _appleMessage = context.tr('Apple 로그인이 취소되었습니다.'));
        return;
      }
      setState(() {
        _appleAccount = account;
        _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
        _appleMessage = context.tr('Apple 로그인이 완료되었습니다.');
      });
      final restoredGoogleSync = await _restoreLinkedGoogleDriveSync();
      if (mounted) {
        setState(() {
          _appleMessage = restoredGoogleSync
              ? context.tr('Apple 로그인이 완료되었습니다. 연결된 Google Drive 동기화를 복원했습니다.')
              : context.tr('Apple 로그인이 완료되었습니다.');
        });
      }
    } on AppleSignInException catch (error) {
      if (mounted) {
        setState(() => _appleMessage = error.message);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _appleMessage = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _appleBusy = false);
      }
    }
  }

  Future<void> _disconnectApple() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Apple 연동 해지')),
        content: const Text(
          'Apple 계정 연결을 해제할까요? iCloud 저장 기능은 아직 제공되지 않아 저장 내용 초기화는 사용할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          Tooltip(
            message: 'iCloud 저장 기능이 추가된 후 사용할 수 있습니다.',
            child: FilledButton(
              onPressed: null,
              child: Text(context.tr('저장 내용 초기화')),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('연동 해지')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _appleBusy = true;
      _appleMessage = '';
    });
    try {
      await ref.read(settingsRepositoryProvider).deleteAppleAccount();
      if (mounted) {
        setState(() {
          _appleAccount = null;
          _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
          _appleMessage = context.tr('Apple 연동을 해지했습니다.');
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _appleMessage = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _appleBusy = false);
      }
    }
  }

  Future<void> _save(
    AppSettings settings, {
    required AppSettings changedFrom,
    bool backup = true,
  }) async {
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Windows shared_preferences rewrites its complete JSON file
      // synchronously for every changed key. Keep that work outside the
      // control-motion window, and publish only the newest persisted value.
      final revision = ++_windowsSettingsSaveRevision;
      setState(() => _pendingWindowsSettings = settings);
      final repository = ref.read(settingsRepositoryProvider);
      final mutationGeneration = repository.settingsMutationGeneration;
      final backupService = ref.read(googleDriveSyncServiceProvider);
      final motionReady = Future<void>.delayed(
        _windowsSettingsPersistenceDelay,
      );
      var didPersist = false;
      final saveOperation = _windowsSettingsSaveTail.then((_) async {
        await motionReady;
        if (mutationGeneration != repository.settingsMutationGeneration) {
          return;
        }
        await repository.save(settings, changedFrom: changedFrom);
        didPersist = true;
      });
      _windowsSettingsSaveTail = saveOperation.catchError((Object _) {});
      try {
        await saveOperation;
      } on Object {
        if (revision == _windowsSettingsSaveRevision) {
          settingsNotifier.state = repository.load();
          if (mounted) {
            setState(() => _pendingWindowsSettings = null);
          }
        }
        rethrow;
      }
      if (!didPersist) {
        if (revision == _windowsSettingsSaveRevision) {
          if (mounted) {
            setState(() => _pendingWindowsSettings = null);
          }
        }
        return;
      }
      if (backup) {
        unawaited(backupService.queueSettingsBackup().catchError((_) {}));
      }
      if (revision != _windowsSettingsSaveRevision) {
        return;
      }
      settingsNotifier.state = repository.load();
      if (mounted && revision == _windowsSettingsSaveRevision) {
        setState(() => _pendingWindowsSettings = null);
      }
      return;
    } else {
      await ref
          .read(settingsRepositoryProvider)
          .save(settings, changedFrom: changedFrom);
      settingsNotifier.state = ref.read(settingsRepositoryProvider).load();
    }
    if (backup) {
      unawaited(
        ref
            .read(googleDriveSyncServiceProvider)
            .queueSettingsBackup()
            .catchError((_) {}),
      );
    }
  }

  Future<void> _enableAppLock(AppSettings settings) async {
    final method = await _selectLockMethod(settings.appLockMethod);
    if (method == null || !await _prepareLockMethod(method)) {
      return;
    }
    await _save(
      settings.copyWith(
        appLockEnabled: true,
        appLockMethod: method,
        appLockBiometricsEnabled: false,
      ),
      changedFrom: settings,
    );
  }

  Future<void> _disableAppLock(AppSettings settings) async {
    final repository = ref.read(settingsRepositoryProvider);
    final confirmed = await _confirmCurrentLockMethod(settings.appLockMethod);
    if (confirmed != true) {
      return;
    }
    await _save(
      settings.copyWith(appLockEnabled: false, appLockBiometricsEnabled: false),
      changedFrom: settings,
    );
    if (settings.appLockMethod == AppLockMethod.appPin) {
      await repository.deleteAppLockPin();
    }
  }

  Future<void> _changeAppLockMethod(
    AppSettings settings,
    AppLockMethod method,
  ) async {
    if (method == settings.appLockMethod) {
      return;
    }
    if (!await _confirmCurrentLockMethod(settings.appLockMethod)) {
      return;
    }
    if (!await _prepareLockMethod(method)) {
      return;
    }
    final repository = ref.read(settingsRepositoryProvider);
    await _save(
      settings.copyWith(appLockMethod: method, appLockBiometricsEnabled: false),
      changedFrom: settings,
    );
    if (settings.appLockMethod == AppLockMethod.appPin &&
        method != AppLockMethod.appPin) {
      await repository.deleteAppLockPin();
    }
  }

  Future<bool> _prepareLockMethod(AppLockMethod method) async {
    switch (method) {
      case AppLockMethod.noPin:
        return true;
      case AppLockMethod.appPin:
        final repository = ref.read(settingsRepositoryProvider);
        if (await repository.appLockPinLength() != null) {
          return true;
        }
        if (!mounted) {
          return false;
        }
        final pin = await _showPinSetupDialog(
          context: context,
          title: context.tr('앱 잠금 PIN 설정'),
        );
        if (pin == null) {
          return false;
        }
        await repository.saveAppLockPin(pin);
        return true;
      case AppLockMethod.system:
        if (_deviceAuthenticationAvailable) {
          return AppLockPrivacyService().duringConfigurationAuthentication(
            () => BiometricAuthService().authenticate(
              localizedReason: '시스템 잠금 방식으로 Daily 앱 잠금을 활성화합니다.',
              allowDeviceCredentials: true,
            ),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('이 기기에서 시스템 잠금 인증을 사용할 수 없습니다.')),
            ),
          );
        }
        return false;
    }
  }

  Future<AppLockMethod?> _selectLockMethod(AppLockMethod initialMethod) async {
    if (!mounted) {
      return null;
    }
    return showDialog<AppLockMethod>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('잠금 방식 선택')),
        children: [
          for (final method in AppLockMethod.values)
            SimpleDialogOption(
              onPressed:
                  method == AppLockMethod.system &&
                      !_deviceAuthenticationAvailable
                  ? null
                  : () => Navigator.of(context).pop(method),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  method == initialMethod
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(method.label),
                subtitle: Text(_lockMethodDescription(method)),
                enabled:
                    method != AppLockMethod.system ||
                    _deviceAuthenticationAvailable,
              ),
            ),
        ],
      ),
    );
  }

  String _lockMethodDescription(AppLockMethod method) => switch (method) {
    AppLockMethod.noPin => context.tr('앱을 벗어난 동안 화면만 가리고 복귀하면 자동으로 해제합니다.'),
    AppLockMethod.appPin => context.tr(
      'Daily 전용 PIN으로 잠그며 생체인식을 선택해서 함께 사용할 수 있습니다.',
    ),
    AppLockMethod.system => context.tr(
      '기기의 Face ID, Touch ID 또는 시스템 비밀번호로 인증합니다.',
    ),
  };

  Future<void> _changePinBiometricUnlock(
    AppSettings settings,
    bool enabled,
  ) async {
    final confirmed = enabled
        ? await AppLockPrivacyService().duringConfigurationAuthentication(
            () => defaultTargetPlatform == TargetPlatform.macOS
                ? BiometricAuthService().authenticateWithBiometricsOrCompanion(
                    localizedReason:
                        'Touch ID 또는 Apple Watch를 Daily PIN 잠금에 사용합니다.',
                  )
                : BiometricAuthService().authenticate(
                    localizedReason: 'Daily PIN 잠금에 생체인식 잠금 해제를 사용합니다.',
                  ),
          )
        : await _confirmCurrentLockMethod(AppLockMethod.appPin);
    if (!confirmed) {
      return;
    }
    await _save(
      settings.copyWith(appLockBiometricsEnabled: enabled),
      changedFrom: settings,
    );
  }

  Future<bool> _confirmCurrentLockMethod(AppLockMethod method) async {
    switch (method) {
      case AppLockMethod.noPin:
        if (!mounted) {
          return false;
        }
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.tr('잠금 방식 변경')),
                content: Text(context.tr('현재 PIN 없는 잠금 방식에서 변경을 계속할까요?')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.tr('취소')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.tr('계속')),
                  ),
                ],
              ),
            ) ??
            false;
      case AppLockMethod.appPin:
        final repository = ref.read(settingsRepositoryProvider);
        final pinLength = await repository.appLockPinLength();
        if (!mounted) {
          return false;
        }
        return await _showPinVerificationDialog(
              context: context,
              expectedLength: pinLength,
              verifier: repository.verifyAppLockPin,
            ) ??
            false;
      case AppLockMethod.system:
        return AppLockPrivacyService().duringConfigurationAuthentication(
          () => BiometricAuthService().authenticate(
            localizedReason: 'Daily 앱 잠금을 해제하려면 인증이 필요합니다.',
            allowDeviceCredentials: true,
          ),
        );
    }
  }

  Future<void> _openNotificationSettings() async {
    final urls = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => [Uri.parse('app-settings:')],
      TargetPlatform.macOS => [
        Uri.parse(
          'x-apple.systempreferences:com.apple.Notifications-Settings.extension',
        ),
        Uri.parse(
          'x-apple.systempreferences:com.apple.preference.notifications',
        ),
      ],
      TargetPlatform.windows => [Uri.parse('ms-settings:notifications')],
      _ => <Uri>[],
    };

    if (urls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Android에서는 시스템 설정 > 앱 > Daily > 알림에서 허용을 켜세요.'),
            ),
          ),
        );
      }
      return;
    }

    for (final url in urls) {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('시스템 알림 설정을 열 수 없습니다. OS 설정에서 Daily 알림을 허용하세요.'),
          ),
        ),
      );
    }
  }

  Future<void> _addCategory(AppSettings settings) async {
    final category = await _showCategoryDialog(context);
    if (category == null) {
      return;
    }
    final categories = [
      ...settings.categories.where((item) => item.id != category.id),
      category,
    ];
    await _save(
      settings.copyWith(categories: _normalizeCategories(categories)),
      changedFrom: settings,
      backup: false,
    );
    _queueCategoryBackup();
  }

  Future<void> _setCategoryVisible(
    AppSettings settings,
    EventCategory category,
    bool visible,
  ) async {
    final hidden = settings.hiddenCategoryIds.toSet();
    if (visible) {
      hidden.remove(category.id);
    } else {
      hidden.add(category.id);
    }
    await _save(
      settings.copyWith(hiddenCategoryIds: hidden.toList()),
      changedFrom: settings,
    );
    await ref.read(calendarWidgetServiceProvider).refresh();
  }

  void _reorderCategories(AppSettings settings, int oldIndex, int newIndex) {
    final categories = [...settings.categories];
    if (oldIndex < 0 || oldIndex >= categories.length) {
      return;
    }
    // onReorderItem already adjusts the destination after removing the source.
    newIndex = newIndex.clamp(0, categories.length - 1);
    if (oldIndex == newIndex) {
      return;
    }
    final category = categories.removeAt(oldIndex);
    categories.insert(newIndex, category);
    final updated = settings.copyWith(categories: categories);
    ref.read(appSettingsProvider.notifier).state = updated;

    final revision = ++_categoryReorderRevision;
    _categoryReorderSaveQueue = _categoryReorderSaveQueue.then((_) async {
      try {
        await ref
            .read(settingsRepositoryProvider)
            .save(updated, changedFrom: settings);
        if (revision == _categoryReorderRevision) {
          _queueCategoryBackup();
        }
      } on Object {
        if (!mounted || revision != _categoryReorderRevision) {
          return;
        }
        ref.read(appSettingsProvider.notifier).state = settings;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('선택을 저장하지 못했습니다. 다시 시도해 주세요.'))),
        );
      }
    });
  }

  Future<void> _editCategory(
    AppSettings settings,
    EventCategory category,
  ) async {
    final updatedCategory = await _showCategoryDialog(
      context,
      initialCategory: category,
    );
    if (updatedCategory == null) {
      return;
    }
    final categories = settings.categories
        .map((item) => item.id == category.id ? updatedCategory : item)
        .toList();
    final hiddenCategoryIds = settings.hiddenCategoryIds
        .map((id) => id == category.id ? updatedCategory.id : id)
        .toSet()
        .toList();
    await _save(
      settings.copyWith(
        categories: _normalizeCategories(categories),
        hiddenCategoryIds: hiddenCategoryIds,
      ),
      changedFrom: settings,
      backup: false,
    );
    await ref
        .read(eventCommandServiceProvider)
        .updateCategoryUsage(previous: category, updated: updatedCategory);
    _queueCategoryBackup();
  }

  Future<void> _deleteCategory(
    AppSettings settings,
    EventCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('분류 삭제')),
        content: Text(
          context.tr(
            '"{category}" 분류를 삭제할까요?',
            args: {
              'category': context.l10n.categoryName(
                id: category.id,
                label: category.label,
              ),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('삭제')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final categories = settings.categories
        .where((item) => item.id != category.id)
        .toList();
    await _save(
      settings.copyWith(
        categories: _normalizeCategories(categories),
        hiddenCategoryIds: settings.hiddenCategoryIds
            .where((id) => id != category.id)
            .toList(),
      ),
      changedFrom: settings,
      backup: false,
    );
    _queueCategoryBackup();
  }

  void _queueCategoryBackup() {
    unawaited(
      ref
          .read(googleDriveSyncServiceProvider)
          .syncPendingChangesNow()
          .catchError((_) {}),
    );
  }

  List<EventCategory> _normalizeCategories(List<EventCategory> categories) {
    final normalized = <EventCategory>[
      for (final category in categories)
        category.id == EventCategory.holiday.id
            ? category.copyWith(locked: true)
            : category,
    ];
    if (!normalized.any(
      (category) => category.id == EventCategory.holiday.id,
    )) {
      normalized.add(EventCategory.holiday);
    }
    return normalized;
  }

  Future<void> _connectGoogleDrive() async {
    final attempt = ++_googleDriveConnectAttempt;
    _activeGoogleDriveConnectAttempt = attempt;
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      final authService = ref.read(googleDriveAuthServiceProvider);
      final account = await authService.signIn(forceAccountSelection: true);
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
      }
      if (account == null) {
        throw const GoogleDriveAuthException('Google 로그인이 취소되었습니다.');
      }
      final headers = await authService.authorizationHeaders(
        promptIfNecessary: true,
      );
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
      }
      if (headers == null) {
        throw const GoogleDriveAuthException(
          'Google Drive 권한 승인이 완료되지 않았습니다. 다시 연결해 주세요.',
        );
      }
      await ref
          .read(settingsRepositoryProvider)
          .saveGoogleAccount(
            GoogleAccount(
              email: account.email,
              displayName: account.displayName,
            ),
          );
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.startListeningOnly(flushPendingChanges: false);
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
      }
      await syncService.syncPendingChangesNow(
        promptIfNecessary: false,
        restoreAfterBackup: true,
      );
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
      }
      if (!mounted) {
        return;
      }
      ref.read(appSettingsProvider.notifier).state = ref
          .read(settingsRepositoryProvider)
          .load();
      setState(() {
        _googleDriveAccount = account;
        _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
        _syncMessage = context.tr('Google Drive 연결이 완료되었습니다.');
      });
    } on Object catch (error) {
      if (mounted && _isCurrentGoogleDriveConnectAttempt(attempt)) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted && _isCurrentGoogleDriveConnectAttempt(attempt)) {
        setState(() {
          _activeGoogleDriveConnectAttempt = null;
          _syncBusy = false;
        });
      }
    }
  }

  Future<bool> _restoreLinkedGoogleDriveSync() async {
    final linkedGoogle = ref
        .read(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount;
    if (linkedGoogle == null) {
      return false;
    }
    try {
      final authService = ref.read(googleDriveAuthServiceProvider);
      final account = await authService.restorePreviousSignIn();
      if (account == null || !_sameEmail(account.email, linkedGoogle.email)) {
        return false;
      }
      final headers = await authService.authorizationHeaders();
      if (headers == null) {
        return false;
      }
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.startListeningOnly(flushPendingChanges: false);
      await syncService.syncPendingChangesNow(restoreAfterBackup: true);
      if (mounted) {
        setState(() => _googleDriveAccount = account);
      }
      return true;
    } on Object {
      return false;
    }
  }

  bool _sameEmail(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  bool _isCurrentGoogleDriveConnectAttempt(int attempt) {
    return _googleDriveConnectAttempt == attempt;
  }

  bool get _canCancelGoogleDriveConnection {
    if (!_syncBusy || _activeGoogleDriveConnectAttempt == null) {
      return false;
    }
    return ref
        .read(googleDriveAuthServiceProvider)
        .canCancelPendingSignInOnResume;
  }

  void _cancelGoogleDriveSignIn() {
    final attempt = _activeGoogleDriveConnectAttempt;
    if (attempt == null || !_isCurrentGoogleDriveConnectAttempt(attempt)) {
      return;
    }
    final authService = ref.read(googleDriveAuthServiceProvider);
    if (!authService.canCancelPendingSignInOnResume) {
      return;
    }
    authService.cancelPendingSignIn();
    _googleDriveConnectAttempt += 1;
    if (mounted) {
      setState(() {
        _activeGoogleDriveConnectAttempt = null;
        _syncBusy = false;
        _syncMessage = context.tr('Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.');
      });
    }
  }

  Future<void> _backupGoogleDriveNow() async {
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncPendingChangesNow(
            promptIfNecessary: defaultTargetPlatform != TargetPlatform.android,
          );
      if (mounted) {
        final status = ref
            .read(googleDriveSyncServiceProvider)
            .statusNotifier
            .value;
        setState(
          () => _syncMessage = status.message.isEmpty
              ? context.tr('백업할 변경 사항이 없습니다.')
              : status.message,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _restoreGoogleDriveNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Google Drive에서 복원')),
        content: Text(
          context.tr(
            'Google Drive AppData의 일정과 설정을 이 기기에 복원할까요? 이 기기의 더 최신이거나 아직 백업되지 않은 변경은 유지됩니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('복원')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .restoreNow(
            promptIfNecessary: defaultTargetPlatform != TargetPlatform.android,
          );
      if (mounted) {
        ref.read(appSettingsProvider.notifier).state = ref
            .read(settingsRepositoryProvider)
            .load();
        setState(() => _syncMessage = context.tr('Google Drive 복원 완료'));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _disconnectGoogle() async {
    final deleteBackup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Google 연동 해지')),
        content: Text(
          context.tr(
            'Google 계정 연결을 해제할까요? Google Drive AppData 백업은 유지하거나 함께 삭제할 수 있습니다. 로컬 일정과 설정은 유지됩니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(context.tr('취소')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('연동만 해제')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('백업 삭제 후 해제')),
          ),
        ],
      ),
    );
    if (deleteBackup == null) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      if (deleteBackup) {
        await ref
            .read(googleDriveSyncServiceProvider)
            .deleteCloudBackup(
              promptIfNecessary:
                  defaultTargetPlatform != TargetPlatform.android,
            );
      }
      try {
        await ref.read(googleDriveAuthServiceProvider).signOut();
      } on Object {
        // Local provider unlink must remain available even if the platform
        // cannot clear its cached Google session.
      }
      await ref.read(settingsRepositoryProvider).deleteGoogleAccount();
      if (mounted) {
        setState(() {
          _googleDriveAccount = null;
          _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
          _syncMessage = deleteBackup
              ? 'Google 연동과 Drive 백업을 삭제했습니다.'
              : 'Google 연동을 해지했습니다. Drive 백업은 유지됩니다.';
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _logoutAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('로그아웃')),
        content: Text(
          context.tr(
            '이 기기의 일정, 설정, 로그인 정보를 삭제하고 시작 화면으로 돌아갑니다. Google Drive AppData의 백업은 삭제하지 않습니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('로그아웃')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
      _appleMessage = '';
    });
    try {
      final events = await ref.read(eventRepositoryProvider).allEventsForSync();
      final hasGoogleAccount = _dailyAccount?.googleAccount != null;
      final backupCompleted =
          !hasGoogleAccount ||
          await _tryFlushPendingBeforeLogout(Stopwatch()..start());
      if (!backupCompleted &&
          (!mounted || !await _confirmLogoutWithoutBackup())) {
        return;
      }

      await ref.read(googleDriveSyncServiceProvider).stop();
      await _tryCancelNotificationsBeforeReset(events);
      await ref.read(alarmServiceProvider).cancelAllEventAlarms();
      try {
        await ref.read(googleDriveAuthServiceProvider).signOut();
      } on Object {
        // Local logout must still complete if a provider token cannot be cleared.
      }
      try {
        await ref.read(appleSignInServiceProvider).signOut();
      } on Object {
        // Apple has no remote logout endpoint; local cleanup continues.
      }
      await ref.read(eventRepositoryProvider).clearAll();
      await ref.read(settingsRepositoryProvider).resetAll();
      ref.read(appSettingsProvider.notifier).state = AppSettings();
      unawaited(
        ref.read(calendarWidgetServiceProvider).refresh().catchError((_) {}),
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<bool> _confirmLogoutWithoutBackup() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('백업을 완료하지 못했습니다')),
            content: Text(
              context.tr(
                '아직 Google Drive에 백업되지 않은 변경이 있을 수 있습니다. 그래도 이 기기의 데이터를 삭제하고 로그아웃할까요?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('취소')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: Text(context.tr('백업 없이 로그아웃')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteAccount() async {
    final authService = ref.read(googleDriveAuthServiceProvider);
    final dailyAccount = _dailyAccount;
    final hasGoogleAccount = dailyAccount?.googleAccount != null;
    final hasDailyAccount = dailyAccount?.hasProviders ?? false;
    final title = context.tr(hasDailyAccount ? 'Daily 계정 탈퇴' : '로컬 데이터 초기화');
    final content = hasDailyAccount
        ? context.tr(
            'Daily 계정의 Apple/Google 연결 및 병합 정보, Google Drive AppData 백업, 이 기기의 모든 일정과 설정을 삭제하고 시작 화면으로 돌아갑니다. 향후 iCloud 저장 데이터도 이 경로에서 함께 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
          )
        : context.tr('이 기기의 모든 일정과 설정을 삭제하고 시작 화면으로 돌아갑니다.');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr(hasDailyAccount ? 'Daily 계정 탈퇴' : '초기화')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      final events = await ref.read(eventRepositoryProvider).allEventsForSync();
      await _tryCancelNotificationsBeforeReset(events);
      await ref.read(alarmServiceProvider).cancelAllEventAlarms();
      if (hasGoogleAccount) {
        await ref
            .read(googleDriveSyncServiceProvider)
            .deleteCloudBackup(
              promptIfNecessary:
                  defaultTargetPlatform != TargetPlatform.android,
            );
      }
      await ref.read(eventRepositoryProvider).clearAll();
      await ref.read(settingsRepositoryProvider).resetAll();
      if (hasGoogleAccount) {
        await authService.signOut();
      }
      await ref.read(appleSignInServiceProvider).signOut();
      ref.read(appSettingsProvider.notifier).state = AppSettings();
      unawaited(
        ref.read(calendarWidgetServiceProvider).refresh().catchError((_) {}),
      );
      if (mounted) {
        setState(() {
          _appleAccount = null;
          _googleDriveAccount = null;
          _dailyAccount = null;
          _syncMessage = hasDailyAccount
              ? 'Daily 계정 탈퇴가 완료되었습니다.'
              : '로컬 데이터 초기화가 완료되었습니다.';
        });
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _tryCancelNotificationsBeforeReset(
    List<CalendarEvent> events,
  ) async {
    try {
      await Future<void>(() async {
        final notificationService = ref.read(notificationServiceProvider);
        for (final event in events) {
          await notificationService.cancelEventReminder(
            event.id,
            reminderMinutesBeforeList: event.reminderMinutesBeforeList,
          );
        }
        await notificationService.cancelMorningBriefing();
      }).timeout(_resetNotificationCleanupTimeout);
    } on Object {
      // Local data reset must not be blocked by OS notification permission,
      // signing, or notification-center state. Stale reminders are resynced or
      // cleared on the next successful notification initialization.
    }
  }

  Future<bool> _tryFlushPendingBeforeLogout(Stopwatch stopwatch) async {
    final syncBudget =
        _accountActionTimeout - stopwatch.elapsed - _logoutAccountReserve;
    if (syncBudget <= Duration.zero) {
      return false;
    }
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncPendingChangesNow(promptIfNecessary: false)
          .timeout(syncBudget);
      return true;
    } on Object {
      return false;
    }
  }

  String _googleAccountErrorMessage(Object error) {
    if (error is GoogleDriveAuthException) {
      return error.message;
    }
    if (error is GoogleDriveSyncException) {
      return error.message;
    }

    final text = error.toString().trim();
    if (text.isEmpty) {
      return context.tr('요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    final lower = text.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('timeoutexception')) {
      return context.tr('네트워크 연결을 확인한 뒤 다시 시도해 주세요.');
    }
    if (lower.contains('invalid_grant') ||
        lower.contains('invalid_token') ||
        text.contains('HTTP 401')) {
      return context.tr('Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.');
    }
    if (lower.contains('permission') ||
        lower.contains('insufficient') ||
        text.contains('HTTP 403')) {
      return context.tr('Google Drive 권한이 부족합니다. 다시 연결해 권한을 승인해 주세요.');
    }
    if (text.contains('HTTP 429')) {
      return context.tr('Google Drive 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.');
    }
    if (RegExp(r'HTTP 5\d\d').hasMatch(text)) {
      return context.tr('Google Drive 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.');
    }
    return text;
  }
}

class _ResponsiveSettingsControlRow extends StatelessWidget {
  const _ResponsiveSettingsControlRow({
    required this.icon,
    required this.title,
    required this.optionCount,
    required this.control,
    this.description,
    this.controlWidth,
    this.wideLabelFlex = 1,
    this.wideControlFlex = 1,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  });

  static const _compactMaxWidth = 520.0;
  static const _leadingWidth = 40.0;
  static const _leadingGap = 16.0;
  static const _controlGap = 12.0;

  final IconData icon;
  final String title;
  final String? description;
  final int optionCount;
  final Widget control;
  final double? controlWidth;
  final int wideLabelFlex;
  final int wideControlFlex;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final titleStyle = theme.textTheme.bodyLarge;
        final availableWidth = constraints.maxWidth;
        final measuredTitleWidth = _measureTitleWidth(context, titleStyle);
        final reservedControlWidth =
            controlWidth ??
            (availableWidth - _leadingWidth - _leadingGap - _controlGap) *
                wideControlFlex /
                (wideLabelFlex + wideControlFlex);
        final availableInlineLabelWidth =
            availableWidth -
            _leadingWidth -
            _leadingGap -
            _controlGap -
            reservedControlWidth;
        final compactPlatform =
            theme.platform == TargetPlatform.iOS ||
            theme.platform == TargetPlatform.android;
        final compactLayout =
            compactPlatform && availableWidth <= _compactMaxWidth;
        final stackControl =
            compactLayout &&
            (optionCount >= 3 ||
                availableInlineLabelWidth < measuredTitleWidth);
        final label = _label(context, titleStyle);

        return Padding(
          padding: padding,
          child: stackControl
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettingsRowLeading(icon),
                        const SizedBox(width: _leadingGap),
                        Expanded(child: label),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: _leadingWidth + _leadingGap,
                      ),
                      child: SizedBox(width: double.infinity, child: control),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _SettingsRowLeading(icon),
                    const SizedBox(width: _leadingGap),
                    Expanded(flex: wideLabelFlex, child: label),
                    const SizedBox(width: _controlGap),
                    if (controlWidth case final width?)
                      SizedBox(width: width, child: control)
                    else
                      Expanded(flex: wideControlFlex, child: control),
                  ],
                ),
        );
      },
    );
  }

  Widget _label(BuildContext context, TextStyle? titleStyle) {
    final description = this.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: _SettingsDescription(description),
          ),
        ],
      ],
    );
  }

  double _measureTitleWidth(BuildContext context, TextStyle? titleStyle) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    return painter.width + 4;
  }
}

class _AppTextSizeSlider extends StatelessWidget {
  const _AppTextSizeSlider({required this.textSize, required this.onChanged});

  final AppTextSize textSize;
  final ValueChanged<AppTextSize> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveSettingsControlRow(
      icon: Icons.text_fields_outlined,
      title: context.tr('전체 UI 글자 크기'),
      optionCount: AppTextSize.values.length,
      wideLabelFlex: 3,
      wideControlFlex: 5,
      control: _ThreeWayCapsule<AppTextSize>(
        key: const ValueKey('app-text-size-slider'),
        values: AppTextSize.values,
        selected: textSize,
        labelFor: context.l10n.textSizeName,
        onChanged: onChanged,
      ),
    );
  }
}

class _AppLockMethodSlider extends StatelessWidget {
  const _AppLockMethodSlider({
    required this.method,
    required this.systemAuthenticationAvailable,
    required this.onChanged,
  });

  final AppLockMethod method;
  final bool systemAuthenticationAvailable;
  final ValueChanged<AppLockMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveSettingsControlRow(
      icon: Icons.admin_panel_settings_outlined,
      title: context.tr('잠금 방식'),
      optionCount: AppLockMethod.values.length,
      wideLabelFlex: 2,
      wideControlFlex: 5,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      control: _ThreeWayCapsule<AppLockMethod>(
        key: const ValueKey('app-lock-method-slider'),
        values: AppLockMethod.values,
        selected: method,
        labelFor: (method) => switch (method) {
          AppLockMethod.noPin => context.tr('PIN 없음'),
          AppLockMethod.appPin => context.tr('PIN 잠금'),
          AppLockMethod.system => context.tr('시스템'),
        },
        enabledFor: (method) =>
            method != AppLockMethod.system || systemAuthenticationAvailable,
        onChanged: onChanged,
      ),
    );
  }
}

class _AnimatedSettingsSwitchListTile extends StatefulWidget {
  const _AnimatedSettingsSwitchListTile({
    this.tileKey,
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.secondary,
    this.contentPadding = EdgeInsets.zero,
  });

  final Key? tileKey;
  final bool value;
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry contentPadding;
  final ValueChanged<bool>? onChanged;

  @override
  State<_AnimatedSettingsSwitchListTile> createState() =>
      _AnimatedSettingsSwitchListTileState();
}

class _AnimatedSettingsSwitchListTileState
    extends State<_AnimatedSettingsSwitchListTile> {
  late final WidgetStatesController _statesController;
  var _pointerPressed = false;
  var _tilePressed = false;
  int? _activePointer;
  Offset? _pointerOrigin;

  bool get _pressed =>
      widget.onChanged != null &&
      (_pointerPressed ||
          (_tilePressed &&
              !(_activePointer != null && _pointerOrigin == null)));

  @override
  void initState() {
    super.initState();
    _statesController = WidgetStatesController()..addListener(_handleStates);
  }

  @override
  void didUpdateWidget(covariant _AnimatedSettingsSwitchListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null) {
      _activePointer = null;
      _pointerOrigin = null;
      _pointerPressed = false;
      _tilePressed = false;
    }
  }

  @override
  void dispose() {
    _statesController
      ..removeListener(_handleStates)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final switchOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.primary.withValues(alpha: 0.24);
      }
      if (states.contains(WidgetState.hovered)) {
        return colorScheme.primary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.focused)) {
        return colorScheme.primary.withValues(alpha: 0.16);
      }
      return null;
    });
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.onChanged == null ? null : _handlePointerDown,
      onPointerMove: widget.onChanged == null ? null : _handlePointerMove,
      onPointerUp: widget.onChanged == null ? null : _handlePointerEnd,
      onPointerCancel: widget.onChanged == null ? null : _handlePointerEnd,
      child: AnimatedScale(
        key: const ValueKey('settings-switch-press-scale'),
        scale: _pressed ? 0.985 : 1,
        duration: _pressed
            ? const Duration(milliseconds: 75)
            : const Duration(milliseconds: 170),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          key: const ValueKey('settings-switch-press-surface'),
          duration: _pressed
              ? const Duration(milliseconds: 75)
              : const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _pressed
                ? colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              key: widget.tileKey,
              statesController: _statesController,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: widget.contentPadding,
              secondary: widget.secondary,
              value: widget.value,
              title: widget.title,
              subtitle: widget.subtitle,
              overlayColor: switchOverlay,
              hoverColor: colorScheme.primary.withValues(alpha: 0.05),
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ),
    );
  }

  void _handleStates() {
    final pressed = _statesController.value.contains(WidgetState.pressed);
    if (mounted && pressed != _tilePressed) {
      setState(() => _tilePressed = pressed);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!mounted ||
        _activePointer != null ||
        (event.buttons & kPrimaryButton) == 0) {
      return;
    }
    _activePointer = event.pointer;
    _pointerOrigin = event.position;
    _setPointerPressed(true);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final origin = _pointerOrigin;
    if (event.pointer != _activePointer || origin == null) {
      return;
    }
    if ((event.position - origin).distance > kTouchSlop) {
      _pointerOrigin = null;
      _setPointerPressed(false);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    _activePointer = null;
    _pointerOrigin = null;
    _setPointerPressed(false);
  }

  void _setPointerPressed(bool pressed) {
    if (mounted && _pointerPressed != pressed) {
      setState(() => _pointerPressed = pressed);
    }
  }
}

class _ThreeWayCapsule<T> extends StatefulWidget {
  const _ThreeWayCapsule({
    super.key,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
    this.enabledFor,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final bool Function(T value)? enabledFor;
  final ValueChanged<T> onChanged;

  @override
  State<_ThreeWayCapsule<T>> createState() => _ThreeWayCapsuleState<T>();
}

class _ThreeWayCapsuleState<T> extends State<_ThreeWayCapsule<T>> {
  T? _dragValue;
  T? _pressedValue;
  int? _activePointer;
  Offset? _pointerOrigin;
  bool? _pointerDragIsHorizontal;

  T get _visibleValue => _dragValue ?? _pressedValue ?? widget.selected;

  bool get _interactionActive => _dragValue != null || _pressedValue != null;

  @override
  Widget build(BuildContext context) {
    const height = 42.0;
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (details) =>
            _handlePointerDown(details, constraints.maxWidth),
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            if (_pointerDragIsHorizontal == true) {
              _previewAt(details.localPosition.dx, constraints.maxWidth);
            }
          },
          onHorizontalDragUpdate: (details) {
            if (_pointerDragIsHorizontal == true) {
              _previewAt(details.localPosition.dx, constraints.maxWidth);
            }
          },
          onHorizontalDragEnd: (_) {
            final value = _dragValue;
            if (_pointerDragIsHorizontal == true &&
                value != null &&
                _isEnabled(value)) {
              widget.onChanged(value);
            }
            if (!mounted) {
              return;
            }
            setState(() {
              _dragValue = null;
              _pressedValue = null;
              _pointerDragIsHorizontal = null;
            });
          },
          onHorizontalDragCancel: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _dragValue = null;
              _pressedValue = null;
              _pointerDragIsHorizontal = null;
            });
          },
          child: Container(
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: dark
                  ? colorScheme.surfaceContainerHigh
                  : const Color(0xffeef2f7),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  key: const ValueKey('settings-capsule-selection-indicator'),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: _alignmentFor(_visibleValue),
                  child: AnimatedScale(
                    key: const ValueKey(
                      'settings-capsule-selection-press-scale',
                    ),
                    scale: _interactionActive ? 0.93 : 1,
                    duration: _interactionActive
                        ? const Duration(milliseconds: 75)
                        : const Duration(milliseconds: 160),
                    curve: _interactionActive
                        ? Curves.easeOutCubic
                        : Curves.easeOutBack,
                    child: FractionallySizedBox(
                      widthFactor: 1 / widget.values.length,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(height / 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1a0f172a),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: Row(
                    children: [
                      for (final (index, value) in widget.values.indexed)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: value == widget.selected,
                            enabled: _isEnabled(value),
                            inMutuallyExclusiveGroup: true,
                            label: widget.labelFor(value),
                            onTap: _isEnabled(value)
                                ? () => _commitValue(value)
                                : null,
                            child: InkWell(
                              key: ValueKey('settings-capsule-option-$index'),
                              excludeFromSemantics: true,
                              borderRadius: BorderRadius.circular(height / 2),
                              overlayColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.pressed)) {
                                  return colorScheme.primary.withValues(
                                    alpha: 0.18,
                                  );
                                }
                                if (states.contains(WidgetState.hovered)) {
                                  return colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  );
                                }
                                if (states.contains(WidgetState.focused)) {
                                  return colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  );
                                }
                                return null;
                              }),
                              onHighlightChanged: _isEnabled(value)
                                  ? (highlighted) => _handleHighlightChange(
                                      value,
                                      highlighted,
                                    )
                                  : null,
                              onTap: _isEnabled(value)
                                  ? () => _commitValue(value)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    style:
                                        (Theme.of(
                                                  context,
                                                ).textTheme.labelSmall ??
                                                const TextStyle())
                                            .copyWith(
                                              color: !_isEnabled(value)
                                                  ? Theme.of(
                                                      context,
                                                    ).disabledColor
                                                  : value == _visibleValue
                                                  ? colorScheme.primary
                                                  : colorScheme
                                                        .onSurfaceVariant,
                                              fontWeight: value == _visibleValue
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        widget.labelFor(value),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isEnabled(T value) => widget.enabledFor?.call(value) ?? true;

  void _handlePointerDown(PointerDownEvent event, double width) {
    if (!mounted ||
        _activePointer != null ||
        (event.buttons & kPrimaryButton) == 0) {
      return;
    }
    final value = _valueAt(event.localPosition.dx, width);
    if (!_isEnabled(value)) {
      return;
    }
    _activePointer = event.pointer;
    _pointerOrigin = event.position;
    _pointerDragIsHorizontal = null;
    _setPressedValue(value);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final origin = _pointerOrigin;
    if (event.pointer != _activePointer || origin == null) {
      return;
    }
    final delta = event.position - origin;
    if (delta.distance > kTouchSlop) {
      _pointerDragIsHorizontal = delta.dx.abs() > delta.dy.abs();
      _pointerOrigin = null;
      _clearPressedValue();
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    _activePointer = null;
    _pointerOrigin = null;
    _clearPressedValue();
  }

  void _handleHighlightChange(T value, bool highlighted) {
    if (!highlighted) {
      _clearPressedValue(value);
      return;
    }
    // Tap highlight can arrive after a parent drag has already exceeded the
    // pointer slop. Do not let that delayed highlight re-arm a cancelled press.
    if (_activePointer == null || _pointerOrigin != null) {
      _setPressedValue(value);
    }
  }

  void _previewAt(double dx, double width) {
    final value = _valueAt(dx, width);
    if (_isEnabled(value) && value != _dragValue) {
      setState(() {
        _dragValue = value;
        _pressedValue = null;
      });
    }
  }

  void _setPressedValue(T value) {
    if (mounted && _isEnabled(value) && value != _pressedValue) {
      setState(() => _pressedValue = value);
    }
  }

  void _commitValue(T value) {
    if (_isEnabled(value)) {
      widget.onChanged(value);
    }
    _clearPressedValue();
  }

  void _clearPressedValue([T? value]) {
    if (mounted &&
        _pressedValue != null &&
        (value == null || _pressedValue == value)) {
      setState(() => _pressedValue = null);
    }
  }

  T _valueAt(double dx, double width) {
    final index = (dx / (width / widget.values.length)).floor().clamp(
      0,
      widget.values.length - 1,
    );
    return widget.values[index];
  }

  Alignment _alignmentFor(T value) {
    final index = widget.values.indexOf(value);
    if (widget.values.length <= 1) return Alignment.center;
    final x = -1 + (2 * index / (widget.values.length - 1));
    return Alignment(x, 0);
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
            child: Text(
              title,
              style: TextStyle(
                color: DailyUi.secondaryText(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Material(
            color: DailyUi.groupedSurface(context),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: DailyUi.separator(context).withValues(alpha: 0.78),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLeadingIcon extends StatelessWidget {
  const _SettingsLeadingIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = switch (icon) {
      Icons.notifications_outlined ||
      Icons.wb_sunny_outlined ||
      Icons.alarm_outlined ||
      Icons.bug_report_outlined => DailyUi.warning,
      Icons.add_link_outlined ||
      Icons.record_voice_over_outlined ||
      Icons.auto_awesome_outlined ||
      Icons.psychology_outlined => DailyUi.purple,
      Icons.language_outlined ||
      Icons.privacy_tip_outlined ||
      Icons.insights_outlined ||
      Icons.shield_outlined ||
      Icons.fingerprint => DailyUi.success,
      _ => DailyUi.primary,
    };
    return ExcludeSemantics(
      child: DailySettingsIcon(icon: icon, color: color),
    );
  }
}

class _SettingsRowLeading extends StatelessWidget {
  const _SettingsRowLeading(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _SettingsLeadingIcon(icon),
      ),
    );
  }
}

class _SettingsDescription extends StatelessWidget {
  const _SettingsDescription(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final platform = Theme.of(context).platform;
        final maxWidth = constraints.maxWidth;
        if ((platform != TargetPlatform.iOS &&
                platform != TargetPlatform.android) ||
            !maxWidth.isFinite ||
            maxWidth <= 0) {
          return Text(text, softWrap: true);
        }
        final effectiveStyle = DefaultTextStyle.of(context).style;
        final textScaler = MediaQuery.textScalerOf(context);
        final textDirection = Directionality.of(context);
        final locale = Localizations.maybeLocaleOf(context);
        final wrapped = _wrapAtWhitespace(
          text,
          maxWidth: maxWidth,
          style: effectiveStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        );
        return Text(
          wrapped,
          softWrap: true,
          maxLines: null,
          semanticsLabel: text,
        );
      },
    );
  }

  String _wrapAtWhitespace(
    String value, {
    required double maxWidth,
    required TextStyle style,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required Locale? locale,
  }) {
    bool fits(String candidate) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        maxLines: 1,
      )..layout();
      return painter.width <= maxWidth;
    }

    String protectWord(String word) {
      if (!fits(word)) return word;
      return word.runes.map(String.fromCharCode).join('\u2060');
    }

    final output = <String>[];
    for (final paragraph in value.split('\n')) {
      final words = paragraph
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.isEmpty) {
        output.add('');
        continue;
      }
      var line = '';
      for (final word in words) {
        final candidate = line.isEmpty ? word : '$line $word';
        if (line.isEmpty || fits(candidate)) {
          line = candidate;
          continue;
        }
        output.add(line.split(' ').map(protectWord).join(' '));
        line = word;
      }
      output.add(line.split(' ').map(protectWord).join(' '));
    }
    return output.join('\n');
  }
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog({required this.email});

  final String email;

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reproductionController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _reproductionController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: DailyUi.isDesktop ? 40 : 14,
        vertical: DailyUi.isDesktop ? 32 : 18,
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      title: Row(
        children: [
          const DailySettingsIcon(
            icon: Icons.bug_report_outlined,
            color: DailyUi.warning,
          ),
          const SizedBox(width: 10),
          Text(
            context.tr('버그 제보'),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DailyInfoCallout(
                  icon: Icons.lock_outline_rounded,
                  title: context.tr('연락처 보호'),
                  text: context.tr(
                    'Google 계정 이메일 {email}을 제보 연락처로 수집합니다. 이메일은 공개 GitHub 이슈에 표시되지 않고 Daily 서버에 비공개로 저장됩니다.',
                    args: {'email': widget.email},
                  ),
                ),
                const SizedBox(height: 8),
                DailyInfoCallout(
                  icon: Icons.public_outlined,
                  color: DailyUi.warning,
                  text: context.tr(
                    '작성한 제보 내용은 공개 GitHub 이슈로 등록됩니다. 개인정보를 입력하지 마세요.',
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  key: const ValueKey('bug-report-title'),
                  controller: _titleController,
                  label: context.tr('제목'),
                  icon: Icons.title_rounded,
                  maxLength: 120,
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                _field(
                  key: const ValueKey('bug-report-description'),
                  controller: _descriptionController,
                  label: context.tr('문제 설명'),
                  icon: Icons.description_outlined,
                  maxLength: 4000,
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 10),
                _field(
                  key: const ValueKey('bug-report-reproduction'),
                  controller: _reproductionController,
                  label: context.tr('재현 방법'),
                  icon: Icons.format_list_numbered_rounded,
                  maxLength: 4000,
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 10),
                _field(
                  key: const ValueKey('bug-report-expected'),
                  controller: _expectedController,
                  label: context.tr('예상 동작'),
                  icon: Icons.check_circle_outline_rounded,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                _field(
                  key: const ValueKey('bug-report-actual'),
                  controller: _actualController,
                  label: context.tr('실제 동작'),
                  icon: Icons.error_outline_rounded,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(88, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(context.tr('취소')),
        ),
        FilledButton.icon(
          key: const ValueKey('submit-bug-report'),
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(context.tr('GitHub 이슈 등록')),
          style: FilledButton.styleFrom(
            backgroundColor: DailyUi.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(150, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int maxLength,
    int minLines = 1,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        fillColor: DailyUi.groupedSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DailyUi.separator(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DailyUi.separator(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DailyUi.primary, width: 1.5),
        ),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? context.tr('필수 입력 항목입니다.')
          : null,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      BugReportDraft(
        title: _titleController.text,
        description: _descriptionController.text,
        reproductionSteps: _reproductionController.text,
        expectedBehavior: _expectedController.text,
        actualBehavior: _actualController.text,
      ),
    );
  }
}

class _AppVersionInfo {
  const _AppVersionInfo({
    required this.version,
    this.buildNumber = '',
    this.packageName = '',
  });

  final String version;
  final String buildNumber;
  final String packageName;
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile({required this.versionInfo, required this.onDoubleTap});

  final Future<_AppVersionInfo> versionInfo;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppVersionInfo>(
      future: versionInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version ?? '확인 중';
        final buildNumber = info?.buildNumber.trim() ?? '';
        final versionLabel = buildNumber.isEmpty
            ? version
            : '$version ($buildNumber)';
        return GestureDetector(
          key: const ValueKey('daily-version-github-link'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: onDoubleTap,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const _SettingsLeadingIcon(Icons.info_outline),
            title: Text(context.tr('Daily 버전')),
            subtitle: _SettingsDescription(
              context.tr(
                '버전 {version} · 더블 클릭하여 Github 확인하기',
                args: {'version': versionLabel},
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DefaultRemindersTile extends StatelessWidget {
  const _DefaultRemindersTile({
    required this.title,
    required this.values,
    required this.presets,
    required this.onChanged,
    required this.onCustom,
  });

  final String title;
  final List<int> values;
  final List<int> presets;
  final ValueChanged<List<int>> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final selected = values.toSet();
    final options = normalizeReminderMinutes([...presets, ...values]);
    final summary = values.isEmpty
        ? context.tr('새 일정에 알림을 자동으로 추가하지 않습니다.')
        : values.map((minutes) => _minutesLabel(context, minutes)).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SettingsRowLeading(Icons.add_alert_outlined),
              const SizedBox(width: 16),
              Expanded(child: Text(title)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: Text(context.tr('없음')),
                      selected: values.isEmpty,
                      onSelected: (_) => onChanged(const <int>[]),
                    ),
                    for (final minutes in options)
                      FilterChip(
                        label: Text(_minutesLabel(context, minutes)),
                        selected: selected.contains(minutes),
                        onSelected: (enabled) {
                          final next = values.toSet();
                          enabled ? next.add(minutes) : next.remove(minutes);
                          onChanged(normalizeReminderMinutes(next));
                        },
                      ),
                    IconButton.outlined(
                      tooltip: context.tr('기본 알림 직접 입력'),
                      onPressed: onCustom,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.title,
    required this.subtitle,
    required this.hour,
    required this.minute,
    required this.use24HourTime,
    required this.onChanged,
    this.icon = Icons.schedule_outlined,
  });

  final String title;
  final String subtitle;
  final int hour;
  final int minute;
  final bool use24HourTime;
  final ValueChanged<TimeOfDay> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: hour, minute: minute);
    final label = _timeLabel(hour, minute, use24HourTime: use24HourTime);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _SettingsLeadingIcon(icon),
      title: Text(title),
      subtitle: _SettingsDescription('$subtitle · $label'),
      trailing: IconButton(
        tooltip: context.tr('시간 선택'),
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: use24HourTime),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
        icon: const Icon(Icons.schedule),
      ),
    );
  }
}

class _TimeFormatTile extends StatelessWidget {
  const _TimeFormatTile({required this.use24HourTime, required this.onChanged});

  final bool use24HourTime;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveSettingsControlRow(
      icon: Icons.access_time_outlined,
      title: context.tr('시간 표시 방식'),
      description: context.tr('시간 선택 화면의 기본 표시 방식을 정합니다.'),
      controlWidth: 116,
      optionCount: 2,
      control: _ThreeWayCapsule<bool>(
        key: const ValueKey('time-format-slider'),
        values: const [false, true],
        selected: use24HourTime,
        labelFor: (value) => value ? '24h' : '12h',
        onChanged: onChanged,
      ),
    );
  }
}

class _DdayOffsetsTile extends StatelessWidget {
  const _DdayOffsetsTile({
    required this.offsets,
    required this.onChanged,
    required this.onCustom,
  });

  final List<int> offsets;
  final ValueChanged<List<int>> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final selected = offsets.toSet();
    const presets = [-30, -14, -7, -3, -1, 0];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SettingsRowLeading(Icons.flag_outlined),
              const SizedBox(width: 16),
              Expanded(child: Text(context.tr('D-day 알림'))),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'D-day 표시가 켜진 일정에 적용합니다.',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final offset in presets)
                      FilterChip(
                        label: Text(_ddayLabel(offset)),
                        selected: selected.contains(offset),
                        onSelected: (checked) {
                          final next = {...selected};
                          if (checked) {
                            next.add(offset);
                          } else {
                            next.remove(offset);
                          }
                          onChanged(next.toList()..sort());
                        },
                      ),
                    ActionChip(
                      label: Text(context.tr('직접 입력')),
                      onPressed: onCustom,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.reorderIndex,
    required this.category,
    required this.visible,
    required this.onVisibilityChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final int reorderIndex;
  final EventCategory category;
  final bool visible;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDelayedDragStartListener(
            index: reorderIndex,
            child: Tooltip(
              message: context.tr('길게 눌러 순서 변경'),
              // Let touch long presses start reordering; mouse hover still works.
              triggerMode: TooltipTriggerMode.manual,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const Icon(Icons.drag_indicator, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Tooltip(
            message: '캘린더에 표시',
            child: Checkbox(
              value: visible,
              visualDensity: VisualDensity.compact,
              onChanged: (value) => onVisibilityChanged(value ?? true),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(category.colorValue),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      title: Text(
        context.l10n.categoryName(id: category.id, label: category.label),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit == null && onDelete == null)
            Tooltip(
              message: '수정 불가',
              child: Icon(
                Icons.lock_outline,
                color: Theme.of(context).disabledColor,
              ),
            )
          else ...[
            if (onEdit != null)
              IconButton(
                tooltip: context.tr('분류 수정'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            if (onDelete != null)
              IconButton(
                tooltip: context.tr('분류 삭제'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ],
      ),
    );
  }
}

class _GoogleDriveSyncSettings extends StatelessWidget {
  const _GoogleDriveSyncSettings({
    required this.email,
    required this.sessionConnected,
    required this.busy,
    required this.message,
    required this.onConnect,
    required this.onBackup,
    required this.onRestore,
    required this.canCancelConnection,
    required this.onCancelConnection,
    required this.onDisconnect,
    required this.hasDailyAccount,
    required this.onDeleteDailyAccount,
  });

  final String? email;
  final bool sessionConnected;
  final bool busy;
  final String message;
  final VoidCallback onConnect;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final bool canCancelConnection;
  final VoidCallback onCancelConnection;
  final VoidCallback onDisconnect;
  final bool hasDailyAccount;
  final VoidCallback onDeleteDailyAccount;

  @override
  Widget build(BuildContext context) {
    final linked = email != null;
    final connecting = busy && !sessionConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const _SettingsLeadingIcon(Icons.account_circle_outlined),
          title: Text(context.tr('Google 계정')),
          subtitle: _SettingsDescription(
            linked ? email! : context.tr('Google 로그인 시 Daily 계정에 연결됩니다.'),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const _SettingsLeadingIcon(Icons.cloud_sync_outlined),
          title: Text(context.tr('Google Drive 동기화')),
          subtitle: _SettingsDescription(
            sessionConnected
                ? context.tr('이 계정의 Google Drive AppData에 일정을 백업하고 복원합니다.')
                : linked
                ? context.tr('Google 인증 세션이 없습니다. 다시 연결하면 자동 동기화가 재개됩니다.')
                : context.tr('Google 로그인 시 Drive AppData 권한도 함께 승인합니다.'),
          ),
        ),
        Row(
          key: const ValueKey('google-drive-backup-restore-row'),
          children: [
            Expanded(
              child: _SettingsActionButton(
                key: const ValueKey('google-drive-primary-action'),
                onPressed: busy
                    ? null
                    : (sessionConnected ? onBackup : onConnect),
                icon: sessionConnected
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_outlined,
                label: context.tr(
                  connecting
                      ? 'Google 연결 중'
                      : sessionConnected
                      ? '백업'
                      : linked
                      ? 'Google 다시 연결'
                      : 'Google로 계속',
                ),
                busy: busy,
                filled: true,
              ),
            ),
            if (sessionConnected) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _SettingsActionButton(
                  key: const ValueKey('google-drive-restore-action'),
                  onPressed: busy ? null : onRestore,
                  icon: Icons.cloud_download_outlined,
                  label: context.tr('복원'),
                ),
              ),
            ],
          ],
        ),
        if (canCancelConnection) ...[
          const SizedBox(height: 8),
          _SettingsActionButton(
            onPressed: onCancelConnection,
            icon: Icons.close_rounded,
            label: context.tr('연결 취소'),
          ),
        ],
        const SizedBox(height: 8),
        if (linked)
          _SettingsActionButton(
            onPressed: busy ? null : onDisconnect,
            icon: Icons.link_off_outlined,
            label: context.tr('Google 연동 해지'),
          ),
        if (linked) const SizedBox(height: 8),
        _SettingsActionButton(
          onPressed: busy ? null : onDeleteDailyAccount,
          icon: Icons.person_remove_outlined,
          label: context.tr(hasDailyAccount ? 'Daily 계정 탈퇴' : '로컬 데이터 초기화'),
          destructive: true,
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            context.tr(message),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ],
    );
  }
}

class _AppleSignInSettings extends StatelessWidget {
  const _AppleSignInSettings({
    required this.account,
    required this.busy,
    required this.message,
    required this.onSignIn,
    required this.onDisconnect,
  });

  final AppleAccount? account;
  final bool busy;
  final String message;
  final VoidCallback onSignIn;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final connected = account != null;
    final title = connected
        ? account!.displayName ?? account!.email ?? context.tr('Apple로 로그인됨')
        : context.tr('Apple 로그인');
    final subtitle = connected
        ? [
            if (account!.email != null) account!.email!,
            context.tr('Daily 계정에 연결된 Apple 로그인입니다.'),
          ].join('\n')
        : context.tr('Apple 로그인만으로 Daily를 사용할 수 있습니다.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const _SettingsLeadingIcon(Icons.apple),
          title: Text(title),
          subtitle: _SettingsDescription(subtitle),
        ),
        if (!connected)
          Row(
            children: [
              Expanded(
                child: _SettingsActionButton(
                  key: const ValueKey('apple-sign-in-action'),
                  onPressed: busy ? null : onSignIn,
                  icon: Icons.apple,
                  label: context.tr('Apple로 계속'),
                  busy: busy,
                  filled: true,
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        if (connected) ...[
          const SizedBox(height: 8),
          _SettingsActionButton(
            onPressed: busy ? null : onDisconnect,
            icon: Icons.link_off_outlined,
            label: context.tr('Apple 연동 해지'),
          ),
        ],
        if (message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            context.tr(message),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ],
    );
  }
}

class _DailyAccountStatus extends StatelessWidget {
  const _DailyAccountStatus({required this.account});

  final DailyAccount? account;

  @override
  Widget build(BuildContext context) {
    final providers = [
      if (account?.appleAccount != null) 'Apple',
      if (account?.googleAccount != null) 'Google',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const _SettingsLeadingIcon(Icons.person_outline),
      title: Text(context.tr('Daily 계정')),
      subtitle: _SettingsDescription(
        providers.isEmpty
            ? context.tr('Apple 또는 Google 계정을 연결할 수 있습니다.')
            : context.tr(
                '{providers} 로그인 연결됨',
                args: {'providers': providers.join(' · ')},
              ),
      ),
    );
  }
}

class _AccountLogoutButton extends StatelessWidget {
  const _AccountLogoutButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SettingsActionButton(
      onPressed: busy ? null : onPressed,
      icon: Icons.logout_rounded,
      label: context.tr('로그아웃'),
      busy: busy,
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
    this.busy = false,
    this.filled = false,
    this.destructive = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool filled;
  final bool destructive;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveForeground =
        foregroundColor ??
        (destructive
            ? DailyUi.destructive
            : filled
            ? Colors.white
            : DailyUi.primary);
    final effectiveBackground =
        backgroundColor ?? (filled ? DailyUi.primary : Colors.transparent);
    final buttonIcon = busy
        ? SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveForeground,
            ),
          )
        : Icon(icon, size: 19);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final padding = const EdgeInsets.symmetric(horizontal: 14);

    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton.icon(
              onPressed: busy ? null : onPressed,
              icon: buttonIcon,
              label: _SettingsActionLabel(label),
              style: FilledButton.styleFrom(
                backgroundColor: effectiveBackground,
                foregroundColor: effectiveForeground,
                disabledBackgroundColor: effectiveBackground.withValues(
                  alpha: 0.46,
                ),
                disabledForegroundColor: effectiveForeground.withValues(
                  alpha: 0.7,
                ),
                padding: padding,
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              onPressed: busy ? null : onPressed,
              icon: buttonIcon,
              label: _SettingsActionLabel(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: effectiveForeground,
                disabledForegroundColor: effectiveForeground.withValues(
                  alpha: 0.42,
                ),
                padding: padding,
                side: BorderSide(
                  color: destructive
                      ? DailyUi.destructive.withValues(alpha: 0.72)
                      : DailyUi.separator(context),
                ),
                shape: shape,
              ),
            ),
    );
  }
}

class _SettingsActionLabel extends StatelessWidget {
  const _SettingsActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile({required this.notifier});

  final ValueNotifier<GoogleDriveSyncStatus> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleDriveSyncStatus>(
      valueListenable: notifier,
      builder: (context, status, _) {
        final lastSyncedAt = status.lastSyncedAt;
        final error = status.error;
        final message = context.tr(status.message);
        final syncing = status.syncing;
        final subtitle = [
          if (lastSyncedAt != null)
            context.tr(
              '마지막 성공: {time}',
              args: {'time': _formatDateTime(context, lastSyncedAt)},
            ),
          if (message.isNotEmpty) message,
          if (error != null && error.isNotEmpty) context.tr(error),
        ].join('\n');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SettingsLeadingIcon(
            syncing ? Icons.sync : Icons.cloud_done_outlined,
          ),
          title: Text(context.tr('동기화 상태')),
          subtitle: _SettingsDescription(
            subtitle.isEmpty ? context.tr('아직 동기화 기록이 없습니다.') : subtitle,
          ),
        );
      },
    );
  }
}

Future<EventCategory?> _showCategoryDialog(
  BuildContext context, {
  EventCategory? initialCategory,
}) async {
  return showDialog<EventCategory>(
    context: context,
    builder: (context) => _CategoryDialog(initialCategory: initialCategory),
  );
}

Future<int?> _showNumberDialog({
  required BuildContext context,
  required String title,
  required String label,
  required int initialValue,
}) async {
  return showDialog<int>(
    context: context,
    builder: (context) =>
        _NumberDialog(title: title, label: label, initialValue: initialValue),
  );
}

Future<String?> _showPinSetupDialog({
  required BuildContext context,
  required String title,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _PinSetupDialog(title: title),
  );
}

Future<bool?> _showPinVerificationDialog({
  required BuildContext context,
  required int? expectedLength,
  required Future<bool> Function(String pin) verifier,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _PinVerificationDialog(
      expectedLength: expectedLength,
      verifier: verifier,
    ),
  );
}

Widget _settingsDialogTitle(
  String title,
  IconData icon, {
  Color color = DailyUi.primary,
}) {
  return Row(
    children: [
      DailySettingsIcon(icon: icon, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    ],
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.initialCategory});

  final EventCategory? initialCategory;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _controller;
  late int _selectedColor;
  late final List<int> _colorValues;

  bool get _editing => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    final initialCategory = widget.initialCategory;
    _controller = TextEditingController(text: initialCategory?.label ?? '');
    _selectedColor =
        initialCategory?.colorValue ?? _SettingsPageState._categoryColors.first;
    _colorValues = {
      _selectedColor,
      ..._SettingsPageState._categoryColors,
    }.toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _settingsDialogTitle(
        context.tr(_editing ? '분류 수정' : '분류 추가'),
        _editing ? Icons.edit_outlined : Icons.add_rounded,
        color: DailyUi.purple,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.initialCategory?.locked != true,
              enabled: widget.initialCategory?.locked != true,
              decoration: InputDecoration(
                labelText: context.tr('이름'),
                prefixIcon: const Icon(Icons.label_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('색상'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final colorValue in _colorValues)
                  SizedBox.square(
                    dimension: 40,
                    child: ChoiceChip(
                      selected: _selectedColor == colorValue,
                      label: const SizedBox.shrink(),
                      labelPadding: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      showCheckmark: false,
                      clipBehavior: Clip.antiAlias,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(colorValue),
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedColor = colorValue),
                    ),
                  ),
                Tooltip(
                  message: '사용자 지정 색상',
                  child: SizedBox.square(
                    dimension: 40,
                    child: ChoiceChip(
                      selected: false,
                      label: const SizedBox.shrink(),
                      labelPadding: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      showCheckmark: false,
                      clipBehavior: Clip.antiAlias,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.cyan,
                              Colors.blue,
                              Colors.purple,
                              Colors.red,
                            ],
                          ),
                        ),
                      ),
                      onSelected: (_) async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 200),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        final color = await showDialog<int>(
                          context: context,
                          builder: (context) =>
                              _RgbColorDialog(initialColor: _selectedColor),
                        );
                        if (color == null || !mounted) {
                          return;
                        }
                        setState(() {
                          if (!_colorValues.contains(color)) {
                            _colorValues.add(color);
                          }
                          _selectedColor = color;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          child: Text(context.tr('취소')),
        ),
        FilledButton(
          onPressed: () {
            final label = _controller.text.trim();
            if (label.isEmpty) {
              return;
            }
            FocusManager.instance.primaryFocus?.unfocus();
            final initialCategory = widget.initialCategory;
            final nextCategory =
                initialCategory == null ||
                    (initialCategory.id != EventCategory.basic.id &&
                        initialCategory.id != EventCategory.holiday.id)
                ? EventCategory.custom(label: label, colorValue: _selectedColor)
                : initialCategory.copyWith(
                    label: label,
                    colorValue: _selectedColor,
                  );
            Navigator.of(context).pop(nextCategory);
          },
          style: FilledButton.styleFrom(
            backgroundColor: DailyUi.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(context.tr(_editing ? '저장' : '추가')),
        ),
      ],
    );
  }
}

class _RgbColorDialog extends StatefulWidget {
  const _RgbColorDialog({required this.initialColor});

  final int initialColor;

  @override
  State<_RgbColorDialog> createState() => _RgbColorDialogState();
}

class _RgbColorDialogState extends State<_RgbColorDialog> {
  late final List<int> _channels;
  late final List<TextEditingController> _controllers;
  late HSVColor _hsv;

  int get _colorValue =>
      0xff000000 | (_channels[0] << 16) | (_channels[1] << 8) | _channels[2];

  @override
  void initState() {
    super.initState();
    _channels = [
      (widget.initialColor >> 16) & 0xff,
      (widget.initialColor >> 8) & 0xff,
      widget.initialColor & 0xff,
    ];
    _controllers = [
      for (final value in _channels) TextEditingController(text: '$value'),
    ];
    _hsv = HSVColor.fromColor(Color(_colorValue));
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final pickerWidth = (screenSize.width - 128).clamp(200.0, 360.0);
    final maxContentHeight = screenSize.height * 0.62;
    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _settingsDialogTitle(
        context.tr('사용자 지정 색상'),
        Icons.palette_outlined,
        color: DailyUi.purple,
      ),
      content: SizedBox(
        width: pickerWidth,
        height: maxContentHeight,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _colorPalette(pickerWidth),
              const SizedBox(height: 14),
              for (var index = 0; index < 3; index++)
                _channelRow(index, const ['R', 'G', 'B'][index]),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('취소')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_colorValue),
          style: FilledButton.styleFrom(
            backgroundColor: DailyUi.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(context.tr('적용')),
        ),
      ],
    );
  }

  Widget _colorPalette(double width) {
    final size = Size(width, 180);
    return GestureDetector(
      key: const Key('category-color-palette'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _setPaletteColor(details.localPosition, size),
      onPanStart: (details) => _setPaletteColor(details.localPosition, size),
      onPanUpdate: (details) => _setPaletteColor(details.localPosition, size),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Colors.purple,
                        Colors.red,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.transparent, Colors.black],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (_hsv.hue / 360 * size.width - 8).clamp(
                  0,
                  size.width - 16,
                ),
                top: (_paletteVerticalPosition * size.height - 8).clamp(
                  0,
                  size.height - 16,
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(_colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _paletteVerticalPosition {
    if (_hsv.value >= 0.999 && _hsv.saturation < 0.999) {
      return _hsv.saturation / 2;
    }
    return 0.5 + (1 - _hsv.value) / 2;
  }

  void _setPaletteColor(Offset position, Size size) {
    final hue = (position.dx / size.width).clamp(0.0, 1.0) * 360;
    final vertical = (position.dy / size.height).clamp(0.0, 1.0);
    final saturation = vertical <= 0.5 ? vertical * 2 : 1.0;
    final value = vertical <= 0.5 ? 1.0 : (1 - vertical) * 2;
    _applyHsv(HSVColor.fromAHSV(1, hue, saturation, value));
  }

  void _applyHsv(HSVColor value) {
    final color = value.toColor();
    setState(() {
      _hsv = value;
      _channels[0] = (color.r * 255).round();
      _channels[1] = (color.g * 255).round();
      _channels[2] = (color.b * 255).round();
      for (var index = 0; index < 3; index++) {
        _controllers[index].text = '${_channels[index]}';
      }
    });
  }

  void _syncHsvFromChannels() {
    _hsv = HSVColor.fromColor(Color(_colorValue));
  }

  Widget _channelRow(int index, String label) {
    return Row(
      children: [
        SizedBox(width: 22, child: Text(label)),
        Expanded(
          child: Slider(
            value: _channels[index].toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: '${_channels[index]}',
            onChanged: (value) {
              final channel = value.round();
              setState(() {
                _channels[index] = channel;
                _controllers[index].text = '$channel';
                _syncHsvFromChannels();
              });
            },
          ),
        ),
        SizedBox(
          width: 58,
          child: TextField(
            controller: _controllers[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: '', isDense: true),
            onChanged: (value) {
              final channel = int.tryParse(value);
              if (channel == null) {
                return;
              }
              setState(() {
                _channels[index] = channel.clamp(0, 255).toInt();
                _syncHsvFromChannels();
              });
            },
            onSubmitted: (_) {
              _controllers[index].text = '${_channels[index]}';
            },
          ),
        ),
      ],
    );
  }
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  final String title;
  final String label;
  final int initialValue;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _settingsDialogTitle(
        widget.title,
        Icons.numbers_rounded,
        color: DailyUi.success,
      ),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.pin_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          child: Text(context.tr('취소')),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(_controller.text.trim());
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop(value);
          },
          style: FilledButton.styleFrom(
            backgroundColor: DailyUi.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(context.tr('적용')),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog({required this.title});

  final String title;

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  var _pin = '';
  String? _firstPin;
  var _error = '';

  bool get _confirming => _firstPin != null;

  void _appendDigit(String digit) {
    setState(() {
      _pin += digit;
      _error = '';
    });
  }

  void _removeDigit() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  void _continue() {
    if (!_confirming) {
      if (_pin.length < 4) {
        setState(() => _error = context.tr('PIN은 4자리 이상이어야 합니다.'));
        return;
      }
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _error = '';
      });
      return;
    }
    if (_pin != _firstPin) {
      setState(() {
        _pin = '';
        _error = context.tr('PIN이 일치하지 않습니다. 다시 입력하세요.');
      });
      return;
    }
    Navigator.of(context).pop(_pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _settingsDialogTitle(
        widget.title,
        Icons.lock_outline_rounded,
        color: DailyUi.success,
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _confirming ? 'PIN을 한 번 더 입력하세요.' : '4자리 이상의 PIN을 입력하세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _PinEntryDots(filledCount: _pin.length, showOnlyFilled: true),
            SizedBox(
              height: 22,
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            _SecurePinKeypad(onDigit: _appendDigit, onBackspace: _removeDigit),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('취소')),
        ),
        FilledButton(
          onPressed: _continue,
          style: FilledButton.styleFrom(
            backgroundColor: DailyUi.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(context.tr(_confirming ? '설정' : '다음')),
        ),
      ],
    );
  }
}

class _PinVerificationDialog extends StatefulWidget {
  const _PinVerificationDialog({
    required this.expectedLength,
    required this.verifier,
  });

  final int? expectedLength;
  final Future<bool> Function(String pin) verifier;

  @override
  State<_PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<_PinVerificationDialog> {
  static const _legacyCheckDelay = Duration(milliseconds: 700);

  Timer? _legacyTimer;
  var _pin = '';
  var _checking = false;
  var _error = '';

  @override
  void dispose() {
    _legacyTimer?.cancel();
    super.dispose();
  }

  void _appendDigit(String digit) {
    _legacyTimer?.cancel();
    if (_checking ||
        (widget.expectedLength != null &&
            _pin.length >= widget.expectedLength!)) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (widget.expectedLength != null && _pin.length == widget.expectedLength) {
      unawaited(_verify());
    } else if (widget.expectedLength == null && _pin.length >= 4) {
      _legacyTimer = Timer(_legacyCheckDelay, () => unawaited(_verify()));
    }
  }

  void _removeDigit() {
    _legacyTimer?.cancel();
    if (_checking || _pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _verify() async {
    if (_checking || _pin.isEmpty) {
      return;
    }
    final pin = _pin;
    setState(() => _checking = true);
    final verified = await widget.verifier(pin);
    if (!mounted) {
      return;
    }
    if (verified) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _checking = false;
      _pin = '';
      _error = context.tr('PIN이 일치하지 않습니다.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _settingsDialogTitle(
        context.tr('PIN 확인'),
        Icons.lock_open_rounded,
        color: DailyUi.success,
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('앱 잠금을 해제하려면 PIN을 입력하세요.')),
            const SizedBox(height: 18),
            _PinEntryDots(
              filledCount: _pin.length,
              expectedCount: widget.expectedLength,
            ),
            SizedBox(
              height: 22,
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            _SecurePinKeypad(
              enabled: !_checking,
              onDigit: _appendDigit,
              onBackspace: _removeDigit,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: Text(context.tr('취소')),
        ),
      ],
    );
  }
}

class _PinEntryDots extends StatelessWidget {
  const _PinEntryDots({
    required this.filledCount,
    this.expectedCount,
    this.showOnlyFilled = false,
  });

  final int filledCount;
  final int? expectedCount;
  final bool showOnlyFilled;

  @override
  Widget build(BuildContext context) {
    final count = showOnlyFilled
        ? filledCount
        : expectedCount ?? (filledCount > 6 ? filledCount : 6);
    return Wrap(
      key: const ValueKey('pin-entry-dots'),
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: List.generate(count, (index) {
        final filled = index < filledCount;
        return Container(
          key: ValueKey('pin-entry-dot-$index'),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: filled
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _SecurePinKeypad extends StatelessWidget {
  const _SecurePinKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        for (final digit in digits)
          digit.isEmpty
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: enabled ? () => onDigit(digit) : null,
                  child: Text(
                    digit,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
        IconButton(
          tooltip: context.tr('한 자리 지우기'),
          onPressed: enabled ? onBackspace : null,
          icon: const Icon(Icons.backspace_outlined),
        ),
      ],
    );
  }
}

String _minutesLabel(BuildContext context, int minutes) {
  if (minutes == 0) {
    return context.tr('정시');
  }
  if (minutes < 60) {
    return context.tr('{count}분 전', args: {'count': minutes});
  }
  if (minutes % 1440 == 0) {
    return context.tr('{count}일 전', args: {'count': minutes ~/ 1440});
  }
  if (minutes % 60 == 0) {
    return context.tr('{count}시간 전', args: {'count': minutes ~/ 60});
  }
  return context.tr('{count}분 전', args: {'count': minutes});
}

String _ddayLabel(int offset) {
  if (offset == 0) {
    return 'D-day';
  }
  return offset < 0 ? 'D$offset' : 'D+$offset';
}

String _timeLabel(int hour, int minute, {required bool use24HourTime}) {
  final paddedMinute = minute.toString().padLeft(2, '0');
  if (use24HourTime) {
    return '${hour.toString().padLeft(2, '0')}:$paddedMinute';
  }
  final period = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$period $displayHour:$paddedMinute';
}

String _formatDateTime(BuildContext context, DateTime value) {
  return DateFormat.yMMMd(
    context.l10n.locale.toLanguageTag(),
  ).add_Hm().format(value);
}
