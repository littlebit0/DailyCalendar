import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// #915: turning PIN lock on reused whatever PIN was still in secure storage
// without asking, so a forgotten leftover PIN could lock the user out.
void main() {
  testWidgets('turning PIN lock on asks for a new PIN despite a leftover one', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily',
      version: '4.2.0',
      buildNumber: '420',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final repository = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
      secureStorage: _MemorySecureStorage(),
    );
    await repository.saveAppLockPin('13579');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          googleDriveAuthServiceProvider.overrideWithValue(_SilentAuth()),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final privacy = find.byKey(const ValueKey('privacy-settings-navigation'));
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('앱 잠금'));
    await tester.tap(find.text('앱 잠금'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN 잠금'));
    await tester.pumpAndSettle();

    expect(find.text('앱 잠금 PIN 설정'), findsOneWidget);
    expect(repository.load().appLockEnabled, isFalse);

    for (final step in ['다음', '설정']) {
      for (final digit in ['2', '4', '6', '8']) {
        await tester.tap(find.widgetWithText(TextButton, digit));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(FilledButton, step));
      await tester.pumpAndSettle();
    }

    expect(repository.load().appLockEnabled, isTrue);
    expect(await repository.verifyAppLockPin('2468'), isTrue);
    expect(await repository.verifyAppLockPin('13579'), isFalse);
  });
}

class _SilentAuth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

class _MemorySecureStorage extends FlutterSecureStorage {
  final _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}
