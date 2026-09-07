import 'dart:async';
import 'dart:convert';

import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _missingCredential = GoogleSignInException(
  code: GoogleSignInExceptionCode.unknownError,
  description:
      'Authorization failed: 16: [28433] Cannot find a matching credential.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GooglePlatform platform;
  late GoogleDriveAuthService service;
  late List<http.Request> identityRequests;
  String? linkedEmail;

  Future<void> initialize({
    bool recovery = true,
    bool signIn = true,
    Future<http.Response> Function(http.Request)? identityResponse,
  }) async {
    service = GoogleDriveAuthService(
      useDesktopOAuth: false,
      useAndroidAuthorizationRecovery: recovery,
      linkedGoogleEmail: () => linkedEmail,
      httpClient: MockClient((request) async {
        identityRequests.add(request);
        return identityResponse != null
            ? identityResponse(request)
            : http.Response(
                jsonEncode({
                  'sub': 'signed-in-user',
                  'email': 'signed-in@example.com',
                  'email_verified': true,
                }),
                200,
              );
      }),
    );
    if (signIn) {
      await service.signIn();
    } else {
      await service.initialize();
    }
  }

  setUp(() {
    platform = _GooglePlatform();
    identityRequests = [];
    linkedEmail = null;
    final previous = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = platform;
    addTearDown(() => GoogleSignInPlatform.instance = previous);
  });

  test(
    'Android startup and repeated restore never invoke Credential Manager',
    () async {
      await initialize(signIn: false);
      for (var attempt = 0; attempt < 3; attempt++) {
        expect(await service.restorePreviousSignIn(), isNull);
        expect(await service.authorizationHeaders(), isNull);
      }
      expect(platform.lightweightCalls, 0);
      expect(platform.signInCalls, 0);
      expect(platform.requests, isEmpty);
    },
  );

  test('a scope request cannot implicitly start Android login', () async {
    await initialize(signIn: false);
    expect(await service.authorizationHeaders(promptIfNecessary: true), isNull);
    expect(platform.lightweightCalls, 0);
    expect(platform.signInCalls, 0);
    expect(platform.requests, isEmpty);
  });

  test(
    'linked account restores and refreshes only with a verified silent token',
    () async {
      linkedEmail = 'signed-in@example.com';
      await initialize(signIn: false);
      expect(service.currentAccount, isNull);
      expect((await service.restorePreviousSignIn())?.email, linkedEmail);
      expect(service.currentAccount?.email, linkedEmail);
      expect(await service.authorizationHeaders(), {
        'Authorization': 'Bearer recovered-token',
      });
      expect(platform.requests, hasLength(2));
      expect(
        platform.requests.every((request) => !request.promptIfUnauthorized),
        isTrue,
      );
      expect(
        platform.requests.every((request) => request.scopes.contains('email')),
        isTrue,
      );
      expect(platform.lightweightCalls, 0);
      expect(platform.signInCalls, 0);
    },
  );

  test(
    'saved email is not enough to sign in when consent is missing',
    () async {
      linkedEmail = 'signed-in@example.com';
      platform.authorize = (_) async => null;
      await initialize(signIn: false);
      expect(await service.restorePreviousSignIn(), isNull);
      expect(
        await service.authorizationHeaders(promptIfNecessary: true),
        isNull,
      );
      expect(service.currentAccount, isNull);
      expect(
        platform.requests.every((request) => !request.promptIfUnauthorized),
        isTrue,
      );
      expect(platform.lightweightCalls, 0);
      expect(platform.signInCalls, 0);
    },
  );

  for (final (label, identity, status) in [
    (
      'another account',
      {'sub': 'other', 'email': 'other@example.com', 'email_verified': true},
      200,
    ),
    (
      'unverified email',
      {
        'sub': 'signed-in-user',
        'email': 'signed-in@example.com',
        'email_verified': false,
      },
      200,
    ),
    (
      'no subject',
      {'email': 'signed-in@example.com', 'email_verified': true},
      200,
    ),
    ('expired token', <String, Object>{}, 401),
  ]) {
    test('silent restore rejects $label without requesting login', () async {
      linkedEmail = 'signed-in@example.com';
      await initialize(
        signIn: false,
        identityResponse: (_) async =>
            http.Response(jsonEncode(identity), status),
      );
      expect(await service.restorePreviousSignIn(), isNull);
      expect(await service.authorizationHeaders(), isNull);
      expect(service.currentAccount, isNull);
      expect(
        platform.requests.every((request) => !request.promptIfUnauthorized),
        isTrue,
      );
      expect(platform.lightweightCalls, 0);
      expect(platform.signInCalls, 0);
    });
  }

  test(
    'silent restore pins the Google subject after identity verification',
    () async {
      linkedEmail = 'signed-in@example.com';
      var subject = 'signed-in-user';
      await initialize(
        signIn: false,
        identityResponse: (_) async => http.Response(
          jsonEncode({
            'sub': subject,
            'email': linkedEmail,
            'email_verified': true,
          }),
          200,
        ),
      );
      expect(await service.restorePreviousSignIn(), isNotNull);
      subject = 'other-user';
      expect(await service.authorizationHeaders(), isNull);
      expect(platform.signInCalls, 0);
    },
  );

  for (final signOut in [true, false]) {
    test(
      'pending silent restore is discarded after ${signOut ? 'sign-out' : 'linked account change'}',
      () async {
        linkedEmail = 'signed-in@example.com';
        final response = Completer<http.Response>();
        final started = Completer<void>();
        await initialize(
          signIn: false,
          identityResponse: (_) {
            started.complete();
            return response.future;
          },
        );
        final restore = service.restorePreviousSignIn();
        await started.future;
        if (signOut) {
          await service.signOut();
        } else {
          linkedEmail = 'other@example.com';
        }
        response.complete(
          http.Response(
            jsonEncode({
              'sub': 'signed-in-user',
              'email': 'signed-in@example.com',
              'email_verified': true,
            }),
            200,
          ),
        );
        expect(await restore, isNull);
        expect(service.currentAccount, isNull);
        expect(platform.signInCalls, 0);
      },
    );
  }

  test(
    'canceling explicit login does not reopen it on restore or sync',
    () async {
      linkedEmail = 'signed-in@example.com';
      platform.signInError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      await initialize(signIn: false);
      await expectLater(
        service.signIn(forceAccountSelection: true),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      expect(await service.restorePreviousSignIn(), isNull);
      expect(await service.authorizationHeaders(), isNull);
      expect(platform.signInCalls, 1);
      expect(platform.lightweightCalls, 0);
      expect(platform.requests, isEmpty);
    },
  );

  test('explicit login remains available after sign-out', () async {
    linkedEmail = 'signed-in@example.com';
    await initialize();
    await service.signOut();
    expect(await service.restorePreviousSignIn(), isNull);
    expect(await service.authorizationHeaders(promptIfNecessary: true), isNull);
    expect(platform.signInCalls, 1);
    await service.signIn(forceAccountSelection: true);
    expect(
      await service.authorizationHeaders(promptIfNecessary: true),
      isNotNull,
    );
    expect(platform.signInCalls, 2);
    expect(platform.lightweightCalls, 0);
  });

  test(
    'explicit Calendar permission still works for a silently restored session',
    () async {
      linkedEmail = 'signed-in@example.com';
      await initialize(signIn: false);
      expect(
        await service.authorizationHeadersForScopes([
          GoogleDriveAuthService.calendarReadonlyScope,
        ], promptIfNecessary: true),
        isNotNull,
      );
      expect(platform.requests.first.promptIfUnauthorized, isFalse);
      expect(platform.requests.last.promptIfUnauthorized, isTrue);
      expect(
        platform.requests.last.scopes,
        contains(GoogleDriveAuthService.calendarReadonlyScope),
      );
      expect(platform.signInCalls, 0);
      expect(platform.lightweightCalls, 0);
    },
  );

  test('non-Android native restoration keeps its existing behavior', () async {
    await initialize(signIn: false, recovery: false);
    expect(await service.restorePreviousSignIn(), isNull);
    expect(platform.lightweightCalls, 1);
    expect(platform.signInCalls, 0);
  });

  test('existing account authorization does not use recovery', () async {
    platform.authorize = (_) async =>
        const ClientAuthorizationTokenData(accessToken: 'account-token');
    await initialize();

    final headers = await service.authorizationHeaders(promptIfNecessary: true);

    expect(headers?['Authorization'], 'Bearer account-token');
    expect(platform.requests.single.email, 'signed-in@example.com');
    expect(identityRequests, isEmpty);
  });

  test('missing Android credential recovers only a verified account', () async {
    await initialize();

    final headers = await service.authorizationHeaders(promptIfNecessary: true);

    expect(headers, {'Authorization': 'Bearer recovered-token'});
    expect(platform.requests, hasLength(2));
    expect(platform.requests.first.email, 'signed-in@example.com');
    expect(platform.requests.last.email, isNull);
    expect(platform.requests.last.promptIfUnauthorized, isTrue);
    expect(
      platform.requests.last.scopes,
      containsAll([GoogleDriveAuthService.driveAppDataScope, 'openid']),
    );
    expect(
      identityRequests.single.url.toString(),
      'https://www.googleapis.com/oauth2/v3/userinfo',
    );
    expect(
      identityRequests.single.headers['Authorization'],
      'Bearer recovered-token',
    );

    platform.requests.clear();
    await service.authorizationHeaders();
    expect(platform.requests, hasLength(1));
    expect(platform.requests.single.email, isNull);
    expect(platform.requests.single.promptIfUnauthorized, isFalse);
    expect(platform.signInCalls, 1);
  });

  test('silent recovery cannot open a consent or login screen', () async {
    platform.authorize = (request) async {
      if (request.email != null) throw _missingCredential;
      return null;
    };
    await initialize();

    expect(await service.authorizationHeaders(), isNull);
    expect(platform.requests, hasLength(2));
    expect(
      platform.requests.every((request) => !request.promptIfUnauthorized),
      isTrue,
    );
    expect(platform.signInCalls, 1);
    expect(identityRequests, isEmpty);
  });

  test('silent missing credentials on both paths return no token', () async {
    platform.authorize = (_) async => throw _missingCredential;
    await initialize();

    expect(await service.authorizationHeaders(), isNull);
    expect(platform.requests, hasLength(2));
    expect(platform.signInCalls, 1);
  });

  test('another Google account cannot supply a Drive token', () async {
    await initialize(
      identityResponse: (_) async =>
          http.Response(jsonEncode({'sub': 'different-user'}), 200),
    );

    await expectLater(
      service.authorizationHeaders(promptIfNecessary: true),
      throwsA(
        isA<GoogleDriveAuthException>().having(
          (error) => error.message,
          'message',
          contains('계정이 다릅니다'),
        ),
      ),
    );
    expect(service.currentAccount?.email, 'signed-in@example.com');
    platform.requests.clear();
    await expectLater(
      service.authorizationHeaders(),
      throwsA(isA<GoogleDriveAuthException>()),
    );
    expect(platform.requests.first.email, 'signed-in@example.com');
  });

  for (final (label, body, status) in [
    ('missing subject', '{}', 200),
    ('invalid response', '<html>error</html>', 200),
    ('rejected token', '{}', 401),
  ]) {
    test('$label never authorizes Drive requests', () async {
      await initialize(
        identityResponse: (_) async => http.Response(body, status),
      );
      await expectLater(
        service.authorizationHeaders(promptIfNecessary: true),
        throwsA(isA<GoogleDriveAuthException>()),
      );
    });
  }

  test(
    'sign-out during identity validation discards recovered token',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      await initialize(
        identityResponse: (_) {
          started.complete();
          return response.future;
        },
      );

      final headers = service.authorizationHeaders();
      await started.future;
      await service.signOut();
      response.complete(
        http.Response(jsonEncode({'sub': 'signed-in-user'}), 200),
      );
      expect(await headers, isNull);
      expect(service.currentAccount, isNull);
    },
  );

  for (final code in [
    GoogleSignInExceptionCode.canceled,
    GoogleSignInExceptionCode.clientConfigurationError,
    GoogleSignInExceptionCode.unknownError,
  ]) {
    test('$code is reported without retrying unrelated failures', () async {
      platform.authorize = (_) async => throw GoogleSignInException(
        code: code,
        description: 'Unrelated authorization error',
      );
      await initialize();

      await expectLater(
        service.authorizationHeaders(promptIfNecessary: true),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      expect(platform.requests, hasLength(1));
      expect(identityRequests, isEmpty);
    });
  }

  test(
    'failed interactive recovery shows a readable error and stops',
    () async {
      platform.authorize = (_) async => throw _missingCredential;
      await initialize();

      await expectLater(
        service.authorizationHeaders(promptIfNecessary: true),
        throwsA(
          isA<GoogleDriveAuthException>().having(
            (error) => error.message,
            'message',
            isNot(contains('GoogleSignInException')),
          ),
        ),
      );
      expect(platform.requests, hasLength(2));
      expect(platform.signInCalls, 1);
    },
  );

  test('other platforms never use Android account recovery', () async {
    await initialize(recovery: false);

    await expectLater(
      service.authorizationHeaders(promptIfNecessary: true),
      throwsA(isA<GoogleDriveAuthException>()),
    );
    expect(platform.requests, hasLength(1));
    expect(identityRequests, isEmpty);
  });

  test('Calendar import recovery retains the requested scope', () async {
    await initialize();

    await service.authorizationHeadersForScopes([
      GoogleDriveAuthService.calendarReadonlyScope,
    ], promptIfNecessary: true);
    expect(
      platform.requests.last.scopes,
      containsAll([GoogleDriveAuthService.calendarReadonlyScope, 'openid']),
    );
    expect(
      platform.requests.last.scopes,
      isNot(contains(GoogleDriveAuthService.driveAppDataScope)),
    );
  });
}

class _GooglePlatform extends GoogleSignInPlatform {
  final requests = <AuthorizationRequestDetails>[];
  var signInCalls = 0;
  var lightweightCalls = 0;
  GoogleSignInException? signInError;
  Future<ClientAuthorizationTokenData?> Function(AuthorizationRequestDetails)
  authorize = (request) async {
    if (request.email != null) throw _missingCredential;
    return const ClientAuthorizationTokenData(accessToken: 'recovered-token');
  };

  @override
  Future<void> init(InitParameters params) async {}

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    return const AuthenticationResults(
      user: GoogleSignInUserData(
        email: 'signed-in@example.com',
        id: 'signed-in-user',
      ),
      authenticationTokens: AuthenticationTokenData(idToken: 'test-id-token'),
    );
  }

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    lightweightCalls++;
    return null;
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    requests.add(params.request);
    return authorize(params.request);
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => throw UnimplementedError();

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}
