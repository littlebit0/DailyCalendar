import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = 'student@example.com';
const _saveFailure = '선택을 저장하지 못했습니다. 다시 시도해 주세요.';
const _briefingFailure =
    '아침 브리핑 알림 예약을 바꾸지 못했습니다. 알림 권한을 확인한 뒤 다시 시도해 주세요.';

class _Settings extends SettingsRepository {
  _Settings({required super.preferences});

  bool failSave = false;

  @override
  Future<void> save(
    AppSettings settings, {
    bool markSyncPending = true,
    AppSettings? changedFrom,
  }) async {
    if (failSave) throw StateError('settings storage unavailable');
    await super.save(
      settings,
      markSyncPending: markSyncPending,
      changedFrom: changedFrom,
    );
  }
}

class _Auth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async =>
      const GoogleDriveAccount(email: _email);

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async => throw const GoogleDriveAuthException(
    'Google Drive 연결 응답 시간이 초과되었습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
    timedOut: true,
  );
}

class _Drive extends Fake implements GoogleDriveSyncService {
  @override
  final statusNotifier = ValueNotifier(const GoogleDriveSyncStatus());

  @override
  Future<void> queueSettingsBackup() async {}
}

class _Notifications implements NotificationService {
  bool failBriefing = false;
  var scheduleBriefingCalls = 0;

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {
    scheduleBriefingCalls++;
    if (failBriefing) throw StateError('notification permission denied');
  }

  @override
  Future<void> cancelMorningBriefing() async {
    if (failBriefing) throw StateError('notification permission denied');
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {}

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<String> permissionSummary() async => '테스트 권한';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily',
      version: '4.1.0',
      buildNumber: '410',
      buildSignature: '',
    );
  });

  Future<(_Settings, _Notifications)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _Settings(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.saveGoogleAccount(const GoogleAccount(email: _email));
    final notifications = _Notifications();
    final drive = _Drive();
    addTearDown(drive.statusNotifier.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          googleDriveAuthServiceProvider.overrideWithValue(_Auth()),
          googleDriveSyncServiceProvider.overrideWithValue(drive),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (settings, notifications);
  }

  Future<void> open(WidgetTester tester, String destination) async {
    await tester.tap(find.byKey(ValueKey('$destination-settings-navigation')));
    await tester.pumpAndSettle();
  }

  testWidgets('bug report shows a Google auth failure and keeps the draft', (
    tester,
  ) async {
    await pump(tester);
    await open(tester, 'about');
    await tester.tap(find.text('버그 제보'));
    await tester.pumpAndSettle();
    for (final field in [
      'title',
      'description',
      'reproduction',
      'expected',
      'actual',
    ]) {
      await tester.enterText(
        find.byKey(ValueKey('bug-report-$field')),
        '입력 $field',
      );
    }
    await tester.tap(find.text('제보 보내기'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Google Drive 연결 응답 시간이 초과되었습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('버그 제보'));
    await tester.pumpAndSettle();
    expect(find.text('입력 title'), findsOneWidget);
  });

  testWidgets('a failed setting save shows a notice and the stored value', (
    tester,
  ) async {
    final (settings, _) = await pump(tester);
    await open(tester, 'appearance');
    final before = settings.load().showLunarDates;
    settings.failSave = true;
    await tester.tap(find.widgetWithText(SwitchListTile, '음력 표시'));
    await tester.pumpAndSettle();

    expect(find.text(_saveFailure), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(settings.load().showLunarDates, before);
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '음력 표시'))
          .value,
      before,
    );
  });

  testWidgets('a failed morning briefing schedule shows a notice', (
    tester,
  ) async {
    final (settings, notifications) = await pump(tester);
    await open(tester, 'notification');
    notifications.failBriefing = true;
    await tester.tap(find.widgetWithText(SwitchListTile, '아침 브리핑'));
    await tester.pumpAndSettle();
    expect(find.text(_briefingFailure), findsOneWidget);
    expect(tester.takeException(), isNull);

    // A failed save does not reach the scheduler.
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    settings.failSave = true;
    final calls = notifications.scheduleBriefingCalls;
    await tester.tap(find.widgetWithText(SwitchListTile, '아침 브리핑'));
    await tester.pumpAndSettle();
    expect(find.text(_saveFailure), findsOneWidget);
    expect(notifications.scheduleBriefingCalls, calls);
  });
}
