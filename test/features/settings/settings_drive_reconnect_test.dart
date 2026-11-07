import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = 'student@example.com';
const _syncFailure = '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
const _noSession = 'Google 인증 세션이 없습니다. 다시 연결하면 자동 동기화가 재개됩니다.';

class _Auth extends GoogleDriveAuthService {
  _Auth({required this.connectFails});

  final bool connectFails;

  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;

  @override
  Future<GoogleDriveAccount?> connectToDrive() async {
    if (connectFails) {
      throw const GoogleDriveAuthException('Google Drive 연결을 완료하지 못했습니다.');
    }
    return const GoogleDriveAccount(email: _email);
  }
}

class _Drive extends Fake implements GoogleDriveSyncService {
  @override
  final statusNotifier = ValueNotifier(const GoogleDriveSyncStatus());

  @override
  Future<void> startListeningOnly({bool flushPendingChanges = true}) async {}

  @override
  Future<void> syncPendingChangesNow({
    bool promptIfNecessary = false,
    bool restoreAfterBackup = false,
  }) async {
    throw const GoogleDriveSyncException(_syncFailure);
  }
}

void main() {
  // The account page wraps descriptions on phones; the bug was seen on macOS.
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

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

  Future<_Drive> pumpAndReconnect(
    WidgetTester tester, {
    required bool connectFails,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.saveGoogleAccount(const GoogleAccount(email: _email));
    final drive = _Drive();
    addTearDown(drive.statusNotifier.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          googleDriveAuthServiceProvider.overrideWithValue(
            _Auth(connectFails: connectFails),
          ),
          googleDriveSyncServiceProvider.overrideWithValue(drive),
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
          home: SettingsPage.account(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_noSession), findsOneWidget);
    await tester.tap(find.text('Google 다시 연결'));
    await tester.pumpAndSettle();
    return drive;
  }

  testWidgets(
    'a failed first sync after reconnecting still shows the session (#773)',
    (tester) async {
      final drive = await pumpAndReconnect(tester, connectFails: false);

      expect(find.text(_noSession), findsNothing);
      expect(find.text('지금 동기화'), findsOneWidget);
      expect(find.text(_syncFailure), findsOneWidget);

      // A later automatic sync succeeds: the stale error goes away.
      drive.statusNotifier.value = GoogleDriveSyncStatus(
        lastSyncedAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      await tester.pump();
      expect(find.text(_syncFailure), findsNothing);
      expect(find.text('지금 동기화'), findsOneWidget);
    },
    variant: macOS,
  );

  testWidgets('an older success does not clear a newer sync error (#773)', (
    tester,
  ) async {
    final drive = await pumpAndReconnect(tester, connectFails: false);

    drive.statusNotifier.value = GoogleDriveSyncStatus(
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    await tester.pump();
    expect(find.text(_syncFailure), findsOneWidget);
  }, variant: macOS);

  testWidgets('a failed sign-in still asks to reconnect (#773)', (
    tester,
  ) async {
    await pumpAndReconnect(tester, connectFails: true);

    expect(find.text(_noSession), findsOneWidget);
    expect(find.text('Google 다시 연결'), findsOneWidget);
    expect(find.text('Google Drive 연결을 완료하지 못했습니다.'), findsOneWidget);
  }, variant: macOS);
}
