import 'dart:async';
import 'dart:convert';

import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const sessionKey = 'daily.google_drive.session.v1';
const prefix = 'daily.google_drive.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  setUp(() {
    storage = _Storage();
    FlutterSecureStorage.setMockInitialValues({});
  });

  GoogleDriveAuthService service({
    required Future<http.Response> Function(http.Request) request,
    Future<({String code, String redirectUri, String codeVerifier})> Function()?
    code,
  }) => GoogleDriveAuthService(
    secureStorage: storage,
    httpClient: MockClient(request),
    useDesktopOAuth: true,
    desktopAuthorizationCode:
        code ??
        () async =>
            (code: 'B', redirectUri: 'http://localhost/', codeVerifier: 'test'),
  );

  void expiredA() {
    storage.values.addAll({
      '${prefix}refresh_token': 'refresh-A',
      '${prefix}access_token': 'old-A',
      '${prefix}expires_at': DateTime.utc(2000).toIso8601String(),
      '${prefix}email': 'a@example.test',
    });
  }

  for (final switchAccount in [false, true]) {
    test(
      'late refresh cannot resurrect A after ${switchAccount ? 'switch to B' : 'logout'}',
      () async {
        expiredA();
        final entered = Completer<void>();
        final response = Completer<http.Response>();
        final auth = service(
          request: (request) async {
            if (request.body.contains('refresh_token')) {
              entered.complete();
              return response.future;
            }
            if (request.url.path == '/token') return _token('B');
            return http.Response('{"email":"b@example.test"}', 200);
          },
        );
        await auth.restorePreviousSignIn();
        final pending = auth.authorizationHeaders();
        await entered.future;
        if (switchAccount) {
          await auth.signIn(forceAccountSelection: true);
        } else {
          await auth.signOut();
        }
        response.complete(_token('A'));
        expect(await pending, isNull);
        expect(
          auth.currentAccount?.email,
          switchAccount ? 'b@example.test' : null,
        );
        final restored = service(
          request: (_) async => throw StateError('no network'),
        );
        expect(
          (await restored.restorePreviousSignIn())?.email,
          switchAccount ? 'b@example.test' : null,
        );
        expect(storage.values[sessionKey], isNot(contains('refresh-A')));
      },
    );
  }

  test(
    'logout while account-selection storage clear is pending cancels login',
    () async {
      expiredA();
      final entered = Completer<void>();
      final resume = Completer<void>();
      var writes = 0;
      storage.beforeWrite = (key, value) async {
        if (key == sessionKey && ++writes == 1) {
          entered.complete();
          await resume.future;
        }
      };
      var requests = 0;
      final auth = service(
        request: (_) async {
          requests++;
          return _token('B');
        },
      );
      final pending = auth.signIn(forceAccountSelection: true);
      final rejected = expectLater(
        pending,
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await entered.future;
      final logout = auth.signOut();
      resume.complete();
      await rejected;
      await logout;
      expect(requests, 0);
      expect(auth.currentAccount, isNull);
      expect(jsonDecode(storage.values[sessionKey]!)['signedOut'], isTrue);
    },
  );

  test(
    'scope consent completion after logout never restores credentials',
    () async {
      final entered = Completer<void>();
      final resume =
          Completer<({String code, String redirectUri, String codeVerifier})>();
      var requests = 0;
      final auth = service(
        code: () {
          entered.complete();
          return resume.future;
        },
        request: (_) async {
          requests++;
          return _token('B');
        },
      );
      final pending = auth.authorizationHeadersForScopes([
        GoogleDriveAuthService.calendarReadonlyScope,
      ], promptIfNecessary: true);
      final rejected = expectLater(
        pending,
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await entered.future;
      await auth.signOut();
      resume.complete((
        code: 'B',
        redirectUri: 'http://localhost/',
        codeVerifier: 'test',
      ));
      await rejected;
      expect(requests, 0);
      expect(auth.currentAccount, isNull);
    },
  );

  test('parallel expired-token requests share one refresh', () async {
    expiredA();
    var requests = 0;
    final response = Completer<http.Response>();
    final entered = Completer<void>();
    final auth = service(
      request: (_) {
        requests++;
        if (!entered.isCompleted) entered.complete();
        return response.future;
      },
    );
    await auth.restorePreviousSignIn();
    final first = auth.authorizationHeaders();
    final second = auth.authorizationHeaders();
    await entered.future;
    response.complete(_token('A'));
    expect(await first, {'Authorization': 'Bearer access-A'});
    expect(await second, {'Authorization': 'Bearer access-A'});
    expect(requests, 1);
  });

  test(
    'late account lookup cannot overwrite a completed newer login',
    () async {
      final entered = Completer<void>();
      final accountA = Completer<http.Response>();
      var login = 0;
      final auth = service(
        code: () async => (
          code: '${++login}',
          redirectUri: 'http://localhost/',
          codeVerifier: 'test',
        ),
        request: (request) async {
          if (request.url.path == '/token') {
            return _token(request.body.contains('code=1') ? 'A' : 'B');
          }
          if (request.headers['Authorization'] == 'Bearer access-A') {
            entered.complete();
            return accountA.future;
          }
          return http.Response('{"email":"b@example.test"}', 200);
        },
      );
      final old = auth.signIn();
      final rejected = expectLater(
        old,
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await entered.future;
      await auth.signIn();
      accountA.complete(http.Response('{"email":"a@example.test"}', 200));
      await rejected;
      expect(auth.currentAccount?.email, 'b@example.test');
      expect(
        jsonDecode(storage.values[sessionKey]!)['email'],
        'b@example.test',
      );
    },
  );

  test(
    'cancel during code exchange rejects late completion without persisting',
    () async {
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      final auth = service(
        request: (_) {
          entered.complete();
          return response.future;
        },
      );
      final login = auth.signIn();
      final rejected = expectLater(
        login,
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await entered.future;
      auth.cancelPendingSignIn();
      response.complete(_token('B'));
      await rejected;
      expect(auth.currentAccount, isNull);
      expect(storage.values[sessionKey], isNull);
    },
  );

  test(
    'logout while restoration reads storage cannot publish stale account',
    () async {
      expiredA();
      final entered = Completer<void>();
      final resume = Completer<void>();
      storage.beforeRead = (key) async {
        if (key == '${prefix}refresh_token') {
          entered.complete();
          await resume.future;
        }
      };
      final auth = service(
        request: (_) async => throw StateError('no network'),
      );
      final restore = auth.restorePreviousSignIn();
      await entered.future;
      final logout = auth.signOut();
      resume.complete();
      expect(await restore, isNull);
      await logout;
      expect(auth.currentAccount, isNull);
    },
  );

  test(
    'cancel during secure commit rolls back complete session envelope',
    () async {
      final entered = Completer<void>();
      final resume = Completer<void>();
      var blocked = false;
      storage.beforeWrite = (key, value) async {
        if (key == sessionKey && !blocked) {
          blocked = true;
          entered.complete();
          await resume.future;
        }
      };
      final auth = service(
        request: (r) async => r.url.path == '/token'
            ? _token('B')
            : http.Response('{"email":"b@example.test"}', 200),
      );
      final login = auth.signIn();
      final rejected = expectLater(
        login,
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await entered.future;
      auth.cancelPendingSignIn();
      resume.complete();
      await rejected;
      expect(storage.values[sessionKey], isNull);
      expect(auth.currentAccount, isNull);
    },
  );

  test(
    'verification read failure rolls back a completed secure write',
    () async {
      var reads = 0;
      storage.beforeRead = (key) async {
        if (key == sessionKey && ++reads == 2) {
          throw StateError('verification unavailable');
        }
      };
      final auth = service(
        request: (r) async => r.url.path == '/token'
            ? _token('B')
            : http.Response('{"email":"b@example.test"}', 200),
      );
      await expectLater(auth.signIn(), throwsStateError);
      expect(storage.values[sessionKey], isNull);
      expect(auth.currentAccount, isNull);
    },
  );

  test(
    'failed secure write preserves previous account and can retry',
    () async {
      expiredA();
      final auth = service(
        request: (r) async => r.url.path == '/token'
            ? _token('B')
            : http.Response('{"email":"b@example.test"}', 200),
      );
      await auth.restorePreviousSignIn();
      storage.beforeWrite = (_, _) async =>
          throw StateError('disk unavailable');
      await expectLater(auth.signIn(), throwsStateError);
      expect(auth.currentAccount?.email, 'a@example.test');
      expect(storage.values[sessionKey], isNull);
      storage.beforeWrite = null;
      await auth.signIn();
      expect(auth.currentAccount?.email, 'b@example.test');
    },
  );
}

http.Response _token(String account) => http.Response(
  jsonEncode({
    'access_token': 'access-$account',
    'refresh_token': 'refresh-$account',
    'expires_in': 3600,
  }),
  200,
);

class _Storage extends FlutterSecureStorage {
  final values = <String, String>{};
  Future<void> Function(String)? beforeRead;
  Future<void> Function(String, String?)? beforeWrite;
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
    await beforeRead?.call(key);
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
    await beforeWrite?.call(key, value);
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

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
    values.remove(key);
  }
}
