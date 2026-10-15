import 'package:daily/core/security/app_lock_privacy_service.dart';
import 'package:daily/core/security/biometric_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'macOS cancellation releases settings authentication suppression',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final client = _FakeDeviceAuthenticationClient()..cancelNext = true;
      final service = BiometricAuthService(client: client);
      final privacy = AppLockPrivacyService();
      expect(
        await privacy.duringConfigurationAuthentication(() async {
          expect(
            AppLockPrivacyService.configurationAuthenticationInProgress,
            isTrue,
          );
          return service.authenticate(allowDeviceCredentials: true);
        }),
        isFalse,
      );
      expect(
        AppLockPrivacyService.configurationAuthenticationInProgress,
        isFalse,
      );
      expect(
        await privacy.duringConfigurationAuthentication(
          () => service.authenticate(allowDeviceCredentials: true),
        ),
        isTrue,
      );
      expect(
        AppLockPrivacyService.configurationAuthenticationInProgress,
        isFalse,
      );
    },
  );

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    test(
      '$platform cancellation completes and permits a fresh authentication',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final client = _FakeDeviceAuthenticationClient()..cancelNext = true;
        final service = BiometricAuthService(client: client);
        expect(await service.authenticate(), isFalse);
        expect(client.lastPersist, platform != TargetPlatform.macOS);
        expect(await service.authenticate(), isTrue);
        expect(client.calls, 2);
      },
    );
  }

  test(
    'Apple device credentials are allowed when explicitly requested',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final client = _FakeDeviceAuthenticationClient();
      final service = BiometricAuthService(client: client);

      final authenticated = await service.authenticate(
        localizedReason: 'Daily 앱 잠금 해제',
        allowDeviceCredentials: true,
      );

      expect(authenticated, isTrue);
      expect(client.lastBiometricOnly, isFalse);
    },
  );

  test('ordinary Apple biometric requests remain biometric only', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final client = _FakeDeviceAuthenticationClient();
    final service = BiometricAuthService(client: client);

    final authenticated = await service.authenticate();

    expect(authenticated, isTrue);
    expect(client.lastBiometricOnly, isTrue);
  });

  test(
    'macOS companion authentication uses the native Apple channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('daily/apple_authentication');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final service = BiometricAuthService();
      expect(await service.isBiometricsOrCompanionAvailable(), isTrue);
      expect(
        await service.authenticateWithBiometricsOrCompanion(
          localizedReason: 'Touch ID 또는 Apple Watch',
        ),
        isTrue,
      );
      expect(calls.map((call) => call.method), [
        'isBiometricsOrCompanionAvailable',
        'authenticateBiometricsOrCompanion',
      ]);
    },
  );
}

class _FakeDeviceAuthenticationClient implements DeviceAuthenticationClient {
  bool? lastBiometricOnly;
  bool? lastPersist;
  bool cancelNext = false;
  int calls = 0;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [
    BiometricType.face,
  ];

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required bool biometricOnly,
    required bool persistAcrossBackgrounding,
  }) async {
    calls++;
    lastPersist = persistAcrossBackgrounding;
    lastBiometricOnly = biometricOnly;
    if (cancelNext) {
      cancelNext = false;
      throw const LocalAuthException(
        code: LocalAuthExceptionCode.systemCanceled,
      );
    }
    return true;
  }
}
