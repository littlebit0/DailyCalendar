import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:html/parser.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'lms_models.dart';
import 'lms_learning_report_client.dart';
import 'lms_credentials_store.dart';

enum LmsWebSessionError {
  authenticationRequired,
  network,
  invalidResponse,
  unsupported,
  busy,
  hostUnavailable,
  viewUnavailable,
  viewMismatch,
  viewAmbiguous,
  scriptUnavailable,
  disallowedRequest,
  secureStorage,
}

/// Deliberately contains no response body, URL query, cookie, or platform error.
class LmsWebSessionException implements Exception {
  const LmsWebSessionException(this.code);
  final LmsWebSessionError code;
  @override
  String toString() => 'LmsWebSessionException(${code.name})';
}

/// Fixed diagnostic categories only; never expose school/native exception text.
enum LmsLoginFailure {
  network,
  timedOut,
  additionalAuthentication,
  credentialsRejected,
  accountLocked,
  passwordExpired,
  accountMismatch,
  unsupportedForm,
  authenticationUnconfirmed,
  invalidResponse,
  hostUnavailable,
  viewUnavailable,
  scriptUnavailable,
  busy,
  secureStorage,
  certificate,
  serverRejected,
  unknown;

  String get message => switch (this) {
    network => '학교 서버에 연결하지 못했습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
    timedOut => '제한 시간 안에 학교 로그인 확인이 끝나지 않았습니다. 잠시 후 다시 시도해 주세요.',
    additionalAuthentication =>
      '인증 절차가 필요하여 거부되었습니다. 수동 로그인으로 추가 인증 또는 보안문자 입력을 완료해 주세요.',
    credentialsRejected => '비밀번호가 틀렸습니다. 저장된 로그인 정보를 확인해 주세요.',
    accountLocked =>
      '학교에서 계정 잠금 또는 로그인 시도 제한을 안내했습니다. 학교 안내에 따라 해제한 뒤 다시 시도해 주세요.',
    passwordExpired =>
      '학교에서 비밀번호 만료 또는 변경을 요구합니다. 학교 사이트에서 변경한 뒤 저장된 정보도 수정해 주세요.',
    accountMismatch => '연결된 학교 계정과 로그인한 학교 계정이 다릅니다. 연결된 계정으로 로그인해 주세요.',
    unsupportedForm =>
      '현재 학교 인증 경로 또는 로그인 양식은 자동 처리할 수 없습니다. 수동 로그인으로 진행해 주세요.',
    authenticationUnconfirmed =>
      '학교에서 로그인 완료를 확인하지 못했습니다. 로그인 정보와 추가 인증 여부를 확인해 주세요.',
    invalidResponse =>
      '학교 응답에서 로그인 상태를 확인할 수 없습니다. 학교 화면이 변경됐거나 예상과 다른 응답을 받았습니다.',
    hostUnavailable => '학교 로그인창을 실행할 앱 화면이 활성화되지 않았습니다. 앱을 화면에 연 뒤 다시 시도해 주세요.',
    viewUnavailable => '학교 로그인창과 연결하지 못했습니다. 로그인창을 닫고 다시 열어 주세요.',
    scriptUnavailable => '학교 로그인 화면 확인 기능을 실행하지 못했습니다. 로그인창을 다시 열어 주세요.',
    busy => '다른 학교 로그인 작업이 진행 중입니다. 해당 작업을 마친 뒤 다시 시도해 주세요.',
    secureStorage =>
      '이 기기의 보안 저장소에서 로그인 정보를 읽거나 저장하지 못했습니다. 기기 잠금을 해제한 뒤 다시 시도해 주세요.',
    certificate => '학교 서버의 보안 인증서를 확인하지 못했습니다. 네트워크와 기기 날짜를 확인해 주세요.',
    serverRejected => '학교 서버가 로그인 화면 요청을 거부했거나 서버 오류를 반환했습니다. 잠시 후 다시 시도해 주세요.',
    unknown => '로그인 처리 중 오류가 발생했지만 원인을 확인하지 못했습니다. 다시 시도해 주세요.',
  };

  static LmsLoginFailure fromError(Object error) {
    if (error is WebResourceError) {
      if (error.type == WebResourceErrorType.TIMEOUT) return timedOut;
      if ({
        WebResourceErrorType.FAILED_SSL_HANDSHAKE,
        WebResourceErrorType.SECURE_CONNECTION_FAILED,
        WebResourceErrorType.SERVER_CERTIFICATE_HAS_BAD_DATE,
        WebResourceErrorType.SERVER_CERTIFICATE_HAS_UNKNOWN_ROOT,
        WebResourceErrorType.SERVER_CERTIFICATE_NOT_YET_VALID,
        WebResourceErrorType.SERVER_CERTIFICATE_UNTRUSTED,
        WebResourceErrorType.CLIENT_CERTIFICATE_REJECTED,
        WebResourceErrorType.CLIENT_CERTIFICATE_REQUIRED,
      }.contains(error.type)) {
        return certificate;
      }
      return network;
    }
    if (error is TimeoutException) return timedOut;
    if (error is HandshakeException) return certificate;
    if (error is SocketException || error is HttpException) return network;
    if (error is! LmsWebSessionException) return unknown;
    return switch (error.code) {
      LmsWebSessionError.network => network,
      LmsWebSessionError.secureStorage => secureStorage,
      LmsWebSessionError.authenticationRequired => authenticationUnconfirmed,
      LmsWebSessionError.invalidResponse => invalidResponse,
      LmsWebSessionError.unsupported ||
      LmsWebSessionError.disallowedRequest => unsupportedForm,
      LmsWebSessionError.busy => busy,
      LmsWebSessionError.hostUnavailable => hostUnavailable,
      LmsWebSessionError.scriptUnavailable => scriptUnavailable,
      LmsWebSessionError.viewUnavailable ||
      LmsWebSessionError.viewMismatch ||
      LmsWebSessionError.viewAmbiguous => viewUnavailable,
    };
  }

  static LmsLoginFailure fromSchoolCode(Object? code) => switch (code) {
    'additionalAuthentication' => additionalAuthentication,
    'credentialsRejected' => credentialsRejected,
    'accountLocked' => accountLocked,
    'passwordExpired' => passwordExpired,
    _ => unsupportedForm,
  };
}

/// Bounded, nonsecret evidence for diagnosing the point of authentication loss.
/// Never add principal IDs, URLs, headers, cookies, or response text here.
enum LmsAuthenticationReason {
  readRedirect,
  readUnauthorized,
  readOriginChanged,
  readLoginForm,
  readPrincipalMismatch,
  rootLoginForm,
  rootPrincipalMismatch,
  rootUnrecognized,
  rootOriginChanged,
  rootAccepted,
  recoveryStarted,
  finalRootValidationStarted,
  snapshotRestoreStarted,
  recoverySucceeded,
  credentialsDiscarded,
  refreshConfirmed,
  closed,
  automaticLoginStarted,
  automaticHeadlessReady,
  automaticStoreBound,
  automaticEntryLoaded,
  automaticCredentialsSubmitted,
  automaticLoginChallenge,
}

class LmsAuthenticationDiagnostic {
  const LmsAuthenticationDiagnostic({
    required this.reason,
    required this.occurredAt,
    required this.generation,
  });
  final LmsAuthenticationReason reason;
  final DateTime occurredAt;
  final int generation;
}

/// Separate navigation permissions from the much narrower automatic read API.
class LmsWebRequestPolicy {
  const LmsWebRequestPolicy(this.baseUrl);
  final Uri baseUrl;

  bool isSchoolOrigin(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == baseUrl.host &&
      uri.port == 443 &&
      uri.userInfo.isEmpty;

  bool allowsRead(Uri uri) {
    if (!isSchoolOrigin(uri) || uri.fragment.isNotEmpty) return false;
    if (uri.queryParametersAll.values.any((values) => values.length != 1)) {
      return false;
    }
    switch (uri.path) {
      case '/':
        return !uri.hasQuery;
      case '/mod/assign/index.php':
      case '/mod/quiz/index.php':
      case '/mod/quiz/view.php':
      case '/course/view.php':
      case '/report/ubcompletion/user_progress.php':
        return uri.queryParameters.length == 1 &&
            RegExp(r'^[1-9][0-9]*$').hasMatch(uri.queryParameters['id'] ?? '');
      default:
        // Detail/view, completion, media, grade and token routes are not reads.
        return false;
    }
  }

  bool allowsLoginNavigation(Uri uri) {
    if (uri.toString() == 'about:blank') return true;
    final domain = baseUrl.host == 'ecampus.smu.ac.kr'
        ? 'smu.ac.kr'
        : 'jnu.ac.kr';
    return uri.scheme == 'https' &&
        uri.port == 443 &&
        uri.userInfo.isEmpty &&
        (uri.host == domain || uri.host.endsWith('.$domain'));
  }

  /// This link refers to the signed-in user's own preferences, not classmates.
  String? principalFromHtml(String source) {
    final document = html.parse(source);
    if (document.querySelector('input[type="password"]') != null) return null;
    final ids = <String>{};
    for (final anchor in document.querySelectorAll('a[href]')) {
      final uri = baseUrl.resolve(anchor.attributes['href']!);
      if (!isSchoolOrigin(uri) || uri.path != '/user/edit.php') continue;
      final id = uri.queryParameters['id'];
      if (id != null && RegExp(r'^[1-9][0-9]*$').hasMatch(id)) ids.add(id);
    }
    return ids.length == 1 ? ids.single : null;
  }
}

/// Only Daily's embedded school browser is used. System browser data is never
/// accessed. The platform cookie manager is shared within this app, so school
/// sessions are activated serially and cleared when changing owner or school.
class LmsWebSession extends ChangeNotifier {
  LmsWebSession({
    required String ownerId,
    required this.schoolId,
    FlutterSecureStorage? secureStorage,
  }) : ownerId = ownerId.trim().toLowerCase(),
       _storage = secureStorage ?? const FlutterSecureStorage() {
    if (this.ownerId.isEmpty || !const {'smu', 'jnu'}.contains(schoolId)) {
      throw const LmsWebSessionException(LmsWebSessionError.unsupported);
    }
  }

  final String ownerId;
  final String schoolId;
  final FlutterSecureStorage _storage;
  static LmsWebSession? _active;
  static Future<void> _activationTail = Future<void>.value();
  Future<void> _readTail = Future<void>.value();
  Future<void>? _preparing;
  Future<String?>? _verification;
  Future<void>? _closing;
  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  WebViewEnvironment? _environment;
  InAppWebViewKeepAlive? _keepAlive;
  String? _principalId;
  String? _expectedPrincipal;
  String? _lastPersistedAuthentication;
  LmsHtmlPage? _verifiedDashboard;
  DateTime? _verifiedDashboardAt;
  DateTime? _lastPageLoadedAt;
  int? _verifiedDashboardGeneration;
  int _generation = 0;
  int? _authenticationRejectedGeneration;
  LmsAuthenticationReason? _authenticationRejectedReason;
  final _authenticationDiagnostics = <LmsAuthenticationDiagnostic>[];
  bool _loginVisible = false;
  LmsLoginFailure? _lastAutomaticLoginFailure;
  LmsLoginFailure? get lastAutomaticLoginFailure => _lastAutomaticLoginFailure;
  bool get hasPrincipalMismatch =>
      _authenticationRejectedReason ==
      LmsAuthenticationReason.rootPrincipalMismatch;
  bool _automaticLogin = false;
  bool _automaticLoginChallenge = false;
  bool _keptAlive = false;
  bool _disposed = false;
  bool _nativeCookieBound = false;
  bool _authenticationRecoveryPending = false;
  bool _authenticationRecoveryAttempted = false;
  Completer<void>? _pageLoaded;
  static const _cookieChannel = MethodChannel('daily/lms_cookie_store');
  bool get _usesAppleStore => Platform.isIOS || Platform.isMacOS;
  final Set<Uri> _visitedLoginUrls = {};

  Uri get baseUrl =>
      Uri.https(schoolId == 'smu' ? 'ecampus.smu.ac.kr' : 'sel.jnu.ac.kr', '/');
  LmsWebRequestPolicy get policy => LmsWebRequestPolicy(baseUrl);
  String? get principalId => _principalId;
  String? get storedPrincipalId => _expectedPrincipal;
  int get generation => _generation;
  List<LmsAuthenticationDiagnostic> get authenticationDiagnostics =>
      List.unmodifiable(_authenticationDiagnostics);
  bool get isAuthenticated =>
      !_disposed && _principalId != null && identical(_active, this);
  bool get isLoginVisible => _loginVisible;
  HeadlessInAppWebView? get headlessView => _headless;
  WebViewEnvironment? get webViewEnvironment => _environment;
  InAppWebViewKeepAlive get keepAlive => _keepAlive ??= InAppWebViewKeepAlive();
  Uri get loginUrl => baseUrl.resolve('/login.php');
  String get _ownerKey =>
      sha256.convert(utf8.encode('$ownerId\n$schoolId')).toString();
  String get _storageKey => 'daily.lms.session.v1.$_ownerKey';
  CookieManager get _cookies =>
      CookieManager.instance(webViewEnvironment: _environment);

  InAppWebViewSettings get webViewSettings => InAppWebViewSettings(
    javaScriptEnabled: true,
    incognito: !Platform.isAndroid,
    useShouldOverrideUrlLoading: true,
    supportMultipleWindows: true,
    javaScriptCanOpenWindowsAutomatically: true,
    mediaPlaybackRequiresUserGesture: true,
    cacheEnabled: false,
    saveFormData: false,
    sharedCookiesEnabled: false,
    isInspectable: false,
    allowFileAccess: false,
    allowContentAccess: false,
  );

  Future<bool> hasStoredSession() async {
    _checkNotRetired();
    final startedGeneration = _generation;
    final data = await _readStored();
    _checkLifecycle(startedGeneration);
    _expectedPrincipal = data?['principal'] as String?;
    return data != null && (data['cookies'] as List).isNotEmpty;
  }

  Future<Map<String, dynamic>?> _readStored() async {
    final value = await _storage.read(key: _storageKey);
    if (value == null) return null;
    try {
      final data = jsonDecode(value);
      if (data is Map<String, dynamic> &&
          data['owner'] == ownerId &&
          data['school'] == schoolId &&
          data['principal'] is String &&
          RegExp(r'^[1-9][0-9]*$').hasMatch(data['principal'] as String) &&
          data['cookies'] is List) {
        return data;
      }
    } on FormatException {
      /* Expired or incompatible local material. */
    }
    await _storage.delete(key: _storageKey);
    return null;
  }

  Future<void> _activate() async {
    _checkNotRetired();
    if (identical(_active, this)) return;
    final startingGeneration = _generation;
    final previous = _activationTail;
    final done = Completer<void>();
    _activationTail = done.future;
    await previous;
    try {
      if (_disposed || startingGeneration != _generation) {
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
      if (identical(_active, this)) return;
      await _active?.close();
      _checkLifecycle(startingGeneration);
      if (Platform.isWindows) {
        final version = await WebViewEnvironment.getAvailableVersion();
        _checkLifecycle(startingGeneration);
        if (version == null) {
          throw const LmsWebSessionException(LmsWebSessionError.unsupported);
        }
        final directory = await getApplicationSupportDirectory();
        _checkLifecycle(startingGeneration);
        _environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder: '${directory.path}/lms-webview/$_ownerKey',
          ),
        );
      }
      if (_disposed || startingGeneration != _generation) {
        await _environment?.dispose();
        _environment = null;
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
      _active = this;
      await _clearSchoolCookies();
      _checkGeneration(startingGeneration);
    } finally {
      done.complete();
    }
  }

  /// No stored credentials means no native view is created during app startup.
  Future<void> prepare() {
    _checkNotRetired();
    if (isAuthenticated || _loginVisible) return Future<void>.value();
    return _preparing ??= _prepare().whenComplete(() => _preparing = null);
  }

  Future<void> _prepare() async {
    final startedGeneration = _generation;
    final data = await _readStored();
    _checkLifecycle(startedGeneration);
    if (data == null) return;
    _expectedPrincipal = data['principal'] as String;
    if ((data['cookies'] as List).isEmpty) return;
    try {
      await _activate();
      _checkGeneration(startedGeneration);
      if (_authenticationRecoveryAttempted &&
          _controller != null &&
          _authenticationRejectedReason !=
              LmsAuthenticationReason.rootLoginForm) {
        // Later lifecycle retries must not overwrite a live store after an
        // inconclusive root response either.
        if (await _validateCurrentStore()) return;
        if (_authenticationRejectedReason ==
            LmsAuthenticationReason.rootPrincipalMismatch) {
          await _discardAuthentication();
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        }
      }
      final restoreGeneration = _generation;
      await _startHeadless();
      _checkGeneration(restoreGeneration);
      await _bindCookieStore();
      _checkGeneration(restoreGeneration);
      await _restoreCookies(data['cookies'] as List);
      _checkGeneration(restoreGeneration);
      await _reloadRoot();
      _checkGeneration(restoreGeneration);
      if (await verifyAuthentication() == null) {
        // Only a rejected root identity in this still-current lifecycle proves
        // these restored credentials unusable. View setup and cancellation do
        // not constitute a school authentication result.
        if (!_disposed &&
            identical(_active, this) &&
            _authenticationRejectedGeneration == _generation) {
          await _discardAuthentication();
        }
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
    } on LmsWebSessionException {
      await _discardUnboundHeadless();
      rethrow;
    } catch (_) {
      await _discardUnboundHeadless();
      throw const LmsWebSessionException(LmsWebSessionError.network);
    }
  }

  /// A read rejected by the server gets one restoration of Daily's own saved
  /// session. This neither opens an SSO route nor submits credentials. A server-
  /// revoked session still requires an explicit school login.
  Future<bool> recoverAuthentication() async {
    _checkNotRetired();
    if (!_authenticationRecoveryPending || _loginVisible) return false;
    _authenticationRecoveryPending = false;
    _authenticationRecoveryAttempted = true;
    _recordAuthentication(LmsAuthenticationReason.recoveryStarted);
    // A read can redirect while rotating an otherwise valid cookie. Validate
    // the live private store before replacing it with an older saved snapshot.
    if (await _validateCurrentStore()) {
      _recordAuthentication(LmsAuthenticationReason.recoverySucceeded);
      return isAuthenticated;
    }
    if (_authenticationRejectedReason ==
        LmsAuthenticationReason.rootPrincipalMismatch) {
      await _discardAuthentication();
      return false;
    }
    _recordAuthentication(LmsAuthenticationReason.snapshotRestoreStarted);
    await prepare();
    if (isAuthenticated) {
      _recordAuthentication(LmsAuthenticationReason.recoverySucceeded);
    }
    return isAuthenticated;
  }

  Future<bool> _validateCurrentStore() async {
    final startedGeneration = _generation;
    await _reloadRoot();
    _checkGeneration(startedGeneration);
    if (await verifyAuthentication() != null) return true;
    // Verification itself advances the generation on an explicit rejection.
    // A concurrent close/owner change clears this evidence and must stop here.
    if (_disposed ||
        !identical(_active, this) ||
        _authenticationRejectedGeneration != _generation) {
      throw const LmsWebSessionException(
        LmsWebSessionError.authenticationRequired,
      );
    }
    if (_authenticationRejectedReason !=
            LmsAuthenticationReason.rootLoginForm &&
        _authenticationRejectedReason !=
            LmsAuthenticationReason.rootPrincipalMismatch) {
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    return false;
  }

  /// A root check alone does not replenish the retry budget. Only the owning
  /// controller's successful complete sync pass permits a later recovery.
  void acknowledgeSuccessfulRefresh() {
    if (!isAuthenticated || _loginVisible) return;
    _authenticationRecoveryAttempted = false;
    _authenticationRecoveryPending = false;
    _recordAuthentication(LmsAuthenticationReason.refreshConfirmed);
  }

  void _recordAuthentication(LmsAuthenticationReason reason) {
    _authenticationDiagnostics.add(
      LmsAuthenticationDiagnostic(
        reason: reason,
        occurredAt: DateTime.now().toUtc(),
        generation: _generation,
      ),
    );
    if (_authenticationDiagnostics.length > 24) {
      _authenticationDiagnostics.removeAt(0);
    }
  }

  Future<void> _rejectReadAuthentication(LmsAuthenticationReason reason) async {
    _recordAuthentication(reason);
    if (_authenticationRecoveryAttempted) {
      _recordAuthentication(LmsAuthenticationReason.finalRootValidationStarted);
      if (await _validateCurrentStore()) {
        // A specific endpoint can reject access while the school root still
        // verifies this account. Stop this read without another activity retry
        // or deleting the independently validated session.
        throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
      }
      // The current root has explicitly rejected login or the expected user.
      // Unknown/network responses throw above and preserve stored material.
      await _discardAuthentication();
    } else {
      _authenticationRecoveryPending = true;
      _invalidate();
    }
  }

  Future<void> _discardAuthentication() async {
    _recordAuthentication(LmsAuthenticationReason.credentialsDiscarded);
    _authenticationRecoveryPending = false;
    final principal = _expectedPrincipal ?? _principalId;
    _invalidate();
    if (principal == null) {
      await _storage.delete(key: _storageKey);
      return;
    }
    // Retaining an identity is not retaining an authenticated session. It lets
    // the owner recognize their last successful data after expiry/restart.
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'owner': ownerId,
        'school': schoolId,
        'principal': principal,
        'cookies': const [],
      }),
    );
  }

  void _checkGeneration(int expected) {
    if (expected != _generation || _disposed || !identical(_active, this)) {
      throw const LmsWebSessionException(
        LmsWebSessionError.authenticationRequired,
      );
    }
  }

  void _checkNotRetired() {
    if (_disposed) {
      throw const LmsWebSessionException(
        LmsWebSessionError.authenticationRequired,
      );
    }
  }

  void _checkLifecycle(int expected) {
    _checkNotRetired();
    if (expected != _generation) {
      throw const LmsWebSessionException(
        LmsWebSessionError.authenticationRequired,
      );
    }
  }

  Future<void> _startHeadless() async {
    if (_controller != null) return;
    final startedGeneration = _generation;
    if (_usesAppleStore) {
      try {
        final available = await _cookieChannel.invokeMethod<bool>(
          'canStartHeadless',
          {'host': baseUrl.host},
        );
        _checkGeneration(startedGeneration);
        if (available != true) {
          throw const LmsWebSessionException(
            LmsWebSessionError.hostUnavailable,
          );
        }
      } on PlatformException catch (error) {
        throw _cookieStoreError(error);
      }
    }
    final loaded = Completer<void>();
    _pageLoaded = loaded;
    _headless = HeadlessInAppWebView(
      webViewEnvironment: _environment,
      initialUrlRequest: URLRequest(url: WebUri(baseUrl.toString())),
      initialSettings: webViewSettings,
      onWebViewCreated: (controller) {
        if (!_disposed &&
            startedGeneration == _generation &&
            identical(_active, this)) {
          _controller = controller;
        }
      },
      onLoadStop: (_, _) => pageLoadFinished(),
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true) {
          if (_automaticLogin) {
            _lastAutomaticLoginFailure = LmsLoginFailure.fromError(error);
          }
          pageLoadFailed();
        }
      },
      onReceivedHttpError: (_, request, response) {
        if (request.isForMainFrame == true &&
            (response.statusCode ?? 0) >= 400) {
          if (_automaticLogin) {
            _lastAutomaticLoginFailure = LmsLoginFailure.serverRejected;
          }
          pageLoadFailed();
        }
      },
      shouldOverrideUrlLoading: (_, action) async {
        final uri = action.request.url?.uriValue;
        return uri != null &&
                ((_automaticLogin &&
                        (policy.isSchoolOrigin(uri) ||
                            uri.scheme == 'https' &&
                                uri.host == 'smsso.smu.ac.kr' &&
                                uri.port == 443 &&
                                uri.userInfo.isEmpty)) ||
                    policy.isSchoolOrigin(uri) &&
                        const {
                          '/',
                          '/login.php',
                          '/login/index.php',
                        }.contains(uri.path))
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onJsAlert: (_, request) async {
        if (!_automaticLogin) return null;
        _automaticLoginChallenge = true;
        return JsAlertResponse(handledByClient: true);
      },
      onJsConfirm: (_, request) async {
        if (!_automaticLogin) return null;
        _automaticLoginChallenge = true;
        return JsConfirmResponse(
          handledByClient: true,
          action: JsConfirmResponseAction.CANCEL,
        );
      },
      onJsPrompt: (_, request) async {
        if (!_automaticLogin) return null;
        _automaticLoginChallenge = true;
        return JsPromptResponse(
          handledByClient: true,
          action: JsPromptResponseAction.CANCEL,
        );
      },
      onCreateWindow: (_, _) async => false,
    );
    try {
      // Attach the error handler before the first native page callback.
      final completion = loaded.future.timeout(const Duration(seconds: 25));
      await Future.wait<void>([
        completion,
        Future<void>.sync(() => _headless!.run()),
      ], eagerError: true);
    } catch (_) {
      await _headless?.dispose();
      _headless = null;
      _controller = null;
      throw const LmsWebSessionException(LmsWebSessionError.network);
    }
  }

  Future<void> _discardUnboundHeadless() async {
    final headless = _headless;
    if (headless == null || _nativeCookieBound || _keptAlive) return;
    try {
      await headless.dispose();
    } catch (_) {
      // Retain a failed disposal handle so close/a later retry can finish
      // cleanup. A detached view never authorizes another cookie store.
      return;
    }
    if (identical(_headless, headless)) {
      _headless = null;
      _controller = null;
      _pageLoaded = null;
    }
  }

  static LmsWebSessionException _cookieStoreError(PlatformException error) =>
      LmsWebSessionException(switch (error.code) {
        'school_view_missing' => LmsWebSessionError.viewUnavailable,
        'school_marker_missing' => LmsWebSessionError.viewMismatch,
        'school_view_ambiguous' => LmsWebSessionError.viewAmbiguous,
        'school_script_unavailable' => LmsWebSessionError.scriptUnavailable,
        // Never include native messages/details, cookies, or the marker.
        _ => LmsWebSessionError.invalidResponse,
      });

  /// The visible login view can outlive its Flutter route through keepAlive.
  /// Its callbacks must still settle restoration loads after the route closes.
  void pageLoadFinished() {
    _lastPageLoadedAt = DateTime.now();
    final pending = _pageLoaded;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  void pageLoadFailed() {
    final pending = _pageLoaded;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const LmsWebSessionException(LmsWebSessionError.network),
      );
    }
  }

  Future<void> _reloadRoot() async {
    final loaded = Completer<void>();
    _pageLoaded = loaded;
    final waiting = loaded.future.timeout(const Duration(seconds: 25));
    try {
      // Observe both immediately: a native load-failure callback can arrive
      // before loadUrl's method-channel Future settles.
      await Future.wait<void>([
        waiting,
        Future<void>.sync(
          () => _controller!.loadUrl(
            urlRequest: URLRequest(url: WebUri(baseUrl.toString())),
          ),
        ),
      ], eagerError: true);
    } catch (_) {
      throw const LmsWebSessionException(LmsWebSessionError.network);
    }
  }

  Future<void> _bindCookieStore() async {
    if (!_usesAppleStore || _nativeCookieBound) return;
    final startedGeneration = _generation;
    _checkGeneration(startedGeneration);
    final controller = _controller;
    final uri = (await controller?.getUrl())?.uriValue;
    _checkGeneration(startedGeneration);
    if (controller == null || uri == null) {
      throw const LmsWebSessionException(LmsWebSessionError.viewUnavailable);
    }
    if (!policy.isSchoolOrigin(uri)) {
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    final marker = 'daily-lms-${const Uuid().v4()}';
    final result = await controller.callAsyncJavaScript(
      functionBody:
          'const previous = window.name; window.name = marker; return previous;',
      arguments: {'marker': marker},
    );
    final originalName = result?.value;
    if (result?.error != null) {
      throw const LmsWebSessionException(LmsWebSessionError.scriptUnavailable);
    }
    if (originalName is! String) {
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    try {
      _checkGeneration(startedGeneration);
      _nativeCookieBound =
          await _cookieChannel.invokeMethod<bool>('bind', {
            'marker': marker,
            'host': baseUrl.host,
          }) ==
          true;
      // Keep the native binding flag even if retirement happened during bind;
      // close awaits this operation, then clears that exact dedicated store.
      _checkGeneration(startedGeneration);
      if (!_nativeCookieBound) {
        throw const LmsWebSessionException(LmsWebSessionError.viewUnavailable);
      }
    } on PlatformException catch (error) {
      throw _cookieStoreError(error);
    } finally {
      await controller.callAsyncJavaScript(
        functionBody: 'if (window.name === marker) window.name = previous;',
        arguments: {'marker': marker, 'previous': originalName},
      );
    }
    _checkGeneration(startedGeneration);
  }

  Future<List<Map<String, dynamic>>> _authenticationCookies() async {
    if (_usesAppleStore) {
      final values = await _cookieChannel.invokeListMethod<dynamic>('read', {
        'host': baseUrl.host,
      });
      return [
        for (final value in values ?? const [])
          if (value is Map &&
              value['name'] is String &&
              _isSessionCookie(value['name'] as String))
            Map<String, dynamic>.from(value),
      ];
    }
    if (Platform.isWindows) {
      final raw = await _controller!.callDevToolsProtocolMethod(
        methodName: 'Network.getCookies',
        parameters: {
          'urls': [baseUrl.toString()],
        },
      );
      final value = raw is String ? jsonDecode(raw) : raw;
      final cookies = value is Map ? value['cookies'] : null;
      if (cookies is! List) return [];
      return [
        for (final cookie in cookies)
          if (cookie is Map &&
              cookie['name'] is String &&
              _isSessionCookie(cookie['name'] as String))
            {
              'name': cookie['name'],
              'value': cookie['value'],
              'expires':
                  cookie['session'] == true ||
                      (cookie['expires'] as num? ?? -1) <= 0
                  ? null
                  : ((cookie['expires'] as num) * 1000).toInt(),
            },
      ];
    }
    final cookies = await _cookies.getCookies(url: WebUri(baseUrl.toString()));
    return [
      for (final cookie in cookies)
        if (_isSessionCookie(cookie.name))
          {
            'name': cookie.name,
            'value': cookie.value,
            'expires': cookie.expiresDate,
          },
    ];
  }

  Future<void> _restoreCookies(List<dynamic> input) async {
    final startedGeneration = _generation;
    _checkGeneration(startedGeneration);
    final cookies = <Map<String, dynamic>>[];
    for (final raw in input) {
      if (raw is! Map ||
          raw['name'] is! String ||
          raw['value'] is! String ||
          !_isSessionCookie(raw['name'] as String)) {
        continue;
      }
      final expires = raw['expires'] as int?;
      if (expires != null && expires <= DateTime.now().millisecondsSinceEpoch) {
        continue;
      }
      cookies.add({
        'name': raw['name'],
        'value': raw['value'],
        'expires': expires,
      });
    }
    if (cookies.isEmpty) {
      _checkGeneration(startedGeneration);
      await _discardAuthentication();
      throw const LmsWebSessionException(
        LmsWebSessionError.authenticationRequired,
      );
    }
    if (_usesAppleStore) {
      final restored = await _cookieChannel.invokeMethod<bool>('write', {
        'host': baseUrl.host,
        'cookies': cookies,
      });
      _checkGeneration(startedGeneration);
      if (restored != true) {
        throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
      }
      return;
    }
    for (final cookie in cookies) {
      _checkGeneration(startedGeneration);
      if (Platform.isWindows) {
        await _controller!.callDevToolsProtocolMethod(
          methodName: 'Network.setCookie',
          parameters: {
            'url': baseUrl.toString(),
            'name': cookie['name'],
            'value': cookie['value'],
            'path': '/',
            'secure': true,
            'httpOnly': true,
            if (cookie['expires'] != null)
              'expires': (cookie['expires'] as int) / 1000,
          },
        );
      } else {
        await _cookies.setCookie(
          url: WebUri(baseUrl.toString()),
          name: cookie['name'] as String,
          value: cookie['value'] as String,
          path: '/',
          expiresDate: cookie['expires'] as int?,
          isSecure: true,
          isHttpOnly: true,
        );
      }
      _checkGeneration(startedGeneration);
    }
  }

  /// Uses only the school's publicly verified SSO form; submits credentials once.
  /// No secrets are interpolated into scripts, URLs, diagnostics or exceptions.
  Future<bool> loginAutomatically(
    LmsLocalCredentials credentials, {
    String? expectedPrincipal,
  }) async {
    _checkNotRetired();
    _lastAutomaticLoginFailure = null;
    bool fail(LmsLoginFailure failure) {
      _lastAutomaticLoginFailure = failure;
      return false;
    }

    if (schoolId != 'smu' ||
        credentials.paused ||
        _loginVisible ||
        _automaticLogin ||
        _authenticationRejectedReason ==
            LmsAuthenticationReason.rootPrincipalMismatch) {
      return fail(
        hasPrincipalMismatch
            ? LmsLoginFailure.accountMismatch
            : _loginVisible || _automaticLogin
            ? LmsLoginFailure.busy
            : LmsLoginFailure.unsupportedForm,
      );
    }
    await _activate();
    _expectedPrincipal = expectedPrincipal ?? _expectedPrincipal;
    _automaticLogin = true;
    _automaticLoginChallenge = false;
    var stage = 'entry';
    _recordAuthentication(LmsAuthenticationReason.automaticLoginStarted);
    try {
      await _startHeadless();
      _recordAuthentication(LmsAuthenticationReason.automaticHeadlessReady);
      await _bindCookieStore();
      _recordAuthentication(LmsAuthenticationReason.automaticStoreBound);
      final started = _generation;
      final loaded = Completer<void>();
      _pageLoaded = loaded;
      await Future.wait<void>([
        loaded.future.timeout(const Duration(seconds: 25)),
        Future<void>.sync(
          () => _controller!.loadUrl(
            urlRequest: URLRequest(url: WebUri(loginUrl.toString())),
          ),
        ),
      ], eagerError: true);
      _recordAuthentication(LmsAuthenticationReason.automaticEntryLoaded);
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        if (_automaticLoginChallenge) {
          _recordAuthentication(
            LmsAuthenticationReason.automaticLoginChallenge,
          );
          return fail(LmsLoginFailure.additionalAuthentication);
        }
        _checkGeneration(started);
        final result = await _controller!
            .callAsyncJavaScript(
              functionBody: automaticLoginScript,
              arguments: {
                'stage': stage,
                'username': credentials.username,
                'password': credentials.password,
              },
            )
            .timeout(const Duration(seconds: 5));
        _checkGeneration(started);
        final data = result?.value;
        if (result?.error != null) {
          return fail(LmsLoginFailure.scriptUnavailable);
        }
        if (data is! Map) return fail(LmsLoginFailure.invalidResponse);
        if (data['state'] == 'blocked') {
          return fail(LmsLoginFailure.fromSchoolCode(data['failure']));
        }
        switch (data['state']) {
          case 'entrySubmitted':
            stage = 'sso';
          case 'credentialsSubmitted':
            _recordAuthentication(
              LmsAuthenticationReason.automaticCredentialsSubmitted,
            );
            stage = 'submitted';
          case 'authenticated':
            try {
              if (await verifyAuthentication() != null) return true;
              if (_authenticationRejectedReason != null) {
                return fail(
                  hasPrincipalMismatch
                      ? LmsLoginFailure.accountMismatch
                      : LmsLoginFailure.authenticationUnconfirmed,
                );
              }
            } on LmsWebSessionException catch (error) {
              if (error.code != LmsWebSessionError.invalidResponse) rethrow;
              // A transient SSO return page can precede the dashboard.
            }
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return fail(LmsLoginFailure.timedOut);
    } on LmsWebSessionException catch (error) {
      _lastAutomaticLoginFailure ??= LmsLoginFailure.fromError(error);
      rethrow;
    } catch (error) {
      _lastAutomaticLoginFailure ??= LmsLoginFailure.fromError(error);
      throw const LmsWebSessionException(LmsWebSessionError.network);
    } finally {
      _automaticLogin = false;
      // Never retain password fields in a failed background login page.
      if (!isAuthenticated) await close();
    }
  }

  @visibleForTesting
  static const automaticLoginScript =
      r'''    if (location.protocol !== 'https:' || (location.port && location.port !== '443')) return {state:'blocked'};
    if (document.readyState !== 'complete') return {state:'waiting'};
    if (!['ecampus.smu.ac.kr', 'smsso.smu.ac.kr'].includes(location.hostname)) return {state:'blocked'};
    const schoolErrors = [...document.querySelectorAll('.alert-danger, .loginerrors, #loginerrormsg, #error_message')]
      .filter(e => e.getClientRects().length).map(e => e.textContent || '').join(' ');
    if (/계정.*잠[금김]|로그인.*(시도.*초과|제한)|account.*locked|too many.*attempt/i.test(schoolErrors)) return {state:'blocked', failure:'accountLocked'};
    if (/비밀번호.*(만료|변경.*필요)|password.*(expired|must.*change)/i.test(schoolErrors)) return {state:'blocked', failure:'passwordExpired'};
    if (/(아이디|비밀번호).*(일치하지|올바르지|틀렸|잘못|오류)|invalid (username|password)|incorrect (username|password)/i.test(schoolErrors)) return {state:'blocked', failure:'credentialsRejected'};
    if (/추가.?인증|보안.?문자|인증.?번호|captcha|one.time.password/i.test(schoolErrors)) return {state:'blocked', failure:'additionalAuthentication'};
    if (location.hostname === 'ecampus.smu.ac.kr') {
      if (!document.querySelector('input[type="password"]')) return {state:'authenticated'};
      if (stage !== 'entry') return {state:'waiting'};
      const f = document.querySelector('form.form-sso-login');
      if (!f) {
        // The official Coursemos mobile theme offers this local login form,
        // without the desktop SSO entry form. Submit it once, on its own origin.
        const mobile = document.querySelector('form.form-login');
        if (!mobile || mobile.method.toLowerCase() !== 'post' || new URL(mobile.action).origin !== location.origin || new URL(mobile.action).pathname !== '/login/index.php') return {state:'blocked'};
        const user = mobile.querySelector('input[name="username"]'), pwd = mobile.querySelector('input[name="password"]');
        if (!user || !pwd || pwd.type !== 'password' || mobile.dataset.dailyAutoSubmitted === 'true') return {state:'blocked'};
        if ([...mobile.querySelectorAll('input')].some(e => e.getClientRects().length && /captcha|otp|motp/i.test(e.id + ' ' + e.name))) return {state:'blocked', failure:'additionalAuthentication'};
        mobile.dataset.dailyAutoSubmitted = 'true';
        user.value = username; pwd.value = password;
        user.dispatchEvent(new Event('input', {bubbles:true})); pwd.dispatchEvent(new Event('input', {bubbles:true}));
        setTimeout(() => mobile.requestSubmit(), 0);
        return {state:'credentialsSubmitted'};
      }
      if (f.method.toLowerCase() !== 'post' || new URL(f.action).origin !== location.origin || new URL(f.action).pathname !== '/exsignon/sso/sso_idp_login.php') return {state:'blocked'};
      setTimeout(() => f.requestSubmit(), 0);
      return {state:'entrySubmitted'};
    }
    if (location.hostname !== 'smsso.smu.ac.kr') return {state:'blocked'};
    const f = document.querySelector('form#loginFrm');
    if (!f) return {state:'waiting'};
    if (stage === 'submitted') return {state: f.dataset.dailyAutoSubmitted === 'true' ? 'waiting' : 'blocked'};
    if (stage !== 'sso' || f.method.toLowerCase() !== 'post' || new URL(f.action).origin !== location.origin || new URL(f.action).pathname !== '/Login.do') return {state:'blocked'};
    const user = f.querySelector('#user_id'), pwd = f.querySelector('#user_password');
    if (!user || !pwd || pwd.type !== 'password' || typeof window.doLogin !== 'function') return {state:'blocked'};
    if ([...f.querySelectorAll('input')].some(e => e.getClientRects().length && /captcha|otp|motp/i.test(e.id + ' ' + e.name))) return {state:'blocked', failure:'additionalAuthentication'};
    const remember = document.querySelector('#saveIdIpt');
    if (remember) remember.checked = false;
    f.dataset.dailyAutoSubmitted = 'true';
    user.value = username; pwd.value = password;
    user.dispatchEvent(new Event('input', {bubbles:true})); pwd.dispatchEvent(new Event('input', {bubbles:true}));
    setTimeout(() => window.doLogin(), 0);
    return {state:'credentialsSubmitted'};
  ''';

  /// Inspect fixed school error categories without submitting a form. The
  /// inspect stage cannot enter either credential-submission branch.
  Future<LmsLoginFailure> explainLoginFailure([Object? error]) async {
    if (hasPrincipalMismatch) return LmsLoginFailure.accountMismatch;
    if (error != null &&
        (error is! LmsWebSessionException ||
            error.code != LmsWebSessionError.invalidResponse)) {
      return LmsLoginFailure.fromError(error);
    }
    final started = _generation;
    final controller = _controller;
    if (controller != null && !_disposed) {
      try {
        final result = await controller
            .callAsyncJavaScript(
              functionBody: automaticLoginScript,
              arguments: {'stage': 'inspect', 'username': '', 'password': ''},
            )
            .timeout(const Duration(seconds: 2));
        _checkGeneration(started);
        final data = result?.value;
        if (data is Map && data['failure'] != null) {
          return LmsLoginFailure.fromSchoolCode(data['failure']);
        }
      } catch (_) {
        /* Retain the original safe failure category. */
      }
    }
    return error == null
        ? LmsLoginFailure.authenticationUnconfirmed
        : LmsLoginFailure.fromError(error);
  }

  /// Called only after the user explicitly opens the login page.
  Future<void> beginLogin() async {
    _checkNotRetired();
    try {
      await _preparing;
    } catch (_) {
      /* Manual login can recover. */
    }
    await _closing;
    _checkNotRetired();
    await _readTail;
    _checkNotRetired();
    await _verification;
    _checkNotRetired();
    await _activate();
    _checkNotRetired();
    _loginVisible = true;
    _authenticationRecoveryPending = false;
    _authenticationRecoveryAttempted = false;
    _expectedPrincipal = null;
    _generation++;
    _notify();
  }

  void attachLoginController(InAppWebViewController controller) {
    if (_disposed || !_loginVisible || !identical(_active, this)) return;
    _controller = controller;
    _keptAlive = true;
  }

  void recordLoginNavigation(Uri? uri) {
    if (!_disposed &&
        _loginVisible &&
        identical(_active, this) &&
        uri != null &&
        policy.allowsLoginNavigation(uri) &&
        uri.scheme == 'https') {
      _visitedLoginUrls.add(uri.replace(query: '', fragment: ''));
    }
  }

  /// Mobile themes can omit the own-preferences menu link. In that case ask
  /// the school's read-only, current-user preferences page, never a supplied ID
  /// or another student's profile. Its server enforces login and rejects guests.
  @visibleForTesting
  static const authenticationScript = r'''
      if (location.origin !== origin) return {unexpectedOrigin: true};
      if (document.querySelector('input[type="password"]')) return {authenticationRequired: true};
      const ownIds = doc => {
        const ids = new Set();
        for (const a of doc.querySelectorAll('a[href]')) {
          try {
            const u = new URL(a.getAttribute('href'), origin);
            const id = u.searchParams.get('id');
            if (u.origin === origin && u.pathname === '/user/edit.php' && /^[1-9][0-9]*$/.test(id || '')) ids.add(id);
          } catch (_) { /* An invalid link cannot establish identity. */ }
        }
        return ids;
      };
      const ids = ownIds(document);
      if (ids.size > 1) return {unrecognized: true};
      if (ids.size === 0) {
        const abort = new AbortController();
        const timer = setTimeout(() => abort.abort(), 10000);
        try {
          const response = await fetch(origin + '/user/preferences.php', {
            method:'GET', credentials:'same-origin', mode:'same-origin',
            redirect:'manual', cache:'no-store', signal:abort.signal
          });
          if (response.status === 401) return {authenticationRequired:true};
          if (!response.ok || response.type === 'opaqueredirect') return {unrecognized:true};
          const u = new URL(response.url);
          if (u.origin !== origin || u.pathname !== '/user/preferences.php' || u.search) return {unexpectedOrigin:true};
          if (!(response.headers.get('content-type') || '').toLowerCase().includes('text/html')) return {unrecognized:true};
          const source = await response.text();
          if (source.length > 4000000) return {unrecognized:true};
          const preferences = new DOMParser().parseFromString(source, 'text/html');
          if (preferences.body?.id !== 'page-user-preferences' || preferences.querySelector('input[type="password"]')) return {unrecognized:true};
          const current = ownIds(preferences);
          if (current.size !== 1) return {unrecognized:true};
          ids.add(Array.from(current)[0]);
        } catch (_) { return {network:true}; }
        finally { clearTimeout(timer); }
      }
      return {
        principal: Array.from(ids)[0], url: location.href, identityVerified: true,
        dashboard: location.pathname === '/' && !location.search
          ? document.documentElement.outerHTML : null
      };
    ''';

  Future<String?> verifyAuthentication() {
    _checkNotRetired();
    return _verification ??= _verifyAuthentication().whenComplete(
      () => _verification = null,
    );
  }

  Future<String?> _verifyAuthentication() async {
    _verifiedDashboard = null;
    _verifiedDashboardAt = null;
    _verifiedDashboardGeneration = null;
    final startedGeneration = _generation;
    final controller = _controller;
    if (controller == null) {
      throw const LmsWebSessionException(LmsWebSessionError.viewUnavailable);
    }
    _checkGeneration(startedGeneration);
    final at = (await controller.getUrl())?.uriValue;
    _checkGeneration(startedGeneration);
    if (at == null) {
      throw const LmsWebSessionException(LmsWebSessionError.viewUnavailable);
    }
    if (!policy.isSchoolOrigin(at)) {
      _recordAuthentication(LmsAuthenticationReason.rootOriginChanged);
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    await _bindCookieStore();
    _checkGeneration(startedGeneration);
    final value = await controller.callAsyncJavaScript(
      functionBody: authenticationScript,
      arguments: {'origin': baseUrl.origin},
    );
    _checkGeneration(startedGeneration);
    if (value == null || value.error != null) {
      _recordAuthentication(LmsAuthenticationReason.rootUnrecognized);
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    final verified = value.value;
    if (verified is Map && verified['network'] == true) {
      throw const LmsWebSessionException(LmsWebSessionError.network);
    }
    final id = verified is Map && verified['principal'] is String
        ? verified['principal']
        : verified;
    if ((id is Map && id['authenticationRequired'] == true) ||
        (id is String &&
            _expectedPrincipal != null &&
            _expectedPrincipal != id)) {
      _principalId = null;
      _generation++;
      _authenticationRejectedGeneration = _generation;
      _authenticationRejectedReason = id is String
          ? LmsAuthenticationReason.rootPrincipalMismatch
          : LmsAuthenticationReason.rootLoginForm;
      _recordAuthentication(_authenticationRejectedReason!);
      _notify();
      return null;
    }
    if (id is! String) {
      _recordAuthentication(
        id is Map && id['unexpectedOrigin'] == true
            ? LmsAuthenticationReason.rootOriginChanged
            : LmsAuthenticationReason.rootUnrecognized,
      );
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    _authenticationRejectedGeneration = null;
    _authenticationRejectedReason = null;
    if (_principalId != id) {
      _principalId = id;
      _generation++;
    }
    final authenticatedGeneration = _generation;
    try {
      await _persist();
      _checkGeneration(authenticatedGeneration);
    } catch (_) {
      if (!_disposed && authenticatedGeneration == _generation) _invalidate();
      rethrow;
    }
    // Restoration/login has just loaded this authenticated dashboard. Consume
    // it once, immediately, instead of fetching the same document again. No
    // quiz/index data is cached and subsequent reads still validate identity.
    final snapshotUrl = verified is Map && verified['url'] is String
        ? Uri.tryParse(verified['url'] as String)
        : null;
    final snapshot = verified is Map ? verified['dashboard'] : null;
    if (snapshotUrl == baseUrl.resolve('/') &&
        snapshot is String &&
        snapshot.length <= 4000000 &&
        (policy.principalFromHtml(snapshot) == id ||
            verified is Map && verified['identityVerified'] == true) &&
        html.parse(snapshot).querySelector('input[type="password"]') == null) {
      _verifiedDashboard = LmsHtmlPage(url: snapshotUrl!, html: snapshot);
      // Verification alone does not make an old DOM a fresh server response.
      _verifiedDashboardAt = _lastPageLoadedAt;
      _verifiedDashboardGeneration = _generation;
    }
    _recordAuthentication(LmsAuthenticationReason.rootAccepted);
    _notify();
    return id;
  }

  bool _isRecognizedMobilePage(String? bodyId, Uri uri) => switch (uri.path) {
    '/' => bodyId == 'page-site-index',
    '/course/view.php' => bodyId?.startsWith('page-course-view-') == true,
    '/mod/assign/index.php' => bodyId == 'page-mod-assign-index',
    '/mod/quiz/index.php' => bodyId == 'page-mod-quiz-index',
    '/mod/quiz/view.php' => bodyId == 'page-mod-quiz-view',
    '/report/ubcompletion/user_progress.php' =>
      bodyId == 'page-report-ubcompletion-user_progress',
    _ => false,
  };

  Future<void> finishLogin({required bool authenticated}) async {
    if (authenticated) {
      _checkGeneration(_generation);
      if (!isAuthenticated) {
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
    }
    _loginVisible = false;
    // The visible view now owns the converted headless view, if there was one.
    if (_keptAlive) _headless = null;
    if (!authenticated) {
      await close();
    } else {
      _notify();
    }
  }

  Future<LmsHtmlPage> fetchHtml(Uri uri) async {
    if (!policy.allowsRead(uri)) {
      throw const LmsWebSessionException(LmsWebSessionError.disallowedRequest);
    }
    final before = _readTail;
    final done = Completer<void>();
    _readTail = done.future;
    await before;
    try {
      if (_loginVisible) {
        throw const LmsWebSessionException(LmsWebSessionError.busy);
      }
      if (!isAuthenticated || _controller == null) {
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
      final startedGeneration = _generation;
      final snapshot = _verifiedDashboard;
      final snapshotAt = _verifiedDashboardAt;
      _verifiedDashboard = null;
      _verifiedDashboardAt = null;
      if (uri == baseUrl.resolve('/') &&
          snapshot != null &&
          snapshotAt != null &&
          _verifiedDashboardGeneration == startedGeneration &&
          DateTime.now().difference(snapshotAt) >= Duration.zero &&
          DateTime.now().difference(snapshotAt) < const Duration(seconds: 2)) {
        return snapshot;
      }
      Map<String, dynamic>? nativeReport;
      if (Platform.isIOS &&
          uri.path == '/report/ubcompletion/user_progress.php') {
        final cookies = await _authenticationCookies();
        _checkGeneration(startedGeneration);
        nativeReport = await LmsLearningReportClient().read(uri, cookies);
      }
      final result = nativeReport == null
          ? await _controller!
                .callAsyncJavaScript(
                  functionBody: '''
        if (location.origin !== origin) return {status: 'auth', reason: 'origin'};
        const abort = new AbortController();
        const timer = setTimeout(() => abort.abort(), 20000);
        try {
          const response = await fetch(url, {method: 'GET', credentials: 'same-origin',
            mode: 'same-origin', redirect: 'manual', cache: 'no-store', signal: abort.signal});
          if (response.type === 'opaqueredirect') return {status: 'auth', reason: 'redirect'};
          if (response.status === 401) return {status: 'auth', reason: 'unauthorized'};
          if (response.status === 403) return {status: 'invalid'};
          if (!response.ok) return {status: 'network'};
          if (!(response.headers.get('content-type') || '').toLowerCase().includes('text/html')) return {status: 'invalid'};
          const body = await response.text();
          if (body.length > 4000000) return {status: 'invalid'};
          return {status: 'ok', url: response.url, html: body};
        } catch (_) { return {status: 'network'}; }
        finally { clearTimeout(timer); }
      ''',
                  arguments: {'origin': baseUrl.origin, 'url': uri.toString()},
                )
                .timeout(const Duration(seconds: 25))
          : null;
      if (startedGeneration != _generation || !isAuthenticated) {
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
      final data = nativeReport ?? result?.value;
      if (data is! Map) {
        throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
      }
      if (data['status'] == 'auth') {
        final reason = switch (data['reason']) {
          'origin' => LmsAuthenticationReason.readOriginChanged,
          'redirect' => LmsAuthenticationReason.readRedirect,
          'unauthorized' => LmsAuthenticationReason.readUnauthorized,
          _ => null,
        };
        if (reason == null) {
          throw const LmsWebSessionException(
            LmsWebSessionError.invalidResponse,
          );
        }
        await _rejectReadAuthentication(reason);
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
      if (data['status'] != 'ok') {
        throw LmsWebSessionException(
          data['status'] == 'invalid'
              ? LmsWebSessionError.invalidResponse
              : LmsWebSessionError.network,
        );
      }
      final finalUrl = Uri.tryParse(data['url'] as String? ?? '');
      final source = data['html'];
      if (finalUrl == null ||
          !policy.allowsRead(finalUrl) ||
          source is! String) {
        throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
      }
      // A quiz access-password prompt is not a revoked school login. Leave
      // such a detail unresolved without discarding the authenticated session.
      if (finalUrl.path == '/mod/quiz/view.php') {
        final document = html.parse(source);
        if (document.body?.id == 'page-mod-quiz-view' &&
            document.querySelector('input[type="password"]') != null) {
          throw const LmsWebSessionException(
            LmsWebSessionError.invalidResponse,
          );
        }
      }
      var pagePrincipal = policy.principalFromHtml(source);
      final document = html.parse(source);
      if (pagePrincipal == null &&
          document.querySelector('input[type="password"]') == null &&
          _isRecognizedMobilePage(document.body?.id, finalUrl)) {
        // A mobile course page lacks the desktop own-user link. Confirm the
        // current user through the same private view and server preferences;
        // do not substitute a classmate link or the previously cached identity.
        pagePrincipal = await verifyAuthentication();
        _checkGeneration(startedGeneration);
      }
      if (pagePrincipal == null &&
          html.parse(source).querySelector('input[type="password"]') == null) {
        // A changed/error page is not proof that the school session expired.
        throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
      }
      if (pagePrincipal != _principalId) {
        if (pagePrincipal == null) {
          await _rejectReadAuthentication(
            LmsAuthenticationReason.readLoginForm,
          );
        } else {
          // A different verified user is not an expired cookie. Never restore
          // or retry a read under that newly observed identity automatically.
          _recordAuthentication(LmsAuthenticationReason.readPrincipalMismatch);
          await _discardAuthentication();
        }
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
      final rotated = data['rotatedCookies'];
      if (rotated is List && rotated.isNotEmpty) {
        final previous = await _authenticationCookies();
        _checkGeneration(startedGeneration);
        final names = rotated.whereType<Map>().map((c) => c['name']).toSet();
        await _restoreCookies([
          ...previous.where((c) => !names.contains(c['name'])),
          ...rotated,
        ]);
        _checkGeneration(startedGeneration);
      }
      await _persist();
      _checkGeneration(startedGeneration);
      return LmsHtmlPage(url: finalUrl, html: source);
    } on LmsWebSessionException {
      rethrow;
    } catch (_) {
      throw const LmsWebSessionException(LmsWebSessionError.network);
    } finally {
      done.complete();
    }
  }

  static bool _isSessionCookie(String name) =>
      name == 'MoodleSession' || name.startsWith('MoodleSession_');

  Future<void> _persist() async {
    final startedGeneration = _generation;
    final principal = _principalId;
    _checkGeneration(startedGeneration);
    if (principal == null) {
      throw const LmsWebSessionException(
        LmsWebSessionError.authenticationRequired,
      );
    }
    final authentication = await _authenticationCookies();
    _checkGeneration(startedGeneration);
    if (authentication.isEmpty) {
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    final encoded = jsonEncode({
      'owner': ownerId,
      'school': schoolId,
      'principal': principal,
      'cookies': authentication,
    });
    // Still inspect live cookies on every authenticated response. Only skip
    // the secure-store write when this instance has successfully saved the
    // exact same identity and cookie snapshot; rotations are saved immediately.
    final fingerprint = sha256.convert(utf8.encode(encoded)).toString();
    if (fingerprint != _lastPersistedAuthentication) {
      try {
        await _storage.write(key: _storageKey, value: encoded);
      } catch (_) {
        throw const LmsWebSessionException(LmsWebSessionError.secureStorage);
      }
      _checkGeneration(startedGeneration);
      _lastPersistedAuthentication = fingerprint;
    }
    _checkGeneration(startedGeneration);
    _expectedPrincipal = principal;
  }

  Future<void> _clearSchoolCookies() async {
    if (_usesAppleStore) {
      if (_nativeCookieBound) {
        await _cookieChannel.invokeMethod<bool>('clear', {
          'host': baseUrl.host,
        });
      }
      return;
    }
    if (Platform.isWindows) {
      // This controller belongs to Daily's private WebView2 profile, not Edge.
      if (_controller != null) {
        await _controller!.callDevToolsProtocolMethod(
          methodName: 'Network.clearBrowserCookies',
        );
      }
      return;
    }
    final roots = <Uri>{
      baseUrl,
      ..._visitedLoginUrls,
      if (schoolId == 'smu') Uri.https('smsso.smu.ac.kr', '/'),
    };
    for (final uri in roots) {
      final cookies = await _cookies.getCookies(url: WebUri(uri.toString()));
      for (final cookie in cookies) {
        await _cookies.deleteCookie(
          url: WebUri(uri.toString()),
          name: cookie.name,
          path: cookie.path ?? '/',
          domain: cookie.domain,
        );
      }
    }
    _visitedLoginUrls.clear();
  }

  void _invalidate() {
    _lastPersistedAuthentication = null;
    _verifiedDashboard = null;
    _verifiedDashboardAt = null;
    _verifiedDashboardGeneration = null;
    _lastPageLoadedAt = null;
    _principalId = null;
    _authenticationRejectedGeneration = null;
    _authenticationRejectedReason = null;
    _generation++;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      await close();
    } finally {
      _expectedPrincipal = null;
      _authenticationRecoveryPending = false;
      await _storage.delete(key: _storageKey);
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _invalidate();
    _recordAuthentication(LmsAuthenticationReason.closed);
    return _closing = _close().whenComplete(() => _closing = null);
  }

  Future<void> _close() async {
    _lastPersistedAuthentication = null;
    try {
      await _preparing;
    } catch (_) {
      /* Dispose failed restores too. */
    }

    try {
      await _verification;
    } catch (_) {
      /* An invalidated verification must finish before cookie-store disposal. */
    }

    _loginVisible = false;
    if (!identical(_active, this)) return;
    await _readTail;
    try {
      await _controller?.stopLoading();
      await _clearSchoolCookies();
    } finally {
      if (_keptAlive && _keepAlive != null) {
        await InAppWebViewController.disposeKeepAlive(_keepAlive!);
      } else {
        await _headless?.dispose();
      }
      await _environment?.dispose();
      _nativeCookieBound = false;
      _environment = null;
      _headless = null;
      _controller = null;
      _keepAlive = null;
      _keptAlive = false;
      _active = null;
    }
  }

  @override
  void dispose() {
    unawaited(retire().catchError((_) {}));
    super.dispose();
  }

  /// Owner/school changes permanently invalidate old login pages immediately.
  /// A normal login cancellation uses [close] so the current session can retry.
  Future<void> retire() {
    _disposed = true;
    return close();
  }
}
