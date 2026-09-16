import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/apple_sign_in_service.dart';
import '../../../core/auth/google_account.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/siri/siri_shortcut_installer.dart';
import '../../../core/sync/google_drive_auth_service.dart';
import '../../../core/theme/daily_ui.dart';
import 'analytics_consent_page.dart';
import '../feature_announcements.dart';
import '../../settings/presentation/settings_page.dart';

enum _WelcomeAction { apple, local, googleDrive, permissions, siri }

enum _OnboardingStep {
  welcome,
  analytics,
  siri,
  categories,
  permissions,
  account,
}

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  _WelcomeAction? _busyAction;
  var _message = '';
  var _googleDriveAttempt = 0;
  var _stepIndex = 0;

  bool get _busy => _busyAction != null;

  bool get _supportsAppleExperiences {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  List<_OnboardingStep> get _steps => [
    _OnboardingStep.welcome,
    _OnboardingStep.analytics,
    if (_supportsAppleExperiences) _OnboardingStep.siri,
    _OnboardingStep.categories,
    _OnboardingStep.permissions,
    _OnboardingStep.account,
  ];

  void _advance() {
    if (_stepIndex >= _steps.length - 1) return;
    setState(() {
      _stepIndex += 1;
      _busyAction = null;
      _message = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final appleSignInService = ref.watch(appleSignInServiceProvider);
    final showAppleSignIn = appleSignInService.isSupportedPlatform;
    final canCancelGoogleConnection =
        _busyAction == _WelcomeAction.googleDrive &&
        ref
            .watch(googleDriveAuthServiceProvider)
            .canCancelPendingSignInOnResume;
    final step = _steps[_stepIndex];
    final page = switch (step) {
      _OnboardingStep.welcome => _buildWelcomePage(context),
      _OnboardingStep.analytics => AnalyticsConsentPage(
        key: const ValueKey('onboarding-analytics-consent'),
        step: _stepIndex,
        stepCount: _steps.length,
        onCompleted: _advance,
      ),
      _OnboardingStep.siri => _buildSiriPage(context),
      _OnboardingStep.categories => _buildCategoriesPage(context),
      _OnboardingStep.permissions => _buildPermissionsPage(context),
      _OnboardingStep.account => _buildStartPage(
        context,
        showAppleSignIn: showAppleSignIn,
        canCancelGoogleConnection: canCancelGoogleConnection,
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.045, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(step), child: page),
    );
  }

  Widget _buildWelcomePage(BuildContext context) {
    return Scaffold(
      body: DailyOnboardingFrame(
        step: _stepIndex,
        stepCount: _steps.length,
        kicker: 'DailyCalendar',
        title: context.tr('오늘을 더\n가볍게 정리하세요.'),
        description: context.tr('일정과 할 일을 한곳에서 보고, 필요한 순간에만 알림을 받으세요.'),
        primaryLabel: context.tr('계속'),
        onPrimary: _advance,
        content: ListView(
          padding: const EdgeInsets.only(top: 24),
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: DailyUi.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: DailyUi.primary,
                  size: 49,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 140,
              child: Row(
                children: [
                  Expanded(
                    child: DailyFeatureCard(
                      icon: Icons.view_week_outlined,
                      title: context.tr('한눈에 보는 일정'),
                      description: context.tr('월간, 주간, 일간 보기'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DailyFeatureCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: context.tr('일정과 할 일'),
                      description: context.tr('기록부터 완료까지'),
                      color: DailyUi.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesPage(BuildContext context) {
    return Scaffold(
      body: DailyOnboardingFrame(
        step: _stepIndex,
        stepCount: _steps.length,
        kicker: context.tr('분류'),
        title: context.tr('일정 분류 설정'),
        description: context.tr('사용할 분류를 미리 설정하거나 기본 분류로 시작하세요.'),
        primaryLabel: context.tr('분류 설정하기'),
        onPrimary: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const SettingsPage.categories()),
          );
          if (mounted) _advance();
        },
        secondaryLabel: context.tr('기본으로만 사용'),
        onSecondary: _advance,
        content: Center(
          child: Icon(
            Icons.category_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSiriPage(BuildContext context) {
    return Scaffold(
      body: DailyOnboardingFrame(
        step: _stepIndex,
        stepCount: _steps.length,
        kicker: context.tr('Siri와 Daily'),
        title: context.tr('말 한마디로\n일정을 관리하세요.'),
        description: context.tr('시그널 단축어를 추가하면 Siri에게 일정을 묻거나 추가하고 수정할 수 있어요.'),
        primaryLabel: context.tr('Siri 단축어 추가하기'),
        primaryIcon: Icons.add_link_rounded,
        onPrimary: _busy ? null : _openSiriInstaller,
        secondaryLabel: context.tr('나중에'),
        onSecondary: _busy ? null : _advance,
        busy: _busyAction == _WelcomeAction.siri,
        content: ListView(
          padding: const EdgeInsets.only(top: 22),
          children: [
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: DailyUi.purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: DailyUi.purple,
                  size: 43,
                ),
              ),
            ),
            const SizedBox(height: 24),
            DailyInfoCallout(
              icon: Icons.mic_none_rounded,
              color: DailyUi.purple,
              text: context.tr(
                '예: “시리야 시그널, 내일 오전 9시에 헬스장 일정 추가해줘.”',
              ),
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DailyUi.destructive,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsPage(BuildContext context) {
    return Scaffold(
      body: DailyOnboardingFrame(
        step: _stepIndex,
        stepCount: _steps.length,
        kicker: context.tr('필요한 순간 놓치지 않기'),
        title: context.tr('알림과 알람을\n준비할까요?'),
        description: context.tr(
          '일정 알림과 아침 브리핑을 받으려면 알림 권한이 필요합니다. 지원되는 기기에서는 일정별 알람도 사용할 수 있어요.',
        ),
        primaryLabel: context.tr('알림 및 알람 허용'),
        primaryIcon: Icons.notifications_active_outlined,
        onPrimary: _busy ? null : _requestPermissions,
        secondaryLabel: context.tr('나중에'),
        onSecondary: _busy ? null : _advance,
        busy: _busyAction == _WelcomeAction.permissions,
        content: ListView(
          padding: const EdgeInsets.only(top: 24),
          children: [
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    child: DailyFeatureCard(
                      icon: Icons.notifications_none_rounded,
                      title: context.tr('일정 알림'),
                      description: context.tr('시작 전 알림과 브리핑'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DailyFeatureCard(
                      icon: Icons.alarm_rounded,
                      title: context.tr('일정 알람'),
                      description: context.tr('지원 기기에서 선택 사용'),
                      color: DailyUi.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DailyInfoCallout(
              icon: Icons.tune_rounded,
              text: context.tr('권한은 나중에 설정에서 다시 요청하거나 변경할 수 있습니다.'),
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DailyUi.destructive,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartPage(
    BuildContext context, {
    required bool showAppleSignIn,
    required bool canCancelGoogleConnection,
  }) {
    return Scaffold(
      body: DailyOnboardingFrame(
        step: _stepIndex,
        stepCount: _steps.length,
        kicker: context.tr('마지막 단계'),
        title: context.tr('Daily를 어떻게\n시작할까요?'),
        description: context.tr(
          '계정을 연결하면 기기 간 동기화를 사용할 수 있고, 계정 없이 이 기기에서만 시작할 수도 있어요.',
        ),
        primaryLabel: context.tr('로컬로 시작'),
        primaryIcon: Icons.calendar_today_outlined,
        onPrimary: _busy ? null : _startLocal,
        busy: _busyAction == _WelcomeAction.local,
        content: ListView(
          padding: const EdgeInsets.only(top: 22),
          children: [
            if (showAppleSignIn) ...[
              _OnboardingAccountButton(
                label: context.tr('Apple로 계속'),
                icon: Icons.apple,
                onPressed: _busy ? null : _startWithApple,
                busy: _busyAction == _WelcomeAction.apple,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                borderColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xff3a3a3c)
                    : Colors.black,
              ),
              const SizedBox(height: 11),
            ],
            _OnboardingAccountButton(
              label: _busyAction == _WelcomeAction.googleDrive
                  ? context.tr('Google 연결 중')
                  : context.tr('Google로 계속'),
              customIcon: const _GoogleMark(),
              onPressed: _busy ? null : _connectAndRestore,
              busy: _busyAction == _WelcomeAction.googleDrive,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xff3c4043),
              borderColor: const Color(0xffd7d9dd),
            ),
            if (canCancelGoogleConnection) ...[
              const SizedBox(height: 8),
              DailySecondaryButton(
                label: context.tr('연결 취소'),
                icon: Icons.close_rounded,
                onPressed: _cancelGoogleDriveSignIn,
              ),
            ],
            const SizedBox(height: 16),
            DailyInfoCallout(
              icon: Icons.cloud_outlined,
              text: context.tr(
                'Google 연결은 앱 전용 Drive AppData 백업과 동기화에만 사용하며 일반 Drive 파일은 읽거나 수정하지 않습니다.',
              ),
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DailyUi.secondaryText(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSiriInstaller() async {
    setState(() {
      _busyAction = _WelcomeAction.siri;
      _message = '';
    });
    final opened = await SiriShortcutInstaller.openSignalInstaller();
    if (!mounted) return;
    setState(() => _busyAction = null);
    if (opened) {
      _advance();
    } else {
      setState(() {
        _message = context.tr('시그널 단축어 추가 화면을 열 수 없습니다.');
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _busyAction = _WelcomeAction.permissions;
      _message = '';
    });
    try {
      await ref.read(notificationServiceProvider).initialize();
      await ref.read(alarmServiceProvider).requestAuthorization();
      if (mounted) _advance();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busyAction = null;
          _message = context.tr(
            '권한 설정을 완료하지 못했습니다. 나중에 설정에서 다시 시도할 수 있습니다. ({error})',
            args: {'error': error},
          );
        });
      }
    }
  }

  Future<void> _startWithApple() async {
    setState(() {
      _busyAction = _WelcomeAction.apple;
      _message = context.tr('Apple 로그인 창을 여는 중입니다.');
    });
    try {
      final account = await ref.read(appleSignInServiceProvider).signIn();
      if (account == null) {
        if (mounted) {
          setState(() => _message = context.tr('Apple 로그인이 취소되었습니다.'));
        }
        return;
      }
      if (!mounted) {
        return;
      }
      final restoredGoogleSync = await _restoreLinkedGoogleDriveSync();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = restoredGoogleSync
            ? 'Apple 로그인이 완료되었습니다. 연결된 Google Drive 동기화를 복원했습니다.'
            : 'Apple 로그인이 완료되었습니다.';
      });
      await _completeOnboarding();
    } on AppleSignInException catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _connectAndRestore() async {
    setState(() {
      _busyAction = _WelcomeAction.googleDrive;
      _message = context.tr('Google 로그인 창을 여는 중입니다.');
    });
    try {
      final connected = await _connectGoogleDriveAndRestore(
        cancelMessage: 'Google 로그인이 취소되었습니다.',
      );
      if (connected) {
        await _completeOnboarding();
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<bool> _connectGoogleDriveAndRestore({
    required String cancelMessage,
  }) async {
    final attempt = ++_googleDriveAttempt;
    try {
      final authService = ref.read(googleDriveAuthServiceProvider);
      final account = await authService.signIn(forceAccountSelection: true);
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      if (account == null) {
        if (mounted) {
          setState(() => _message = cancelMessage);
        }
        return false;
      }

      final headers = await authService.authorizationHeaders(
        promptIfNecessary: true,
      );
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
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
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      await syncService.syncPendingChangesNow(
        promptIfNecessary: false,
        restoreAfterBackup: true,
      );
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }

      return true;
    } on UnsupportedError catch (error) {
      if (mounted && _isCurrentGoogleDriveAttempt(attempt)) {
        setState(() => _message = error.message ?? '$error');
      }
    } on Object catch (error) {
      if (mounted && _isCurrentGoogleDriveAttempt(attempt)) {
        setState(() => _message = '$error');
      }
    }
    return false;
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
      final restored = await authService.restorePreviousSignIn();
      if (restored == null || !_sameEmail(restored.email, linkedGoogle.email)) {
        return false;
      }
      final headers = await authService.authorizationHeaders();
      if (headers == null) {
        return false;
      }
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.startListeningOnly(flushPendingChanges: false);
      await syncService.syncPendingChangesNow(restoreAfterBackup: true);
      return true;
    } on Object {
      return false;
    }
  }

  bool _sameEmail(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  bool _isCurrentGoogleDriveAttempt(int attempt) {
    return _googleDriveAttempt == attempt;
  }

  void _cancelGoogleDriveSignIn() {
    if (_busyAction != _WelcomeAction.googleDrive) {
      return;
    }
    final authService = ref.read(googleDriveAuthServiceProvider);
    if (!authService.canCancelPendingSignInOnResume) {
      return;
    }
    authService.cancelPendingSignIn();
    _googleDriveAttempt += 1;
    if (mounted) {
      setState(() {
        _busyAction = null;
        _message = context.tr('Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.');
      });
    }
  }

  Future<void> _startLocal() async {
    setState(() {
      _busyAction = _WelcomeAction.local;
      _message = '';
    });
    try {
      await _completeOnboarding();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final previous = settingsRepository.load();
    await settingsRepository.announcements.acknowledge(
      featureAnnouncements.map((item) => item.id),
    );
    await settingsRepository.save(
      previous.copyWith(onboardingCompleted: true),
      changedFrom: previous,
    );
    if (!mounted) {
      return;
    }
    ref.read(appSettingsProvider.notifier).state = settingsRepository.load();
  }
}

class _OnboardingAccountButton extends StatelessWidget {
  const _OnboardingAccountButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    this.icon,
    this.customIcon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final IconData? icon;
  final Widget? customIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.55),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.65),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.1,
                  color: foregroundColor,
                ),
              )
            else
              customIcon ?? Icon(icon, size: 21),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.39;
    final strokeWidth = size.shortestSide * 0.19;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xff4285f4);
    canvas.drawArc(rect, -0.18, 1.70, false, paint);
    paint.color = const Color(0xff34a853);
    canvas.drawArc(rect, 1.52, 1.14, false, paint);
    paint.color = const Color(0xfffbbc05);
    canvas.drawArc(rect, 2.66, 0.82, false, paint);
    paint.color = const Color(0xffea4335);
    canvas.drawArc(rect, 3.48, 1.48, false, paint);

    final blue = Paint()
      ..color = const Color(0xff4285f4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth / 2,
        radius,
        strokeWidth,
      ),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
