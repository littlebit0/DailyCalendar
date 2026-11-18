import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/onboarding/feature_announcements.dart';
import 'package:daily/features/onboarding/presentation/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _failure = '요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
const _opening = 'Google 로그인 창을 여는 중입니다.';

class _Auth extends GoogleDriveAuthService {
  Object? connectError;

  @override
  Future<GoogleDriveAccount?> connectToDrive() async {
    if (connectError case final error?) throw error;
    return const GoogleDriveAccount(email: 'student@example.com');
  }
}

class _Drive extends Fake implements GoogleDriveSyncService {
  @override
  Future<void> startListeningOnly({bool flushPendingChanges = true}) async {}
}

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  String? failingKey;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      key != failingKey && await super.setValue(valueType, key, value);
}

void main() {
  // Android has neither the Siri step nor the Apple button.
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  late _Store store;
  late _Auth auth;
  late SettingsRepository settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = store = _Store();
    auth = _Auth();
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
  });

  Future<void> openAccountStep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          googleDriveAuthServiceProvider.overrideWithValue(auth),
          googleDriveSyncServiceProvider.overrideWithValue(_Drive()),
        ],
        child: const MaterialApp(home: WelcomePage()),
      ),
    );
    await tester.pumpAndSettle();
    for (var step = 0; step < 8; step += 1) {
      if (find.text('로컬로 시작').evaluate().isNotEmpty) break;
      final next = [
        '계속',
        '기본으로만 사용',
        '나중에',
      ].map(find.text).firstWhere((finder) => finder.evaluate().isNotEmpty);
      await tester.tap(next.first);
      await tester.pumpAndSettle();
    }
    expect(find.text('로컬로 시작'), findsOneWidget);
  }

  // Saving the account does real asynchronous work that the fake clock of
  // pumpAndSettle never completes while the busy indicator keeps animating.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'a failed completion after Google sign-in shows a notice and can be retried',
    (tester) async {
      await openAccountStep(tester);
      store.failingKey = 'flutter.${FeatureAnnouncementStore.key}';

      await tester.tap(find.text('Google로 계속'));
      await settle(tester);

      expect(find.text(_failure), findsOneWidget);
      expect(find.text(_opening), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);
      expect(settings.load().onboardingCompleted, isFalse);

      store.failingKey = null;
      await tester.tap(find.text('Google로 계속'));
      await settle(tester);
      expect(settings.load().onboardingCompleted, isTrue);
    },
    variant: android,
  );

  testWidgets('a Google sign-in failure does not show the exception text', (
    tester,
  ) async {
    await openAccountStep(tester);
    auth.connectError = PlatformException(code: 'sign_in_failed');

    await tester.tap(find.text('Google로 계속'));
    await settle(tester);

    expect(find.text(_failure), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(settings.load().onboardingCompleted, isFalse);
  }, variant: android);

  testWidgets('a Google sign-in message written for the user is kept', (
    tester,
  ) async {
    await openAccountStep(tester);
    auth.connectError = const GoogleDriveAuthException('Google 연결 안내');

    await tester.tap(find.text('Google로 계속'));
    await settle(tester);

    expect(find.text('Google 연결 안내'), findsOneWidget);
  }, variant: android);

  testWidgets('a failed local start does not show the exception text', (
    tester,
  ) async {
    await openAccountStep(tester);
    store.failingKey = 'flutter.${FeatureAnnouncementStore.key}';

    await tester.tap(find.text('로컬로 시작'));
    await settle(tester);

    expect(find.text(_failure), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);

    store.failingKey = null;
    await tester.tap(find.text('로컬로 시작'));
    await settle(tester);
    expect(settings.load().onboardingCompleted, isTrue);
  }, variant: android);
}
