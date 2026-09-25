import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/app_providers.dart';
import '../core/lms/lms_controller.dart';
import '../core/analytics/product_analytics.dart';
import '../core/auth/google_account.dart';
import '../core/security/biometric_auth_service.dart';
import '../core/security/app_lock_privacy_service.dart';
import '../core/settings/app_settings.dart';
import '../core/localization/app_localizations.dart';
import '../core/platform/windows_build_identity.dart';
import '../features/calendar/presentation/month_calendar_page.dart';
import '../features/onboarding/presentation/analytics_consent_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import '../features/onboarding/presentation/update_features_gate.dart';
import '../core/weather/weather_widgets.dart';
import '../core/sync/startup_sync_gate.dart';
import '../core/sync/google_drive_auth_service.dart';
import 'daily_theme.dart';

class DailyApp extends ConsumerWidget {
  const DailyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final analytics = ref.watch(productAnalyticsProvider);
    unawaited(
      AppLockPrivacyService().setEnabled(
        settings.appLockEnabled,
        method: settings.appLockMethod,
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: analytics.consentPromptCompletedListenable,
      builder: (context, consentPromptCompleted, child) => MaterialApp(
        key: ValueKey(
          settings.onboardingCompleted
              ? 'daily-home-'
                    '${consentPromptCompleted ? 'consent-complete' : 'consent-pending'}'
              : 'daily-onboarding',
        ),
        title: defaultTargetPlatform == TargetPlatform.windows
            ? (isWindowsTestEdition ? 'DailyCalendar Test' : 'DailyCalendar')
            : 'Daily',
        debugShowCheckedModeBanner: false,
        locale: localeForLanguage(settings.language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supportedLocales) {
          if (locale == null) return const Locale('en');
          if (locale.languageCode == 'zh') {
            return const Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hant',
            );
          }
          return supportedLocales.firstWhere(
            (supported) => supported.languageCode == locale.languageCode,
            orElse: () => const Locale('en'),
          );
        },
        theme: DailyTheme.light(),
        darkTheme: DailyTheme.dark(),
        themeMode: switch (settings.themeMode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        builder: (context, child) {
          var content = child ?? const SizedBox.shrink();
          if (settings.onboardingCompleted) {
            content = _AppLockGate(
              enabled: settings.appLockEnabled,
              child: WeatherScope(
                controller: ref.watch(weatherControllerProvider),
                child: content,
              ),
            );
          }
          final brightness = Theme.of(context).brightness;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  appTextScaleForPlatform(
                    settings.appTextSize,
                    defaultTargetPlatform,
                  ),
                ),
              ),
              child: content,
            ),
          );
        },
        home: !settings.onboardingCompleted
            ? const WelcomePage()
            : consentPromptCompleted
            ? const _AppHome()
            : AnalyticsConsentPage(onCompleted: () {}),
      ),
    );
  }
}

double appTextScaleForPlatform(AppTextSize size, TargetPlatform platform) {
  if (_usesDesktopAppExperience(platform)) {
    return switch (size) {
      AppTextSize.basic => 1.0,
      AppTextSize.large => 1.15,
      AppTextSize.extraLarge => 1.3,
    };
  }
  return size.scale;
}

bool _usesDesktopAppExperience(TargetPlatform platform) {
  return platform == TargetPlatform.macOS || platform == TargetPlatform.windows;
}

bool shouldAutomaticallyRequestBiometrics(
  TargetPlatform _, {
  bool alreadyAttempted = false,
}) {
  return !alreadyAttempted;
}

class _AppLockGate extends ConsumerStatefulWidget {
  const _AppLockGate({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  ConsumerState<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<_AppLockGate>
    with WidgetsBindingObserver {
  static const _legacyPinCheckDelay = Duration(milliseconds: 700);

  final _biometricAuth = BiometricAuthService();
  final _pinKeyboardFocusNode = FocusNode();
  Timer? _legacyPinTimer;
  String _pin = '';
  int? _pinLength;
  late var _unlocked = !widget.enabled;
  var _checking = false;
  var _error = '';
  var _pinEntryVisible = false;
  var _pinBiometricAttemptedForCurrentLock = false;
  var _systemAuthenticationAttemptedForCurrentLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) {
      unawaited(_prepareLockScreen());
    }
  }

  @override
  void didUpdateWidget(covariant _AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _legacyPinTimer?.cancel();
      _unlocked = true;
      _pin = '';
      _error = '';
      return;
    }
    if (!oldWidget.enabled) {
      // Enabling the lock in Settings should not immediately lock the user out.
      _unlocked = true;
      _systemAuthenticationAttemptedForCurrentLock = false;
      if (ref.read(appSettingsProvider).appLockMethod == AppLockMethod.appPin) {
        unawaited(_loadPinLength());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _legacyPinTimer?.cancel();
    _pinKeyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_checking ||
        AppLockPrivacyService.configurationAuthenticationInProgress) {
      return;
    }
    final settings = ref.read(appSettingsProvider);
    if (widget.enabled &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden)) {
      _lock();
    } else if (widget.enabled && state == AppLifecycleState.resumed) {
      if (_unlocked) {
        return;
      }
      if (settings.appLockMethod == AppLockMethod.noPin) {
        setState(() => _unlocked = true);
      } else if (settings.appLockMethod == AppLockMethod.appPin &&
          settings.appLockBiometricsEnabled &&
          !_pinBiometricAttemptedForCurrentLock) {
        unawaited(_tryPinBiometricAuthentication());
      } else if (settings.appLockMethod == AppLockMethod.system &&
          shouldAutomaticallyRequestBiometrics(
            defaultTargetPlatform,
            alreadyAttempted: _systemAuthenticationAttemptedForCurrentLock,
          )) {
        unawaited(_trySystemAuthentication(automatic: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _unlocked) {
      return widget.child;
    }
    final lockMethod = ref.watch(appSettingsProvider).appLockMethod;

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: true, child: widget.child),
        Scaffold(
          key: const ValueKey('app-lock-screen'),
          body: KeyboardListener(
            focusNode: _pinKeyboardFocusNode,
            autofocus: lockMethod == AppLockMethod.appPin && _pinEntryVisible,
            onKeyEvent: _handlePinKeyEvent,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline, size: 42),
                        const SizedBox(height: 18),
                        Text(
                          switch (lockMethod) {
                            AppLockMethod.noPin => context.tr(
                              '잠금 상태에서는 화면을 볼 수 없습니다.',
                            ),
                            AppLockMethod.appPin when !_pinEntryVisible =>
                              context.tr('잠금 상태입니다.'),
                            AppLockMethod.appPin => context.tr('PIN 입력'),
                            AppLockMethod.system => context.tr('잠금 상태입니다.'),
                          },
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 26),
                        if (lockMethod == AppLockMethod.appPin) ...[
                          if (!_pinEntryVisible) ...[
                            FilledButton.icon(
                              key: const ValueKey('show-pin-entry-button'),
                              onPressed: _checking ? null : _showPinEntry,
                              icon: const Icon(Icons.password_outlined),
                              label: Text(context.tr('비밀번호를 통해 잠금해제')),
                            ),
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ] else ...[
                            _PinDots(filledCount: _pin.length),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 24,
                              child: Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _PinKeypad(
                              enabled: !_checking,
                              onDigit: _appendDigit,
                              onBackspace: _removeDigit,
                            ),
                          ],
                        ] else if (lockMethod == AppLockMethod.system) ...[
                          Text(
                            context.tr(
                              '기기의 Face ID, Touch ID 또는 시스템 비밀번호로 확인합니다.',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _checking
                                ? null
                                : _trySystemAuthentication,
                            icon: const Icon(Icons.lock_open_outlined),
                            label: Text(context.tr('시스템 잠금으로 해제')),
                          ),
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox.shrink(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _prepareLockScreen() async {
    final settings = ref.read(appSettingsProvider);
    if (settings.appLockMethod == AppLockMethod.noPin) {
      if (mounted) {
        setState(() => _unlocked = true);
      }
      return;
    }
    if (settings.appLockMethod == AppLockMethod.appPin) {
      await _loadPinLength();
      if (settings.appLockBiometricsEnabled) {
        await _tryPinBiometricAuthentication();
      }
    }
    if (!mounted) {
      return;
    }
    if (settings.appLockMethod == AppLockMethod.system &&
        shouldAutomaticallyRequestBiometrics(
          defaultTargetPlatform,
          alreadyAttempted: _systemAuthenticationAttemptedForCurrentLock,
        )) {
      await _trySystemAuthentication(automatic: true);
    }
  }

  Future<void> _loadPinLength() async {
    final pinLength = await ref
        .read(settingsRepositoryProvider)
        .appLockPinLength();
    if (!mounted) {
      return;
    }
    setState(() => _pinLength = pinLength);
  }

  void _lock() {
    _legacyPinTimer?.cancel();
    if (mounted) {
      setState(() {
        _pin = '';
        _error = '';
        _checking = false;
        _pinEntryVisible = false;
        _pinBiometricAttemptedForCurrentLock = false;
        _systemAuthenticationAttemptedForCurrentLock = false;
        _unlocked = false;
      });
    }
  }

  void _appendDigit(String digit) {
    _legacyPinTimer?.cancel();
    final expectedLength = _pinLength;
    if (_checking ||
        (expectedLength != null && _pin.length >= expectedLength)) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = '';
    });

    if (expectedLength != null && _pin.length == expectedLength) {
      unawaited(_verifyPin());
      return;
    }
    if (expectedLength == null && _pin.length >= 4) {
      _legacyPinTimer = Timer(_legacyPinCheckDelay, () {
        unawaited(_verifyPin(keepInputOnFailure: true));
      });
    }
  }

  void _showPinEntry() {
    setState(() {
      _pinEntryVisible = true;
      _error = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pinKeyboardFocusNode.requestFocus();
      }
    });
  }

  void _handlePinKeyEvent(KeyEvent event) {
    if (!_usesDesktopAppExperience(defaultTargetPlatform) ||
        !_pinEntryVisible ||
        event is! KeyDownEvent) {
      return;
    }
    final digit = event.character ?? event.logicalKey.keyLabel;
    if (RegExp(r'^\d$').hasMatch(digit)) {
      _appendDigit(digit);
    } else if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _removeDigit();
    }
  }

  void _removeDigit() {
    _legacyPinTimer?.cancel();
    if (_checking || _pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _verifyPin({bool keepInputOnFailure = false}) async {
    if (_checking || _pin.isEmpty) {
      return;
    }
    final submittedPin = _pin;
    setState(() => _checking = true);
    final repository = ref.read(settingsRepositoryProvider);
    final ok = await repository.verifyAppLockPin(submittedPin);
    if (!mounted) {
      return;
    }
    if (ok) {
      if (_pinLength == null) {
        await repository.saveAppLockPin(submittedPin);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _unlocked = true;
        _error = '';
        _checking = false;
      });
    } else {
      setState(() {
        _checking = false;
        _error = keepInputOnFailure
            ? context.tr('PIN을 계속 입력하거나 지워서 다시 입력하세요.')
            : context.tr('PIN이 일치하지 않습니다.');
        if (!keepInputOnFailure) {
          _pin = '';
        }
      });
    }
  }

  Future<void> _trySystemAuthentication({bool automatic = false}) async {
    if (_checking ||
        _unlocked ||
        (automatic && _systemAuthenticationAttemptedForCurrentLock)) {
      return;
    }
    setState(() {
      _checking = true;
      _error = '';
      if (automatic) {
        _systemAuthenticationAttemptedForCurrentLock = true;
      }
    });
    final authenticated = await _biometricAuth.authenticate(
      localizedReason: context.tr('Daily 잠금을 해제하려면 인증이 필요합니다.'),
      allowDeviceCredentials: true,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      if (authenticated) {
        _unlocked = true;
      } else {
        _error = context.tr('시스템 인증을 완료하지 못했습니다.');
      }
    });
  }

  Future<void> _tryPinBiometricAuthentication() async {
    if (_checking || _unlocked || _pinBiometricAttemptedForCurrentLock) {
      return;
    }
    setState(() {
      _checking = true;
      _error = '';
      _pinBiometricAttemptedForCurrentLock = true;
    });
    final authenticated = defaultTargetPlatform == TargetPlatform.macOS
        ? await _biometricAuth.authenticateWithBiometricsOrCompanion(
            localizedReason: context.tr(
              'Touch ID 또는 Apple Watch로 Daily PIN 잠금을 해제합니다.',
            ),
          )
        : await _biometricAuth.authenticate(
            localizedReason: context.tr('Daily PIN 잠금을 생체인식으로 해제합니다.'),
          );
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      if (authenticated) {
        _unlocked = true;
      } else {
        _error = context.tr('생체인식을 완료하지 못했습니다. PIN을 입력해 주세요.');
        _pinEntryVisible = true;
      }
    });
    if (!authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pinKeyboardFocusNode.requestFocus();
        }
      });
    }
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filledCount});

  final int filledCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 13,
      child: Wrap(
        key: const ValueKey('pin-entry-dots'),
        alignment: WrapAlignment.center,
        spacing: 14,
        children: List.generate(
          filledCount,
          (index) => Container(
            key: ValueKey('pin-unlock-dot-$index'),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
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
        Semantics(
          label: '한 자리 지우기',
          button: true,
          child: IconButton(
            onPressed: enabled ? onBackspace : null,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ),
      ],
    );
  }
}

class _AppHome extends ConsumerStatefulWidget {
  const _AppHome();

  @override
  ConsumerState<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<_AppHome>
    with WidgetsBindingObserver {
  static const _siriEventChangesChannel = MethodChannel(
    'daily/siri_event_changes',
  );
  static const _syncRestoreRetryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 8),
  ];

  late final LmsController _lmsController;
  var _servicesStarted = false;
  String? _scheduledLmsOwner;
  late final bool _requiresStartupSync;
  bool _startupGateOpen = false;
  Future<void>? _startupOperation;
  Future<bool>? _syncStartOperation;
  Timer? _syncRestoreRetryTimer;
  var _syncRestoreRetryIndex = 0;
  ValueNotifier<int>? _settingsRevisionNotifier;
  VoidCallback? _settingsRevisionListener;
  Future<void>? _siriChangeProcessing;
  Future<void>? _widgetTodoProcessing;
  StreamSubscription<void>? _widgetTodoChangesSubscription;

  @override
  void initState() {
    super.initState();
    _lmsController = ref.read(lmsControllerProvider);
    _scheduledLmsOwner = ref
        .read(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount
        ?.email;
    _requiresStartupSync =
        ref.read(settingsRepositoryProvider).dailyAccount()?.googleAccount !=
        null;
    _startupGateOpen = !_requiresStartupSync;
    WidgetsBinding.instance.addObserver(this);
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _siriEventChangesChannel.setMethodCallHandler(_handleSiriEventChange);
    }
    final widgetService = ref.read(calendarWidgetServiceProvider);
    if (widgetService.isSupported) {
      _widgetTodoChangesSubscription = ref
          .read(calendarWidgetServiceProvider)
          .todoActionChanges
          .listen((_) => unawaited(_processPendingWidgetTodoActions()));
    }
    unawaited(
      _startLocalNotificationServices().then((_) async {
        await _processPendingSiriEventChanges();
        await _processPendingWidgetTodoActions();
      }),
    );
    if (!_requiresStartupSync) _startSyncIfConnected();
    _refreshCalendarWidgets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lmsController.setForeground(false);
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _siriEventChangesChannel.setMethodCallHandler(null);
    }
    _syncRestoreRetryTimer?.cancel();
    unawaited(_widgetTodoChangesSubscription?.cancel());
    final listener = _settingsRevisionListener;
    final notifier = _settingsRevisionNotifier;
    if (listener != null) {
      notifier?.removeListener(listener);
    }
    super.dispose();
  }

  Future<Object?> _handleSiriEventChange(MethodCall call) async {
    if (call.method != 'eventsChanged' || !mounted) {
      return null;
    }

    await _processPendingSiriEventChanges(showFailure: true);
    return null;
  }

  Future<void> _processPendingSiriEventChanges({bool showFailure = false}) {
    final active = _siriChangeProcessing;
    if (active != null) return active;
    final operation = _processPendingSiriEventChangesImpl(showFailure);
    _siriChangeProcessing = operation;
    return operation.whenComplete(() {
      if (identical(_siriChangeProcessing, operation)) {
        _siriChangeProcessing = null;
      }
    });
  }

  Future<void> _processPendingWidgetTodoActions() {
    final active = _widgetTodoProcessing;
    if (active != null) return active;
    final operation = _processPendingWidgetTodoActionsImpl();
    _widgetTodoProcessing = operation;
    return operation.whenComplete(() {
      if (identical(_widgetTodoProcessing, operation)) {
        _widgetTodoProcessing = null;
      }
    });
  }

  Future<void> _processPendingWidgetTodoActionsImpl() async {
    final widgetService = ref.read(calendarWidgetServiceProvider);
    final actions = await widgetService.pendingTodoActions();
    if (actions.isEmpty) return;

    final repository = ref.read(visibleEventRepositoryProvider);
    final commandService = ref.read(eventCommandServiceProvider);
    final acknowledged = <String>[];
    for (final action in actions) {
      final event = await repository.findById(action.eventId);
      if (event == null || event.isDeleted) {
        acknowledged.add(action.token);
        continue;
      }
      try {
        await commandService.setCompleted(event, action.completed);
        acknowledged.add(action.token);
      } on Object {
        break;
      }
    }
    await widgetService.acknowledgeTodoActions(acknowledged);
    if (acknowledged.isNotEmpty) {
      await widgetService.refresh();
      unawaited(
        ref
            .read(productAnalyticsProvider)
            .record(
              AnalyticsRecord.featureUsed(
                AnalyticsFeature.widget,
                outcome: AnalyticsOutcome.succeeded,
              ),
            )
            .catchError((_) {}),
      );
      ref.invalidate(eventsInRangeProvider);
    }
  }

  Future<void> _processPendingSiriEventChangesImpl(bool showFailure) async {
    try {
      final rawChanges = await _siriEventChangesChannel
          .invokeListMethod<Object?>('pendingChanges');
      if (rawChanges == null || rawChanges.isEmpty) return;
      final changes = rawChanges
          .whereType<Map<Object?, Object?>>()
          .map(_PendingSiriEventChange.fromMap)
          .whereType<_PendingSiriEventChange>()
          .toList();
      if (changes.isEmpty) return;

      ref.invalidate(eventsInRangeProvider);
      final repository = ref.read(visibleEventRepositoryProvider);
      final notificationService = ref.read(notificationServiceProvider);
      final alarmService = ref.read(alarmServiceProvider);
      for (final change in changes) {
        final event = await repository.findById(change.eventId);
        await notificationService.cancelEventReminder(
          change.eventId,
          reminderMinutesBeforeList: {
            ...change.reminderMinutesBefore,
            ...?event?.reminderMinutesBeforeList,
          }.toList(),
        );
        await alarmService.cancelEventAlarm(change.eventId);
        if (event != null && !event.isDeleted) {
          await notificationService.scheduleEventReminder(
            event,
            allowImmediate: true,
          );
          await alarmService.scheduleEventAlarm(event);
        }
      }
      await ref.read(calendarWidgetServiceProvider).refresh();
      await _siriEventChangesChannel.invokeMethod<void>('acknowledgeChanges', {
        'tokens': changes.map((change) => change.token).toList(),
      });
      try {
        await ref.read(googleDriveSyncServiceProvider).syncPendingChangesNow();
      } catch (error, stackTrace) {
        // The event remains sync_status=pending, so Drive retry is independent
        // from the completed local notification/alarm/widget reconciliation.
        debugPrint('Siri event Drive sync deferred: $error\n$stackTrace');
        if (showFailure && mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(context.tr('일정은 저장했으며 클라우드 동기화는 연결 후 재시도됩니다.')),
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Siri event follow-up failed: $error\n$stackTrace');
      if (showFailure && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.tr('일정은 저장했지만 알림 또는 동기화 처리가 보류되었습니다.')),
          ),
        );
      }
    }
  }

  Future<void> _reconcileAllEventSchedules() async {
    final events = await ref.read(eventRepositoryProvider).allEventsForSync();
    final notificationService = ref.read(notificationServiceProvider);
    final alarmService = ref.read(alarmServiceProvider);
    for (final event in events) {
      // App Intents writes outside EventCommandService, so first remove every
      // previous reservation for the event before applying its current state.
      await notificationService.cancelEventReminder(
        event.id,
        reminderMinutesBeforeList: event.reminderMinutesBeforeList,
      );
      await alarmService.cancelEventAlarm(event.id);
      if (event.isDeleted ||
          !event.isVisibleToOwner(
            ref
                .read(settingsRepositoryProvider)
                .dailyAccount()
                ?.googleAccount
                ?.email,
          )) {
        continue;
      }
      await notificationService.scheduleEventReminder(
        event,
        allowImmediate: false,
      );
      await alarmService.scheduleEventAlarm(event);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(productAnalyticsProvider).flush().catchError((_) {}));
    }
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(lmsControllerProvider).setForeground(true);
        _syncRestoreRetryTimer?.cancel();
        _syncRestoreRetryIndex = 0;
        // App Intents update the shared SQLite file outside Drift's active
        // connection, so recreate range streams when Daily returns.
        ref.invalidate(eventsInRangeProvider);
        _processPendingSiriEventChanges();
        _processPendingWidgetTodoActions();
        if (_startupGateOpen) _startSyncIfConnected();
        _refreshCalendarWidgets();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        ref.read(lmsControllerProvider).setForeground(false);
        if (_startupGateOpen && _startupOperation == null) {
          _syncBeforeBackgroundOrExit();
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSettings>(appSettingsProvider, (previous, next) {
      if (previous != next) {
        ref.read(lmsControllerProvider).settingsChanged();
        if (previous?.themeMode != next.themeMode) {
          _refreshCalendarWidgetTheme();
        } else {
          _refreshCalendarWidgets();
        }
      }
    });
    ref.listen(lmsControllerProvider, (_, _) {
      _refreshCalendarWidgets();
    });
    return StartupSyncGate(
      requiredAtStartup: _requiresStartupSync,
      synchronize: _synchronizeStartup,
      onContinue: () {
        _startupGateOpen = true;
        _scheduleSyncRestoreRetry();
        if (_startupOperation == null) unawaited(_refreshAcademicCalendars());
      },
      child: const UpdateFeaturesGate(child: MonthCalendarPage()),
    );
  }

  Future<void> _synchronizeStartup() async {
    final operation = _startupOperation ??= _runStartupSync();
    try {
      await operation;
    } finally {
      if (identical(_startupOperation, operation)) _startupOperation = null;
      if (mounted && _startupGateOpen) _scheduleSyncRestoreRetry();
      if (mounted && _startupGateOpen) unawaited(_refreshAcademicCalendars());
    }
  }

  Future<void> _runStartupSync() async {
    await _tryStartSyncIfConnected(startup: true);
    if (!mounted) return;
    _refreshSettingsState();
    ref.invalidate(eventsInRangeProvider);
    // Prime the actual stream providers used by the initial month/quick view,
    // week and selected-day sidebar, not a separate throwaway database query.
    final monday = ref.read(appSettingsProvider).weekStartsOnMonday;
    final month = ref.read(visibleMonthProvider);
    final selected = ref.read(selectedDateProvider);
    final day = DateTime(selected.year, selected.month, selected.day);
    final first = DateTime(month.year, month.month);
    DateTime weekStart(DateTime date) => date.subtract(
      Duration(days: monday ? date.weekday - 1 : date.weekday % 7),
    );
    final monthStart = weekStart(first);
    final selectedWeekStart = weekStart(day);
    for (final range in [
      CalendarRange(monthStart, monthStart.add(const Duration(days: 42))),
      CalendarRange(
        selectedWeekStart,
        selectedWeekStart.add(const Duration(days: 7)),
      ),
      CalendarRange(day, day.add(const Duration(days: 1))),
    ]) {
      if (!mounted) return;
      final provider = eventsInRangeProvider(range);
      final subscription = ref.listenManual(provider, (_, _) {});
      try {
        await ref.read(provider.future);
      } finally {
        subscription.close();
      }
    }
  }

  void _refreshCalendarWidgets() {
    unawaited(
      ref.read(calendarWidgetServiceProvider).refresh().catchError((_) {}),
    );
  }

  void _refreshCalendarWidgetTheme() {
    unawaited(
      ref.read(calendarWidgetServiceProvider).refreshTheme().catchError((_) {}),
    );
  }

  Future<void> _startSyncIfConnected() async {
    if (_startupOperation != null || !_startupGateOpen) return;
    final activeOperation = _syncStartOperation;
    if (activeOperation != null) {
      await activeOperation;
      return;
    }
    final operation = _tryStartSyncIfConnected();
    _syncStartOperation = operation;
    try {
      final started = await operation;
      if (started) {
        _syncRestoreRetryTimer?.cancel();
        _syncRestoreRetryIndex = 0;
      } else {
        _scheduleSyncRestoreRetry();
      }
    } finally {
      if (identical(_syncStartOperation, operation)) {
        _syncStartOperation = null;
      }
      if (mounted) unawaited(_refreshAcademicCalendars());
    }
  }

  Future<void> _refreshAcademicCalendars() async {
    if (!mounted) return;
    final lms = ref.read(lmsControllerProvider);
    final foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    lms.setForeground(foreground);
    // After the main Drive phase; it must not hold the startup gate open.
    // The private native browser needs an active application window.
    if (foreground) await lms.refresh();
    if (!mounted) return;
    // Do not instantiate network/import services for users without a subscription.
    try {
      final store = ref.read(settingsRepositoryProvider).academicStore;
      if (!store.load().values.any((subscription) => subscription.enabled)) {
        return;
      }
      await ref.read(academicCalendarServiceProvider).refreshIfDue();
      if (mounted) _refreshSettingsState();
    } on Object {
      // Source errors are reported in academic settings, not as a startup failure.
    }
  }

  Future<bool> _tryStartSyncIfConnected({bool startup = false}) async {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final initialAccount = settingsRepository.dailyAccount();
    void ensureCurrentAccount() {
      final currentAccount = settingsRepository.dailyAccount();
      if (!mounted ||
          (startup &&
              (currentAccount?.id != initialAccount?.id ||
                  currentAccount?.googleAccount?.email !=
                      initialAccount?.googleAccount?.email))) {
        throw const GoogleDriveAuthException('계정이 변경되었습니다.');
      }
    }

    try {
      final auth = ref.read(googleDriveAuthServiceProvider);
      final account = await auth.restorePreviousSignIn();
      ensureCurrentAccount();
      var dailyAccount = settingsRepository.dailyAccount();
      if (account != null && !settingsRepository.hasStoredDailyAccount) {
        // Migrate the pre-Daily-account Google session once. New Apple-only
        // accounts always persist first, so they never attach Google silently.
        await settingsRepository.saveGoogleAccount(
          GoogleAccount(email: account.email, displayName: account.displayName),
        );
        dailyAccount = settingsRepository.dailyAccount();
      }

      final linkedGoogleEmail = dailyAccount?.googleAccount?.email;
      if (linkedGoogleEmail == null) {
        if (startup) {
          throw const GoogleDriveAuthException('Google Drive 연결이 필요합니다.');
        }
        return false;
      }
      if (account != null &&
          linkedGoogleEmail.toLowerCase() != account.email.toLowerCase()) {
        if (startup) throw const GoogleDriveAuthException('계정이 변경되었습니다.');
        return false;
      }

      // This call is always non-interactive. It also restores desktop OAuth
      // tokens when account metadata was temporarily unavailable.
      final headers = await auth.authorizationHeaders();
      ensureCurrentAccount();
      if (headers == null) {
        if (startup) {
          throw const GoogleDriveAuthException('Google Drive 연결이 필요합니다.');
        }
        return false;
      }
      if (startup) {
        _listenForSyncedSettings();
        await ref.read(syncServiceProvider).start();
        ensureCurrentAccount();
        _servicesStarted = true;
      } else {
        _startPostLoginServices();
      }
      return true;
    } on Object {
      if (startup) rethrow;
      // Google Drive sync is optional; local calendar use stays available.
      return false;
    }
  }

  void _scheduleSyncRestoreRetry() {
    if (!mounted ||
        !_startupGateOpen ||
        _startupOperation != null ||
        _servicesStarted ||
        _syncRestoreRetryTimer != null) {
      return;
    }
    final linkedGoogleAccount = ref
        .read(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount;
    if (linkedGoogleAccount == null ||
        _syncRestoreRetryIndex >= _syncRestoreRetryDelays.length) {
      return;
    }
    final delay = _syncRestoreRetryDelays[_syncRestoreRetryIndex++];
    _syncRestoreRetryTimer = Timer(delay, () {
      _syncRestoreRetryTimer = null;
      if (mounted) {
        _startSyncIfConnected();
      }
    });
  }

  void _startPostLoginServices() {
    _listenForSyncedSettings();
    if (_servicesStarted) {
      unawaited(
        Future.microtask(() async {
          await _syncGoogleDriveSnapshot();
        }).catchError((_) {}),
      );
      return;
    }
    _servicesStarted = true;
    unawaited(
      Future.microtask(() async {
        await ref.read(syncServiceProvider).start();
        _refreshSettingsState();
      }).catchError((_) {}),
    );
  }

  void _listenForSyncedSettings() {
    if (_settingsRevisionListener != null) {
      return;
    }
    void listener() => _refreshSettingsState();
    final notifier = ref
        .read(googleDriveSyncServiceProvider)
        .settingsRevisionNotifier;
    _settingsRevisionNotifier = notifier;
    _settingsRevisionListener = listener;
    notifier.addListener(listener);
  }

  void _syncBeforeBackgroundOrExit() {
    unawaited(
      Future.microtask(() async {
        await ref.read(googleDriveSyncServiceProvider).syncPendingChangesNow();
      }).catchError((_) {}),
    );
  }

  Future<void> _syncGoogleDriveSnapshot() async {
    await ref.read(googleDriveSyncServiceProvider).syncOnResume();
    _refreshSettingsState();
  }

  void _refreshSettingsState() {
    if (!mounted) return;
    ref.read(lmsControllerProvider).settingsChanged();
    final owner = ref
        .read(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount
        ?.email;
    if (_scheduledLmsOwner != owner) {
      _scheduledLmsOwner = owner;
      unawaited(_reconcileAllEventSchedules().catchError((_) {}));
    }
    ref.read(appSettingsProvider.notifier).state = ref
        .read(settingsRepositoryProvider)
        .load();
  }

  Future<void> _startLocalNotificationServices() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize();
      final alarmService = ref.read(alarmServiceProvider);
      await alarmService.requestAuthorization();

      final settings = ref.read(appSettingsProvider);
      if (settings.morningBriefingEnabled) {
        await notificationService.scheduleMorningBriefing(
          hour: settings.morningBriefingHour,
          minute: settings.morningBriefingMinute,
        );
      }

      await _reconcileAllEventSchedules();
    } catch (error, stackTrace) {
      debugPrint('Local notification startup failed: $error\n$stackTrace');
    }
  }
}

class _PendingSiriEventChange {
  const _PendingSiriEventChange({
    required this.token,
    required this.eventId,
    required this.reminderMinutesBefore,
  });

  final String token;
  final String eventId;
  final List<int> reminderMinutesBefore;

  static _PendingSiriEventChange? fromMap(Map<Object?, Object?> map) {
    final token = map['token'];
    final eventId = map['eventId'];
    if (token is! String || eventId is! String) return null;
    return _PendingSiriEventChange(
      token: token,
      eventId: eventId,
      reminderMinutesBefore:
          (map['reminderMinutesBefore'] as List<Object?>? ?? const [])
              .whereType<num>()
              .map((value) => value.toInt())
              .toList(),
    );
  }
}
