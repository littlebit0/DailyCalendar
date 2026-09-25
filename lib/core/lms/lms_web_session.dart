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

enum LmsWebSessionError {
  authenticationRequired,
  network,
  invalidResponse,
  unsupported,
  busy,
  disallowedRequest,
}

/// Deliberately contains no response body, URL query, cookie, or platform error.
class LmsWebSessionException implements Exception {
  const LmsWebSessionException(this.code);
  final LmsWebSessionError code;
  @override
  String toString() => 'LmsWebSessionException(${code.name})';
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
  int _generation = 0;
  bool _loginVisible = false;
  bool _keptAlive = false;
  bool _disposed = false;
  bool _nativeCookieBound = false;
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
    return data != null;
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
          data['cookies'] is List &&
          (data['cookies'] as List).isNotEmpty) {
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
    try {
      await _activate();
      _checkGeneration(startedGeneration);
      await _startHeadless();
      _checkGeneration(startedGeneration);
      await _bindCookieStore();
      _checkGeneration(startedGeneration);
      await _restoreCookies(data['cookies'] as List);
      _checkGeneration(startedGeneration);
      await _reloadRoot();
      _checkGeneration(startedGeneration);
      if (await verifyAuthentication() == null) {
        await _storage.delete(key: _storageKey);
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
    } on LmsWebSessionException {
      rethrow;
    } catch (_) {
      throw const LmsWebSessionException(LmsWebSessionError.network);
    }
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
      onLoadStop: (_, _) {
        final pending = _pageLoaded;
        if (pending != null && !pending.isCompleted) pending.complete();
      },
      onReceivedError: (_, request, _) {
        if (request.isForMainFrame == true &&
            _pageLoaded?.isCompleted == false) {
          _pageLoaded!.completeError(
            const LmsWebSessionException(LmsWebSessionError.network),
          );
        }
      },
      shouldOverrideUrlLoading: (_, action) async {
        final uri = action.request.url?.uriValue;
        return uri != null &&
                policy.isSchoolOrigin(uri) &&
                const {'/', '/login.php', '/login/index.php'}.contains(uri.path)
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (_, _) async => false,
    );
    try {
      // Attach the error handler before the first native page callback.
      final completion = loaded.future.timeout(const Duration(seconds: 25));
      await _headless!.run();
      await completion;
    } catch (_) {
      await _headless?.dispose();
      _headless = null;
      _controller = null;
      throw const LmsWebSessionException(LmsWebSessionError.network);
    }
  }

  Future<void> _reloadRoot() async {
    final loaded = Completer<void>();
    _pageLoaded = loaded;
    final waiting = loaded.future.timeout(const Duration(seconds: 25));
    await _controller!.loadUrl(
      urlRequest: URLRequest(url: WebUri(baseUrl.toString())),
    );
    try {
      await waiting;
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
    if (controller == null || uri == null || !policy.isSchoolOrigin(uri)) {
      throw const LmsWebSessionException(
        LmsWebSessionError.authenticationRequired,
      );
    }
    final marker = 'daily-lms-${const Uuid().v4()}';
    final result = await controller.callAsyncJavaScript(
      functionBody:
          'const previous = window.name; window.name = marker; return previous;',
      arguments: {'marker': marker},
    );
    final originalName = result?.value;
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
        throw const LmsWebSessionException(LmsWebSessionError.unsupported);
      }
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

  Future<String?> verifyAuthentication() {
    _checkNotRetired();
    return _verification ??= _verifyAuthentication().whenComplete(
      () => _verification = null,
    );
  }

  Future<String?> _verifyAuthentication() async {
    final startedGeneration = _generation;
    final controller = _controller;
    if (controller == null || !identical(_active, this)) return null;
    _checkGeneration(startedGeneration);
    final at = (await controller.getUrl())?.uriValue;
    _checkGeneration(startedGeneration);
    if (at == null || !policy.isSchoolOrigin(at)) return null;
    await _bindCookieStore();
    _checkGeneration(startedGeneration);
    final value = await controller.callAsyncJavaScript(
      functionBody: '''
      if (location.origin !== origin) return null;
      if (document.querySelector('input[type="password"]')) return null;
      const ids = new Set();
      for (const a of document.querySelectorAll('a[href]')) {
        const u = new URL(a.getAttribute('href'), location.href);
        const id = u.searchParams.get('id');
        if (u.origin === origin && u.pathname === '/user/edit.php' && /^[1-9][0-9]*\$/.test(id || '')) ids.add(id);
      }
      return ids.size === 1 ? Array.from(ids)[0] : {unrecognized: true};
    ''',
      arguments: {'origin': baseUrl.origin},
    );
    _checkGeneration(startedGeneration);
    if (value?.error != null) {
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    final id = value?.value;
    if (id is Map && id['unrecognized'] == true) {
      throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
    }
    if (id is! String ||
        (_expectedPrincipal != null && _expectedPrincipal != id)) {
      _invalidate();
      return null;
    }
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
    _notify();
    return id;
  }

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
      final result = await _controller!
          .callAsyncJavaScript(
            functionBody: '''
        if (location.origin !== origin) return {status: 'auth'};
        const abort = new AbortController();
        const timer = setTimeout(() => abort.abort(), 20000);
        try {
          const response = await fetch(url, {method: 'GET', credentials: 'same-origin',
            mode: 'same-origin', redirect: 'manual', cache: 'no-store', signal: abort.signal});
          if (response.type === 'opaqueredirect' || response.status === 401 || response.status === 403) return {status: 'auth'};
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
          .timeout(const Duration(seconds: 25));
      if (startedGeneration != _generation || !isAuthenticated) {
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
      }
      final data = result?.value;
      if (data is! Map) {
        throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
      }
      if (data['status'] == 'auth') {
        _invalidate();
        await _storage.delete(key: _storageKey);
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
      final pagePrincipal = policy.principalFromHtml(source);
      if (pagePrincipal == null &&
          html.parse(source).querySelector('input[type="password"]') == null) {
        // A changed/error page is not proof that the school session expired.
        throw const LmsWebSessionException(LmsWebSessionError.invalidResponse);
      }
      if (pagePrincipal != _principalId) {
        _invalidate();
        await _storage.delete(key: _storageKey);
        throw const LmsWebSessionException(
          LmsWebSessionError.authenticationRequired,
        );
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
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'owner': ownerId,
        'school': schoolId,
        'principal': principal,
        'cookies': authentication,
      }),
    );
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
    _principalId = null;
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
      await _storage.delete(key: _storageKey);
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _invalidate();
    return _closing = _close().whenComplete(() => _closing = null);
  }

  Future<void> _close() async {
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
