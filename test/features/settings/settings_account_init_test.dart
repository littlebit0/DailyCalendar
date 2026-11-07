import 'package:daily/core/auth/apple_account.dart';
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

class _Settings extends SettingsRepository {
  _Settings({required super.preferences, required this.keyFails});

  final bool keyFails;

  @override
  Future<String?> geminiApiKey() async {
    if (keyFails) {
      throw StateError('secure storage unavailable');
    }
    return null;
  }
}

class _Auth extends GoogleDriveAuthService {
  _Auth({this.restoreFails = false});

  final bool restoreFails;
  var restoreCalls = 0;

  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async {
    restoreCalls++;
    if (restoreFails) {
      throw StateError('restore failed');
    }
    return null;
  }
}

class _Drive extends Fake implements GoogleDriveSyncService {
  @override
  final statusNotifier = ValueNotifier(const GoogleDriveSyncStatus());
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

  Future<_Auth> pump(
    WidgetTester tester, {
    required bool keyFails,
    bool restoreFails = false,
    GoogleAccount? google,
    AppleAccount? apple,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _Settings(
      preferences: await SharedPreferences.getInstance(),
      keyFails: keyFails,
    );
    if (google != null) await settings.saveGoogleAccount(google);
    if (apple != null) await settings.saveAppleAccount(apple);
    final auth = _Auth(restoreFails: restoreFails);
    final drive = _Drive();
    addTearDown(drive.statusNotifier.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          googleDriveAuthServiceProvider.overrideWithValue(auth),
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
    return auth;
  }

  const email = 'student@example.com';
  final emailText = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data == email || widget.semanticsLabel == email),
  );

  testWidgets('key lookup failure keeps saved Google account and restore', (
    tester,
  ) async {
    final auth = await pump(
      tester,
      keyFails: true,
      google: const GoogleAccount(email: email),
    );

    expect(tester.takeException(), isNull);
    expect(auth.restoreCalls, 1);
    expect(emailText, findsWidgets);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('key lookup failure keeps saved Apple account connected', (
    tester,
  ) async {
    await pump(
      tester,
      keyFails: true,
      apple: const AppleAccount(userIdentifier: 'apple-user'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('missing key shows saved Google account', (tester) async {
    final auth = await pump(
      tester,
      keyFails: false,
      google: const GoogleAccount(email: email),
    );

    expect(auth.restoreCalls, 1);
    expect(emailText, findsWidgets);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('Google restore failure keeps saved account', (tester) async {
    final auth = await pump(
      tester,
      keyFails: false,
      restoreFails: true,
      google: const GoogleAccount(email: email),
    );

    expect(tester.takeException(), isNull);
    expect(auth.restoreCalls, 1);
    expect(emailText, findsWidgets);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('no saved account stays disconnected', (tester) async {
    await pump(tester, keyFails: true);

    expect(find.text('로그아웃'), findsNothing);
  });
}
