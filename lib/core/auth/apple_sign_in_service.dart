import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../settings/settings_repository.dart';
import 'apple_account.dart';

typedef AppleAvailabilityChecker = Future<bool> Function();
typedef AppleCredentialRequester =
    Future<AuthorizationCredentialAppleID> Function({
      required List<AppleIDAuthorizationScopes> scopes,
    });
typedef AppleCredentialStateChecker =
    Future<CredentialState> Function(String userIdentifier);

class AppleSignInException implements Exception {
  const AppleSignInException(this.message, {this.cause});

  final String message;

  /// The underlying failure, for error reports only; never shown to the user.
  final Object? cause;

  @override
  String toString() => message;
}

class AppleSignInService {
  AppleSignInService({
    required SettingsRepository settingsRepository,
    AppleAvailabilityChecker? availabilityChecker,
    AppleCredentialRequester? credentialRequester,
    AppleCredentialStateChecker? credentialStateChecker,
    TargetPlatform? targetPlatform,
  }) : _settingsRepository = settingsRepository,
       _availabilityChecker =
           availabilityChecker ?? SignInWithApple.isAvailable,
       _credentialRequester =
           credentialRequester ?? SignInWithApple.getAppleIDCredential,
       _credentialStateChecker =
           credentialStateChecker ?? SignInWithApple.getCredentialState,
       _targetPlatform = targetPlatform;

  final SettingsRepository _settingsRepository;
  final AppleAvailabilityChecker _availabilityChecker;
  final AppleCredentialRequester _credentialRequester;
  final AppleCredentialStateChecker _credentialStateChecker;
  final TargetPlatform? _targetPlatform;

  AppleAccount? get currentAccount => _settingsRepository.appleAccount();

  bool get isSupportedPlatform {
    final platform = _targetPlatform ?? defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  Future<bool> isAvailable() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      return _availabilityChecker();
    } on Object {
      return false;
    }
  }

  Future<AppleAccount?> signIn() async {
    if (!isSupportedPlatform) {
      throw const AppleSignInException(
        'Apple 로그인은 iPhone, iPad, macOS에서 사용할 수 있습니다.',
      );
    }
    if (!await isAvailable()) {
      throw const AppleSignInException(
        '이 기기에서 Apple 로그인을 사용할 수 없습니다. Apple ID 설정과 앱 권한을 확인해 주세요.',
      );
    }

    try {
      final credential = await _credentialRequester(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final userIdentifier = credential.userIdentifier?.trim();
      if (userIdentifier == null || userIdentifier.isEmpty) {
        throw const AppleSignInException(
          'Apple 인증 응답에 사용자 식별자가 없습니다. 다시 시도해 주세요.',
        );
      }

      final existing = currentAccount;
      final sameUser = existing?.userIdentifier == userIdentifier;
      final account = AppleAccount(
        userIdentifier: userIdentifier,
        email: _clean(credential.email) ?? (sameUser ? existing?.email : null),
        givenName:
            _clean(credential.givenName) ??
            (sameUser ? existing?.givenName : null),
        familyName:
            _clean(credential.familyName) ??
            (sameUser ? existing?.familyName : null),
      );
      await _settingsRepository.saveAppleAccount(account);
      return account;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw AppleSignInException(_messageForAuthorizationError(error));
    } on SignInWithAppleNotSupportedException catch (_) {
      throw const AppleSignInException(
        '이 기기에서 Apple 로그인을 사용할 수 없습니다. OS 버전과 Apple ID 설정을 확인해 주세요.',
      );
    } on AppleSignInException {
      rethrow;
    } on Object catch (error, stack) {
      // The page shows only the message; keep the cause for the error report.
      Error.throwWithStackTrace(
        AppleSignInException('Apple 로그인 요청을 완료하지 못했습니다.', cause: error),
        stack,
      );
    }
  }

  /// Asks Apple to authenticate again and reports whether it is the linked
  /// account; null when the user cancelled. Nothing is saved (#968).
  Future<bool?> verifyCurrentAccount() async {
    final linked = currentAccount;
    if (linked == null || !await isAvailable()) return false;
    try {
      final credential = await _credentialRequester(scopes: const []);
      return credential.userIdentifier?.trim() == linked.userIdentifier;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      return false;
    } on Object {
      return false;
    }
  }

  Future<AppleAccount?> refreshCurrentAccount() async {
    final account = currentAccount;
    if (account == null || !isSupportedPlatform) {
      return account;
    }
    try {
      final state = await _credentialStateChecker(account.userIdentifier);
      // Daily treats Sign in with Apple as the user's app account marker.
      // iOS can report a transient non-authorized state after simulator resets,
      // device account changes, or credential-state lookup failures. Do not
      // erase the local app login state unless the user explicitly logs out or
      // withdraws membership from Daily.
      if (state == CredentialState.revoked) {
        return account;
      }
      return currentAccount;
    } on Object {
      return account;
    }
  }

  Future<void> signOut() {
    return _settingsRepository.deleteAppleAccount();
  }

  String _messageForAuthorizationError(
    SignInWithAppleAuthorizationException error,
  ) {
    return switch (error.code) {
      AuthorizationErrorCode.failed =>
        'Apple 로그인에 실패했습니다. Apple ID 상태와 네트워크를 확인해 주세요.',
      AuthorizationErrorCode.invalidResponse =>
        'Apple 로그인 응답이 올바르지 않습니다. 다시 시도해 주세요.',
      AuthorizationErrorCode.notHandled =>
        'Apple 로그인 요청을 처리하지 못했습니다. 앱의 Sign in with Apple 권한을 확인해 주세요.',
      AuthorizationErrorCode.notInteractive =>
        '현재 상태에서는 Apple 로그인 창을 열 수 없습니다. 앱을 다시 열고 시도해 주세요.',
      AuthorizationErrorCode.credentialImport ||
      AuthorizationErrorCode.credentialExport =>
        'Apple 자격 증명 처리 중 오류가 발생했습니다. 다시 시도해 주세요.',
      AuthorizationErrorCode.matchedExcludedCredential ||
      AuthorizationErrorCode.unknown =>
        'Apple 로그인을 완료하지 못했습니다. SideStore 등으로 재서명한 IPA에서는 '
            'Sign in with Apple 권한이 제거될 수 있습니다. 이 경우 Google로 계속을 '
            '사용하거나 TestFlight/App Store 빌드에서 Apple 로그인을 사용해 주세요.',
      AuthorizationErrorCode.canceled => 'Apple 로그인이 취소되었습니다.',
    };
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
