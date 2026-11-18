import 'package:daily/core/auth/apple_account.dart';
import 'package:daily/core/auth/apple_sign_in_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// #968: a new PIN after identity verification clears secure storage only when
/// its values can no longer be decrypted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ScriptedStorage storage;
  late SettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _ScriptedStorage();
    repository = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
      secureStorage: storage,
    );
  });

  test('key-lost errors are recognised by code only', () {
    expect(
      SettingsRepository.isSecureStorageKeyLost(
        PlatformException(code: 'DailySecureStorageKeyLost'),
      ),
      isTrue,
    );
    expect(
      SettingsRepository.isSecureStorageKeyLost(
        PlatformException(code: 'Exception encountered'),
      ),
      isFalse,
    );
    expect(SettingsRepository.isSecureStorageKeyLost(StateError('x')), isFalse);
  });

  test('a lost key clears the store before the new PIN is saved', () async {
    storage.failure = PlatformException(
      code: SettingsRepository.secureStorageKeyLostCode,
    );

    await repository.replaceUnreadableAppLockPin('4321');

    expect(storage.log, ['read', 'deleteAll', 'write', 'write']);
    expect(await repository.verifyAppLockPin('4321'), isTrue);
  });

  test('a readable store keeps its other values', () async {
    storage.values['geminiApiKey'] = 'kept';

    await repository.replaceUnreadableAppLockPin('4321');

    expect(storage.log, isNot(contains('deleteAll')));
    expect(await repository.geminiApiKey(), 'kept');
    expect(await repository.hasAppLockPin(), isTrue);
  });

  test('other storage errors change nothing', () async {
    storage.failure = PlatformException(code: 'Exception encountered');

    await expectLater(
      repository.replaceUnreadableAppLockPin('4321'),
      throwsA(isA<PlatformException>()),
    );
    expect(storage.log, ['read']);
  });

  group('Apple re-authentication', () {
    Future<AppleSignInService> service(
      Future<AuthorizationCredentialAppleID> Function() requester,
    ) async {
      await repository.saveAppleAccount(
        const AppleAccount(userIdentifier: 'apple-user'),
      );
      return AppleSignInService(
        settingsRepository: repository,
        targetPlatform: TargetPlatform.iOS,
        availabilityChecker: () async => true,
        credentialRequester: ({required scopes}) => requester(),
      );
    }

    AuthorizationCredentialAppleID credential(String user) =>
        AuthorizationCredentialAppleID(
          userIdentifier: user,
          givenName: null,
          familyName: null,
          authorizationCode: 'code',
          email: null,
          identityToken: null,
          state: null,
        );

    test('matches only the linked account and saves nothing', () async {
      final apple = await service(() async => credential('someone-else'));
      expect(await apple.verifyCurrentAccount(), isFalse);
      expect(repository.appleAccount()?.userIdentifier, 'apple-user');

      final same = await service(() async => credential('apple-user'));
      expect(await same.verifyCurrentAccount(), isTrue);
    });

    test('cancellation is not a failure', () async {
      final apple = await service(
        () async => throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'cancelled',
        ),
      );
      expect(await apple.verifyCurrentAccount(), isNull);
    });
  });
}

class _ScriptedStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  final log = <String>[];
  PlatformException? failure;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    log.add('read');
    if (failure != null) throw failure!;
    return values[key];
  }

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
    log.add('write');
    if (failure != null) throw failure!;
    values[key] = value!;
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    log.add('deleteAll');
    values.clear();
    failure = null;
  }
}
