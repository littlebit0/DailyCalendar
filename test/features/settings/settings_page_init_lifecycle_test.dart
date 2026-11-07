import 'dart:async';

import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily',
      version: '3.3.0',
      buildNumber: '330',
      buildSignature: '',
    );
    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue =
        const [Locale('ko')];
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocalesTestValue();
  });

  Future<(_GatedKeySettingsRepository, _GatedGoogleDriveAuthService)>
  pumpLauncher(
    WidgetTester tester, {
    Widget page = const SettingsPage(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final repository = _GatedKeySettingsRepository(preferences: preferences);
    final authService = _GatedGoogleDriveAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('open settings'),
            ),
          ),
        ),
      ),
    );
    return (repository, authService);
  }

  Future<void> openThenClose(WidgetTester tester) async {
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(SettingsPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
  }

  testWidgets('closing settings while the AI key loads does not use ref', (
    tester,
  ) async {
    final (repository, authService) = await pumpLauncher(tester);
    authService.restoreGate.complete();
    await openThenClose(tester);

    repository.keyGate.complete('stored-key');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Restoration still runs with the services captured while mounted.
    expect(authService.restoreCalls, 1);
    expect(repository.dailyAccount()?.googleAccount?.email, 'kept@example.com');
  });

  testWidgets('closing settings while restoring the account still saves it', (
    tester,
  ) async {
    final (repository, authService) = await pumpLauncher(tester);
    repository.keyGate.complete(null);
    await openThenClose(tester);
    expect(authService.restoreCalls, 1);

    authService.restoreGate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.dailyAccount()?.googleAccount?.email, 'kept@example.com');
  });

  testWidgets('settings initialization still shows the restored account', (
    tester,
  ) async {
    final (repository, authService) = await pumpLauncher(
      tester,
      page: const SettingsPage.account(),
    );
    repository.keyGate.complete('stored-key');
    authService.restoreGate.complete();
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(authService.restoreCalls, 1);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'kept@example.com' ||
                widget.semanticsLabel == 'kept@example.com'),
      ),
      findsWidgets,
    );
  });
}

class _GatedKeySettingsRepository extends SettingsRepository {
  _GatedKeySettingsRepository({required super.preferences});

  final keyGate = Completer<String?>();

  @override
  Future<String?> geminiApiKey() => keyGate.future;
}

class _GatedGoogleDriveAuthService extends GoogleDriveAuthService {
  final restoreGate = Completer<void>();
  var restoreCalls = 0;
  GoogleDriveAccount? _account;

  @override
  GoogleDriveAccount? get currentAccount => _account;

  @override
  Future<void> initialize() async {}

  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async {
    restoreCalls += 1;
    await restoreGate.future;
    return _account = const GoogleDriveAccount(email: 'kept@example.com');
  }

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async => const {'Authorization': 'Bearer test-token'};
}
