import 'dart:async';

import 'package:daily/core/auth/apple_sign_in_service.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _email = 'linked@example.com';

class _Auth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async =>
      const GoogleDriveAccount(email: _email);

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async => const {'Authorization': 'Bearer test-token'};
}

class _Drive extends Fake implements GoogleDriveSyncService {
  final restore = Completer<void>();

  @override
  final statusNotifier = ValueNotifier(const GoogleDriveSyncStatus());

  @override
  Future<void> startListeningOnly({bool flushPendingChanges = true}) async {}

  @override
  Future<void> syncPendingChangesNow({
    bool promptIfNecessary = false,
    bool restoreAfterBackup = false,
  }) => restore.future;
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

  testWidgets(
    'Google account actions stay disabled during Apple sign-in and restore',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      await settings.saveGoogleAccount(const GoogleAccount(email: _email));
      final credential = Completer<AuthorizationCredentialAppleID>();
      final apple = AppleSignInService(
        settingsRepository: settings,
        targetPlatform: TargetPlatform.iOS,
        availabilityChecker: () async => true,
        credentialRequester: ({required scopes}) => credential.future,
      );
      final drive = _Drive();
      addTearDown(drive.statusNotifier.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            googleDriveAuthServiceProvider.overrideWithValue(_Auth()),
            googleDriveSyncServiceProvider.overrideWithValue(drive),
            appleSignInServiceProvider.overrideWithValue(apple),
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

      bool enabled(String label) {
        final button = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        return button.onPressed != null;
      }

      const actions = ['지금 동기화', 'Google 연동 해지', 'Daily 계정 탈퇴'];
      for (final label in actions) {
        expect(enabled(label), isTrue, reason: label);
      }

      await tester.tap(find.text('Apple로 계속'));
      await tester.pump();
      expect(enabled('Google 연동 해지'), isFalse);
      expect(enabled('Daily 계정 탈퇴'), isFalse);
      expect(enabled('동기화 중'), isFalse);

      credential.complete(
        const AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user',
          givenName: null,
          familyName: null,
          authorizationCode: 'auth-code',
          email: null,
          identityToken: 'identity-token',
          state: null,
        ),
      );
      await tester.pump();
      await tester.pump();
      // Apple is saved; the linked Drive restore is still running.
      expect(settings.appleAccount()?.userIdentifier, 'apple-user');
      expect(enabled('Google 연동 해지'), isFalse);
      expect(enabled('Daily 계정 탈퇴'), isFalse);

      drive.restore.complete();
      await tester.pumpAndSettle();
      for (final label in actions) {
        expect(enabled(label), isTrue, reason: label);
      }
    },
  );
}
