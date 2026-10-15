import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class DeviceAuthenticationClient {
  Future<bool> get canCheckBiometrics;

  Future<List<BiometricType>> getAvailableBiometrics();

  Future<bool> isDeviceSupported();

  Future<bool> authenticate({
    required String localizedReason,
    required bool biometricOnly,
    required bool persistAcrossBackgrounding,
  });
}

class LocalAuthDeviceAuthenticationClient
    implements DeviceAuthenticationClient {
  LocalAuthDeviceAuthenticationClient({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> get canCheckBiometrics => _authentication.canCheckBiometrics;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() =>
      _authentication.getAvailableBiometrics();

  @override
  Future<bool> isDeviceSupported() => _authentication.isDeviceSupported();

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required bool biometricOnly,
    required bool persistAcrossBackgrounding,
  }) {
    return _authentication.authenticate(
      localizedReason: localizedReason,
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: persistAcrossBackgrounding,
    );
  }
}

/// Keeps the platform authentication API behind Daily's app-lock policy.
class BiometricAuthService {
  BiometricAuthService({DeviceAuthenticationClient? client})
    : _client = client ?? LocalAuthDeviceAuthenticationClient();

  final DeviceAuthenticationClient _client;
  static const _appleAuthenticationChannel = MethodChannel(
    'daily/apple_authentication',
  );

  Future<bool> isAvailable() async {
    if (kIsWeb) {
      return false;
    }
    try {
      if (!await _client.canCheckBiometrics) {
        return false;
      }
      return (await _client.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<bool> isDeviceAuthenticationAvailable() async {
    if (kIsWeb) {
      return false;
    }
    try {
      return await _client.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'Daily 잠금을 해제하려면 생체 인증이 필요합니다.',
    bool allowDeviceCredentials = false,
  }) async {
    final biometricOnly =
        !allowDeviceCredentials &&
        defaultTargetPlatform != TargetPlatform.windows;
    final available = biometricOnly
        ? await isAvailable()
        : await isDeviceAuthenticationAvailable();
    if (!available) {
      return false;
    }
    try {
      return await _client.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        // Darwin only resumes sticky requests on iOS. On macOS a system
        // cancellation must complete so the locked UI can offer another try.
        persistAcrossBackgrounding:
            defaultTargetPlatform != TargetPlatform.macOS,
      );
    } on LocalAuthException {
      return false;
    } on Object {
      return false;
    }
  }

  Future<bool> authenticateWithBiometricsOrCompanion({
    String localizedReason = 'Daily 잠금을 해제하려면 인증이 필요합니다.',
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return authenticate(localizedReason: localizedReason);
    }
    try {
      return await _appleAuthenticationChannel.invokeMethod<bool>(
            'authenticateBiometricsOrCompanion',
            {'localizedReason': localizedReason},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> isBiometricsOrCompanionAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return isAvailable();
    }
    try {
      return await _appleAuthenticationChannel.invokeMethod<bool>(
            'isBiometricsOrCompanionAvailable',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
