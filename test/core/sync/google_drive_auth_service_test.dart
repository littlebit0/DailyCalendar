import 'dart:async';
import 'dart:convert';

import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _missingCredential = GoogleSignInException(
  code: GoogleSignInExceptionCode.unknownError,
  description:
      'Authorization failed: 16: [28433] Cannot find a matching credential.',
);

const _cancelled = GoogleSignInException(
  code: GoogleSignInExceptionCode.canceled,
  description: 'User cancelled the account chooser',
);

const _signedIn = AuthenticationResults(
  user: GoogleSignInUserData(
    email: 'signed-in@example.com',
    id: 'signed-in-user',
  ),
  authenticationTokens: AuthenticationTokenData(idToken: 'test-id-token'),
);

const _otherUser = AuthenticationResults(
  user: GoogleSignInUserData(email: 'other@example.com', id: 'other-user'),
  authenticationTokens: AuthenticationTokenData(idToken: 'other-id-token'),
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
    Duration? approvalTimeout,
    Future<http.Response> Function(http.Request)? identityResponse,
  }) async {
    service = GoogleDriveAuthService(
      useDesktopOAuth: false,
      useAndroidAuthorizationRecovery: recovery,
      linkedGoogleEmail: () => linkedEmail,
      mobileUserApprovalTimeout: approvalTimeout,
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
      expect(await service.signIn(forceAccountSelection: true), isNull);
      expect(await service.restorePreviousSignIn(), isNull);
      expect(await service.authorizationHeaders(), isNull);
      expect(platform.signInCalls, 1);
      expect(platform.lightweightCalls, 0);
      expect(platform.requests, isEmpty);
    },
  );

  test(
    'two cancellations then successful connection publish only success',
    () async {
      await initialize(signIn: false);
      final accounts = <GoogleDriveAccount?>[];
      final subscription = service.accountChanges.listen(accounts.add);
      addTearDown(subscription.cancel);
      platform.signInError = _cancelled;
      for (var attempt = 0; attempt < 2; attempt++) {
        expect(await service.connectToDrive(), isNull);
        // These are the lifecycle and automatic sync entry points on resume.
        expect(await service.restorePreviousSignIn(), isNull);
        expect(await service.authorizationHeaders(), isNull);
      }
      expect(accounts, isEmpty);
      platform.signInError = null;
      expect((await service.connectToDrive())?.email, 'signed-in@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(accounts.map((account) => account?.email), [
        'signed-in@example.com',
      ]);
      expect(platform.signInCalls, 3);
      expect(platform.lightweightCalls, 0);
    },
  );

  for (final restored in [false, true]) {
    test(
      'cancelled reconnect preserves ${restored ? 'silently restored' : 'explicit'} identity and token validation',
      () async {
        linkedEmail = 'signed-in@example.com';
        await initialize(signIn: !restored);
        if (restored) expect(await service.restorePreviousSignIn(), isNotNull);
        final previous = service.currentAccount;
        final accounts = <GoogleDriveAccount?>[];
        final subscription = service.accountChanges.listen(accounts.add);
        addTearDown(subscription.cancel);
        platform.signInError = _cancelled;
        expect(await service.connectToDrive(), isNull);
        await Future<void>.delayed(Duration.zero);
        expect(service.currentAccount?.email, previous?.email);
        expect(accounts, isEmpty);
        expect(await service.authorizationHeaders(), isNotNull);
        expect(platform.requests.last.promptIfUnauthorized, isFalse);
        // Preserving the account is not sufficient proof of usable credentials.
        platform.authorize = (_) async => null;
        expect(await service.authorizationHeaders(), isNull);
        expect(platform.lightweightCalls, 0);
      },
    );
  }

  test(
    'Drive consent cancellation never commits the candidate account',
    () async {
      await initialize();
      final accounts = <GoogleDriveAccount?>[];
      final subscription = service.accountChanges.listen(accounts.add);
      addTearDown(subscription.cancel);
      platform.authenticateResult = () async => _otherUser;
      platform.authorize = (_) async => throw _cancelled;
      expect(await service.connectToDrive(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(service.currentAccount?.email, 'signed-in@example.com');
      expect(accounts, isEmpty);
      platform.authorize = (request) async =>
          ClientAuthorizationTokenData(accessToken: '${request.email}-token');
      expect(
        await service.authorizationHeaders(),
        containsPair('Authorization', 'Bearer signed-in@example.com-token'),
      );
      expect((await service.connectToDrive())?.email, 'other@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(accounts.map((account) => account?.email), ['other@example.com']);
    },
  );

  test(
    'new identity is published only after Drive authorization completes',
    () async {
      await initialize();
      platform.authenticateResult = () async => _otherUser;
      final consent = Completer<ClientAuthorizationTokenData?>();
      final consentStarted = Completer<void>();
      platform.authorize = (_) {
        if (!consentStarted.isCompleted) consentStarted.complete();
        return consent.future;
      };
      final connection = service.connectToDrive();
      await consentStarted.future;
      expect(service.currentAccount?.email, 'signed-in@example.com');
      expect(await service.authorizationHeaders(), isNull);
      consent.complete(
        const ClientAuthorizationTokenData(accessToken: 'new-token'),
      );
      expect((await connection)?.email, 'other@example.com');
      expect(service.currentAccount?.email, 'other@example.com');
    },
  );

  for (final error in <Object>[
    const GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
    ),
    const GoogleSignInException(code: GoogleSignInExceptionCode.interrupted),
    const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError),
    PlatformException(code: 'network_error'),
    http.ClientException('offline'),
  ]) {
    test(
      '${error.runtimeType} ${error is GoogleSignInException ? error.code : ''} remains a real failure and permits retry',
      () async {
        await initialize();
        platform.authenticateResult = () async => throw error;
        await expectLater(
          service.connectToDrive(),
          throwsA(
            error is http.ClientException
                ? isA<http.ClientException>()
                : isA<GoogleDriveAuthException>(),
          ),
        );
        expect(service.currentAccount?.email, 'signed-in@example.com');
        platform.authenticateResult = () async => _signedIn;
        expect(await service.connectToDrive(), isNotNull);
      },
    );
  }

  test(
    'missing Drive token without cancellation is reported as failure',
    () async {
      await initialize();
      platform.authenticateResult = () async => _otherUser;
      platform.authorize = (_) async => null;
      await expectLater(
        service.connectToDrive(),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      expect(service.currentAccount?.email, 'signed-in@example.com');
    },
  );

  test(
    'three overlapping sign-in requests use one native Activity at a time',
    () async {
      await initialize(signIn: false);
      final attempts = List.generate(
        3,
        (_) => Completer<AuthenticationResults>(),
      );
      platform.authenticateResult = () =>
          attempts[platform.signInCalls - 1].future;
      final connections = List.generate(3, (_) => service.connectToDrive());
      await Future<void>.delayed(Duration.zero);
      expect(platform.signInCalls, 1);
      attempts[0].completeError(_cancelled);
      expect(await connections[0], isNull);
      await Future<void>.delayed(Duration.zero);
      expect(platform.signInCalls, 2);
      attempts[1].completeError(_cancelled);
      expect(await connections[1], isNull);
      await Future<void>.delayed(Duration.zero);
      expect(platform.signInCalls, 3);
      attempts[2].complete(_signedIn);
      expect(await connections[2], isNotNull);
      expect(platform.maximumActiveSignIns, 1);
    },
  );

  for (final cancel in [false, true]) {
    test(
      'logout invalidates queued attempts and late ${cancel ? 'cancel' : 'success'}',
      () async {
        await initialize();
        final late = Completer<AuthenticationResults>();
        platform.authenticateResult = () => late.future;
        final first = service.connectToDrive();
        final queued = service.connectToDrive();
        await Future<void>.delayed(Duration.zero);
        await service.signOut();
        if (cancel) {
          late.completeError(_cancelled);
        } else {
          late.complete(_signedIn);
        }
        expect(await first, isNull);
        expect(await queued, isNull);
        await Future<void>.delayed(Duration.zero);
        expect(service.currentAccount, isNull);
        expect(platform.signInCalls, 2);
        expect(await service.restorePreviousSignIn(), isNull);
        platform.authenticateResult = () async => _signedIn;
        expect(await service.connectToDrive(), isNotNull);
      },
    );
  }

  test('logout during Drive consent rejects late account and token', () async {
    await initialize();
    final consent = Completer<ClientAuthorizationTokenData?>();
    platform.authorize = (_) => consent.future;
    final connection = service.connectToDrive();
    await Future<void>.delayed(Duration.zero);
    await service.signOut();
    consent.complete(
      const ClientAuthorizationTokenData(accessToken: 'late-token'),
    );
    expect(await connection, isNull);
    expect(service.currentAccount, isNull);
    expect(await service.authorizationHeaders(), isNull);
  });

  for (final duringConsent in [false, true]) {
    test(
      'timed-out ${duringConsent ? 'consent' : 'authentication'} stays owned until native completion',
      () async {
        await initialize(approvalTimeout: const Duration(milliseconds: 10));
        final authentication = Completer<AuthenticationResults>();
        final consent = Completer<ClientAuthorizationTokenData?>();
        platform.authenticateResult = duringConsent
            ? () async => _otherUser
            : () => authentication.future;
        if (duringConsent) platform.authorize = (_) => consent.future;
        await expectLater(
          service.connectToDrive(),
          throwsA(isA<GoogleDriveAuthException>()),
        );
        await expectLater(
          service.connectToDrive(),
          throwsA(isA<GoogleDriveAuthException>()),
        );
        expect(platform.signInCalls, 2);
        if (duringConsent) {
          consent.complete(
            const ClientAuthorizationTokenData(accessToken: 'late-token'),
          );
        } else {
          authentication.complete(_otherUser);
        }
        await Future<void>.delayed(Duration.zero);
        expect(service.currentAccount?.email, 'signed-in@example.com');
        platform.authenticateResult = () async => _signedIn;
        platform.authorize = (_) async =>
            const ClientAuthorizationTokenData(accessToken: 'fresh-token');
        expect(await service.connectToDrive(), isNotNull);
      },
    );
  }

  test(
    'restart after cancellation restores only a verified saved identity without UI',
    () async {
      linkedEmail = 'signed-in@example.com';
      await initialize();
      platform.signInError = _cancelled;
      expect(await service.connectToDrive(), isNull);
      await initialize(signIn: false);
      expect(service.currentAccount, isNull);
      expect((await service.restorePreviousSignIn())?.email, linkedEmail);
      expect(platform.signInCalls, 2);
      expect(platform.lightweightCalls, 0);
    },
  );

  test(
    'auth result logging contains outcomes without account or token values',
    () async {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);
      await initialize(signIn: false);
      platform.signInError = _cancelled;
      expect(await service.connectToDrive(), isNull);
      platform.signInError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'signed-in@example.com test-id-token',
      );
      await expectLater(
        service.connectToDrive(),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      platform.signInError = null;
      expect(await service.connectToDrive(), isNotNull);
      expect(messages, [
        'GoogleAuthResult.CANCELLED',
        'GoogleAuthResult.FAILURE',
        'GoogleAuthResult.SUCCESS',
      ]);
    },
  );

  for (final logout in [false, true]) {
    test(
      'timed-out credential clear during ${logout ? 'logout' : 'selection'} blocks new native work',
      () async {
        await initialize();
        final clear = Completer<void>();
        platform.clearCredentialState = () => clear.future;
        if (logout) {
          await service.signOut();
        } else {
          await expectLater(
            service.connectToDrive(),
            throwsA(isA<GoogleDriveAuthException>()),
          );
        }
        expect(platform.signInCalls, 1);
        await expectLater(
          service.connectToDrive(),
          throwsA(isA<GoogleDriveAuthException>()),
        );
        expect(
          await service.authorizationHeaders(promptIfNecessary: true),
          isNull,
        );
        expect(platform.requests, isEmpty);
        expect(platform.signInCalls, 1);
        clear.complete();
        await Future<void>.delayed(Duration.zero);
        platform.clearCredentialState = null;
        expect(await service.connectToDrive(), isNotNull);
      },
    );
  }

  test('timed-out consent blocks another interactive scope request', () async {
    await initialize(approvalTimeout: const Duration(milliseconds: 10));
    final consent = Completer<ClientAuthorizationTokenData?>();
    platform.authenticateResult = () async => _otherUser;
    platform.authorize = (request) async {
      if (request.email == 'other@example.com') return consent.future;
      return const ClientAuthorizationTokenData(accessToken: 'existing-token');
    };
    await expectLater(
      service.connectToDrive(),
      throwsA(isA<GoogleDriveAuthException>()),
    );
    final requestsBefore = platform.requests.length;
    expect(
      await service.authorizationHeadersForScopes([
        GoogleDriveAuthService.calendarReadonlyScope,
      ], promptIfNecessary: true),
      isNull,
    );
    expect(platform.requests.length, requestsBefore);
    consent.complete(
      const ClientAuthorizationTokenData(accessToken: 'late-token'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(service.currentAccount?.email, 'signed-in@example.com');
  });

  test(
    'connection rejects a recovered token from another identity before commit',
    () async {
      await initialize();
      platform.authenticateResult = () async => _otherUser;
      // The fallback userinfo response still identifies the old signed-in user.
      await expectLater(
        service.connectToDrive(),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      expect(service.currentAccount?.email, 'signed-in@example.com');
      expect(identityRequests, hasLength(1));
    },
  );

  test(
    'unrelated credential clear errors remain visible and retryable',
    () async {
      await initialize();
      platform.clearCredentialState = () async =>
          throw PlatformException(code: 'unrelated_error');
      await expectLater(
        service.connectToDrive(),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      expect(service.currentAccount?.email, 'signed-in@example.com');
      expect(platform.signInCalls, 1);
      platform.clearCredentialState = null;
      expect(await service.connectToDrive(), isNotNull);
    },
  );

  for (final restored in [false, true]) {
    test(
      'pending Calendar consent for ${restored ? 'restored' : 'explicit'} account blocks a new connection',
      () async {
        linkedEmail = 'signed-in@example.com';
        await initialize(signIn: !restored);
        if (restored) expect(await service.restorePreviousSignIn(), isNotNull);
        final consent = Completer<ClientAuthorizationTokenData?>();
        final started = Completer<void>();
        platform.authorize = (request) async {
          if (request.scopes.contains(
            GoogleDriveAuthService.calendarReadonlyScope,
          )) {
            if (!started.isCompleted) started.complete();
            return consent.future;
          }
          return const ClientAuthorizationTokenData(
            accessToken: 'existing-token',
          );
        };
        final permission = service.authorizationHeadersForScopes([
          GoogleDriveAuthService.calendarReadonlyScope,
        ], promptIfNecessary: true);
        await started.future;
        final signInsBefore = platform.signInCalls;
        await expectLater(
          service.connectToDrive(),
          throwsA(isA<GoogleDriveAuthException>()),
        );
        expect(platform.signInCalls, signInsBefore);
        consent.complete(
          const ClientAuthorizationTokenData(accessToken: 'calendar-token'),
        );
        expect(
          await permission,
          containsPair('Authorization', 'Bearer calendar-token'),
        );
        platform.authorize = (_) async =>
            const ClientAuthorizationTokenData(accessToken: 'fresh-token');
        expect(await service.connectToDrive(), isNotNull);
      },
    );
  }

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
  var signOutCalls = 0;
  var activeSignIns = 0;
  var maximumActiveSignIns = 0;
  var lightweightCalls = 0;
  GoogleSignInException? signInError;
  Future<AuthenticationResults> Function()? authenticateResult;
  Future<void> Function()? clearCredentialState;
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
    activeSignIns++;
    if (activeSignIns > maximumActiveSignIns) {
      maximumActiveSignIns = activeSignIns;
    }
    try {
      if (signInError != null) throw signInError!;
      return authenticateResult == null
          ? _signedIn
          : await authenticateResult!();
    } finally {
      activeSignIns--;
    }
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
  Future<void> signOut(SignOutParams params) async {
    signOutCalls++;
    await clearCredentialState?.call();
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}
