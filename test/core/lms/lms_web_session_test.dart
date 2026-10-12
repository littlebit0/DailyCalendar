import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show
        InAppWebViewController,
        InAppWebViewPlatform,
        PlatformHeadlessInAppWebView,
        PlatformHeadlessInAppWebViewCreationParams,
        WebResourceRequest,
        WebResourceError,
        WebResourceErrorType,
        WebUri,
        URLRequest,
        CallAsyncJavaScriptResult,
        ContentWorld;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final base = Uri.parse('https://ecampus.smu.ac.kr/');
  final policy = LmsWebRequestPolicy(base);

  test(
    'fresh verified dashboard is consumed once; quiz reads stay fresh',
    () async {
      _seedStoredSession();
      _mockCookieBridge([]);
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform();
      const dashboard =
          '<body><a href="/user/edit.php?id=123">account</a><main id="region-main"></main></body>';
      platform.configure = (view) {
        view.controller.verification = {
          'principal': '123',
          'url': base.toString(),
          'dashboard': dashboard,
        };
        view.controller.fetchHtml = dashboard;
      };
      InAppWebViewPlatform.instance = platform;
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      try {
        await session.prepare();
        expect((await session.fetchHtml(base)).html, dashboard);
        expect(platform.views.single.controller.fetches, 0);
        await session.fetchHtml(base);
        expect(platform.views.single.controller.fetches, 1);
        await session.fetchHtml(base.resolve('/mod/quiz/view.php?id=9001'));
        await session.fetchHtml(base.resolve('/mod/quiz/view.php?id=9001'));
        expect(platform.views.single.controller.fetches, 3);
        await session.close();
        await session.prepare();
        expect(session.isAuthenticated, isTrue);
      } finally {
        await session.retire();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  test(
    'dashboard snapshot from another principal is never reused',
    () async {
      _seedStoredSession();
      _mockCookieBridge([]);
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform();
      platform.configure = (view) {
        view.controller.verification = {
          'principal': '123',
          'url': base.toString(),
          'dashboard': '<body><a href="/user/edit.php?id=456">other</a></body>',
        };
        view.controller.fetchHtml =
            '<body><a href="/user/edit.php?id=123">account</a></body>';
      };
      InAppWebViewPlatform.instance = platform;
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      try {
        await session.prepare();
        final page = await session.fetchHtml(base);
        expect(page.html, contains('id=123'));
        expect(platform.views.single.controller.fetches, 1);
      } finally {
        await session.retire();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  test(
    'reverifying an old loaded dashboard does not extend its freshness',
    () async {
      _seedStoredSession();
      _mockCookieBridge([]);
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform();
      const dashboard =
          '<body><a href="/user/edit.php?id=123">account</a></body>';
      platform.configure = (view) {
        view.controller.verification = {
          'principal': '123',
          'url': base.toString(),
          'dashboard': dashboard,
        };
        view.controller.fetchHtml = dashboard;
      };
      InAppWebViewPlatform.instance = platform;
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      try {
        await session.prepare();
        await Future<void>.delayed(const Duration(milliseconds: 2050));
        await session.verifyAuthentication();
        await session.fetchHtml(base);
        expect(platform.views.single.controller.fetches, 1);
      } finally {
        await session.retire();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  test(
    'unchanged cookies skip secure writes; rotations and failed writes retry',
    () async {
      _seedStoredSession();
      var cookie = 'fixture-only';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('daily/lms_cookie_store'),
            (call) async {
              if (call.method == 'read') {
                return [
                  {'name': 'MoodleSession', 'value': cookie},
                ];
              }
              return true;
            },
          );
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform();
      platform.configure = (view) {
        view.controller.fetchHtml =
            '<body><a href="/user/edit.php?id=123">account</a><main id="region-main"></main></body>';
      };
      InAppWebViewPlatform.instance = platform;
      final storage = _CountingStorage();
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
        secureStorage: storage,
      );
      try {
        await session.prepare();
        expect(storage.writes, 1);
        await session.fetchHtml(base);
        await session.fetchHtml(base.resolve('/mod/quiz/view.php?id=9001'));
        expect(storage.writes, 1);
        expect(platform.views.single.controller.fetches, 2);
        cookie = 'fixture-rotated';
        await session.fetchHtml(base);
        expect(storage.writes, 2);
        cookie = 'fixture-next';
        storage.failNext = true;
        await expectLater(
          session.fetchHtml(base),
          throwsA(isA<LmsWebSessionException>()),
        );
        expect(storage.writes, 3);
        await session.fetchHtml(base);
        expect(storage.writes, 4);
        expect(session.isAuthenticated, isTrue);
        await session.fetchHtml(base);
        expect(storage.writes, 4);
      } finally {
        await session.retire();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  test(
    'automatic reads are restricted to verified dashboard and activity indexes',
    () {
      for (final path in [
        '/',
        '/mod/assign/index.php?id=12',
        '/mod/quiz/index.php?id=34',
        '/mod/quiz/view.php?id=12',
        '/course/view.php?id=1',
        '/report/ubcompletion/user_progress.php?id=34',
      ]) {
        expect(policy.allowsRead(base.resolve(path)), isTrue, reason: path);
      }
      for (final path in [
        '/my/',
        '/course/view.php?id=1&action=complete',
        '/course/view.php?id=1#module-1',
        '/mod/assign/view.php?id=12',
        '/mod/quiz/attempt.php?attempt=12',
        '/mod/quiz/review.php?attempt=12',
        '/mod/quiz/startattempt.php?cmid=12',
        '/mod/quiz/processattempt.php?id=12',
        '/mod/quiz/view.php?id=12&action=submit',
        '/mod/quiz/view.php?id=12&id=13',
        '/mod/vod/view.php?id=12',
        '/login/token.php',
        '/user/managetoken.php',
        '/grade/report/index.php',
        '/lib/ajax/service.php',
        '/mod/assign/index.php?id=0',
        '/mod/assign/index.php?id=1&id=2',
        '/mod/assign/index.php?id=1&action=submit',
        '/mod/assign/index.php?id=1#detail',
        '/report/ubcompletion/user_progress.php?id=1&id=2',
        '/report/ubcompletion/user_progress.php?id=1&userid=2',
        '/report/ubcompletion/user_progress.php?id=1&action=complete',
        '/?action=logout',
      ]) {
        expect(policy.allowsRead(base.resolve(path)), isFalse, reason: path);
      }
    },
  );

  test(
    'school and owner boundaries cannot be escaped with URL decorations',
    () {
      for (final url in [
        'http://ecampus.smu.ac.kr/',
        'https://ecampus.smu.ac.kr:444/',
        'https://user@ecampus.smu.ac.kr/',
        'https://ecampus.smu.ac.kr.attacker.test/',
        'https://sel.jnu.ac.kr/',
      ]) {
        expect(policy.allowsRead(Uri.parse(url)), isFalse, reason: url);
      }
      expect(
        policy.allowsLoginNavigation(
          Uri.parse('https://smsso.smu.ac.kr/svc/tk/Auth.do'),
        ),
        isTrue,
      );
      expect(
        policy.allowsLoginNavigation(
          Uri.parse('https://smu.ac.kr.attacker.test/'),
        ),
        isFalse,
      );
    },
  );

  test('principal comes only from unambiguous signed-in preferences link', () {
    expect(
      policy.principalFromHtml('<a href="/user/edit.php?id=123">설정</a>'),
      '123',
    );
    expect(
      policy.principalFromHtml('<a href="/user/profile.php?id=999">학생</a>'),
      isNull,
    );
    expect(
      policy.principalFromHtml(
        '<input type="password"><a href="/user/edit.php?id=123">설정</a>',
      ),
      isNull,
    );
    expect(
      policy.principalFromHtml(
        '<a href="https://other.test/user/edit.php?id=123">설정</a>',
      ),
      isNull,
    );
    expect(
      policy.principalFromHtml(
        '<a href="/user/edit.php?id=123">설정</a><a href="/user/edit.php?id=456">설정</a>',
      ),
      isNull,
    );
  });

  test(
    'startup without saved authentication does not create a native WebView',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = LmsWebSession(
        ownerId: ' STUDENT@EXAMPLE.COM ',
        schoolId: 'smu',
      );
      expect(session.ownerId, 'student@example.com');
      expect(await session.hasStoredSession(), isFalse);
      await session.prepare();
      expect(session.headlessView, isNull);
      expect(session.isAuthenticated, isFalse);
      session.dispose();
    },
  );

  test(
    'stored identity is available offline and isolated by Google owner',
    () async {
      const owner = 'student@example.com';
      final key = sha256.convert(utf8.encode('$owner\nsmu'));
      FlutterSecureStorage.setMockInitialValues({
        'daily.lms.session.v1.$key': jsonEncode({
          'owner': owner,
          'school': 'smu',
          'principal': '123',
          'cookies': [
            {'name': 'MoodleSession', 'value': 'unit-test-session'},
          ],
        }),
      });
      final same = LmsWebSession(ownerId: owner, schoolId: 'smu');
      final other = LmsWebSession(
        ownerId: 'other@example.com',
        schoolId: 'smu',
      );
      expect(await same.hasStoredSession(), isTrue);
      expect(same.storedPrincipalId, '123');
      expect(same.isAuthenticated, isFalse);
      expect(await other.hasStoredSession(), isFalse);
      same.dispose();
      other.dispose();
    },
  );

  test(
    'expired cookies retain only account-scoped identity without browser restore',
    () async {
      const owner = 'student@example.com';
      final key = sha256.convert(utf8.encode('$owner\nsmu'));
      FlutterSecureStorage.setMockInitialValues({
        'daily.lms.session.v1.$key': jsonEncode({
          'owner': owner,
          'school': 'smu',
          'principal': '123',
          'cookies': [],
        }),
      });
      final session = LmsWebSession(ownerId: owner, schoolId: 'smu');
      expect(await session.hasStoredSession(), isFalse);
      expect(session.storedPrincipalId, '123');
      await session.prepare();
      expect(await session.recoverAuthentication(), isFalse);
      expect(session.headlessView, isNull);
      expect(session.isAuthenticated, isFalse);
      await session.disconnect();
      expect(await session.hasStoredSession(), isFalse);
      expect(session.storedPrincipalId, isNull);
      session.dispose();
    },
  );

  test(
    'retired login pages cannot restart or verify the old session',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      await session.retire();
      final authenticationRequired = isA<LmsWebSessionException>().having(
        (error) => error.code,
        'code',
        LmsWebSessionError.authenticationRequired,
      );
      await expectLater(session.beginLogin(), throwsA(authenticationRequired));
      expect(session.prepare, throwsA(authenticationRequired));
      expect(session.verifyAuthentication, throwsA(authenticationRequired));
      expect(session.isAuthenticated, isFalse);
      expect(session.isLoginVisible, isFalse);
      session.dispose();
    },
  );

  test(
    'retirement waits for restoration and rejects its late identity',
    () async {
      final storage = _DelayedStorage();
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
        secureStorage: storage,
      );
      final preparing = session.prepare();
      final expectation = expectLater(
        preparing,
        throwsA(isA<LmsWebSessionException>()),
      );
      var retired = false;
      final retirement = session.retire().then((_) => retired = true);
      await Future<void>.delayed(Duration.zero);
      expect(retired, isFalse);
      storage.readResult.complete(
        jsonEncode({
          'owner': 'student@example.com',
          'school': 'smu',
          'principal': '123',
          'cookies': [
            {'name': 'MoodleSession', 'value': 'fixture-only'},
          ],
        }),
      );
      await expectation;
      await retirement;
      expect(session.storedPrincipalId, isNull);
      expect(session.headlessView, isNull);
      session.dispose();
    },
  );

  test(
    'headless restoration waits for an attachable Apple host without touching saved auth',
    () async {
      _seedStoredSession();
      const channel = MethodChannel('daily/lms_cookie_store');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return false;
          });
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform();
      InAppWebViewPlatform.instance = platform;
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      try {
        await expectLater(
          session.prepare(),
          throwsA(
            isA<LmsWebSessionException>().having(
              (e) => e.code,
              'code',
              LmsWebSessionError.hostUnavailable,
            ),
          ),
        );
        expect(platform.views, isEmpty);
        expect(calls, ['canStartHeadless']);
        expect(await session.hasStoredSession(), isTrue);
        expect(session.storedPrincipalId, '123');
        expect(session.headlessView, isNull);
      } finally {
        await session.retire();
        session.dispose();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  test(
    'early headless load failure preserves saved auth and cleans up for retry',
    () async {
      _seedStoredSession();
      final calls = <String>[];
      _mockCookieBridge(calls);
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform()
        ..configure = (view) => view.failInitialLoad = true;
      InAppWebViewPlatform.instance = platform;
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      try {
        await expectLater(
          session.prepare(),
          throwsA(
            isA<LmsWebSessionException>().having(
              (error) => error.code,
              'code',
              LmsWebSessionError.network,
            ),
          ),
        );
        expect(await session.hasStoredSession(), isTrue);
        expect(session.headlessView, isNull);
        expect(platform.views.single.disposals, 1);
        expect(calls, ['canStartHeadless']);
        platform.configure = null;
        await session.prepare();
        expect(platform.views.length, 2);
        expect(session.isAuthenticated, isTrue);
      } finally {
        await session.retire();
        session.dispose();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  for (final failure in const {
    'school_view_missing': LmsWebSessionError.viewUnavailable,
    'school_marker_missing': LmsWebSessionError.viewMismatch,
    'school_view_ambiguous': LmsWebSessionError.viewAmbiguous,
    'school_script_unavailable': LmsWebSessionError.scriptUnavailable,
    'invalid_marker': LmsWebSessionError.invalidResponse,
  }.entries) {
    test(
      'unbound ${failure.key} view is disposed and next restore builds a fresh private view',
      () async {
        _seedStoredSession();
        const channel = MethodChannel('daily/lms_cookie_store');
        var bindings = 0;
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              if (call.method == 'bind' && ++bindings == 1) {
                throw PlatformException(
                  code: failure.key,
                  message: 'private-native-message',
                );
              }
              if (call.method == 'read') {
                return [
                  {'name': 'MoodleSession', 'value': 'fixture-only'},
                ];
              }
              return true;
            });
        final oldPlatform = InAppWebViewPlatform.instance;
        final platform = _HeadlessPlatform();
        InAppWebViewPlatform.instance = platform;
        final session = LmsWebSession(
          ownerId: 'student@example.com',
          schoolId: 'smu',
        );
        try {
          await expectLater(
            session.prepare(),
            throwsA(
              isA<LmsWebSessionException>()
                  .having((e) => e.code, 'code', failure.value)
                  .having(
                    (e) => e.toString(),
                    'safe diagnostic',
                    isNot(contains('private-native-message')),
                  ),
            ),
          );
          expect(platform.views.single.disposals, 1);
          expect(session.headlessView, isNull);
          expect(await session.hasStoredSession(), isTrue);
          expect(session.storedPrincipalId, '123');
          expect(calls, isNot(contains('clear')));
          await session.prepare();
          expect(platform.views, hasLength(2));
          expect(platform.views.last.disposals, 0);
          expect(bindings, 2);
          expect(session.isAuthenticated, isTrue);
          expect(session.principalId, '123');
          expect(calls, isNot(contains('clear')));
        } finally {
          await session.retire();
          session.dispose();
          if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        }
      },
      skip: !Platform.isMacOS && !Platform.isIOS,
    );
  }

  test(
    'close during pre-cookie view lookup preserves the stored session for retry',
    () async {
      _seedStoredSession();
      final calls = <String>[];
      _mockCookieBridge(calls);
      final gate = Completer<WebUri?>();
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform();
      platform.configure = (view) {
        if (platform.views.length == 1) view.controller.urlGate = gate;
      };
      InAppWebViewPlatform.instance = platform;
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      try {
        final preparing = session.prepare();
        final rejected = expectLater(
          preparing,
          throwsA(isA<LmsWebSessionException>()),
        );
        while (platform.views.isEmpty ||
            platform.views.single.controller.urlReads == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final closing = session.close();
        gate.complete(WebUri('https://ecampus.smu.ac.kr/'));
        await rejected;
        await closing;
        expect(await session.hasStoredSession(), isTrue);
        expect(calls, isNot(contains('write')));
        expect(calls, isNot(contains('clear')));
        await session.prepare();
        expect(session.isAuthenticated, isTrue);
        expect(platform.views, hasLength(2));
      } finally {
        await session.retire();
        session.dispose();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  test(
    'quiz access password does not invalidate the school session',
    () async {
      _seedStoredSession();
      final calls = <String>[];
      _mockCookieBridge(calls);
      final oldPlatform = InAppWebViewPlatform.instance;
      final platform = _HeadlessPlatform();
      platform.configure = (view) => view.controller.fetchHtml =
          '<body id="page-mod-quiz-view"><nav><a href="/user/edit.php?id=123">계정</a></nav><main id="region-main"><input type="password" name="quizpassword"></main></body>';
      InAppWebViewPlatform.instance = platform;
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      try {
        await session.prepare();
        await expectLater(
          session.fetchHtml(
            Uri.parse('https://ecampus.smu.ac.kr/mod/quiz/view.php?id=9001'),
          ),
          throwsA(
            isA<LmsWebSessionException>().having(
              (e) => e.code,
              'code',
              LmsWebSessionError.invalidResponse,
            ),
          ),
        );
        expect(session.isAuthenticated, isTrue);
        expect(await session.hasStoredSession(), isTrue);
        expect(calls, isNot(contains('clear')));
      } finally {
        await session.retire();
        session.dispose();
        if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  for (final incompleteUrl in <String?>[null, 'https://unrelated.example/']) {
    test(
      'pre-cookie incomplete URL $incompleteUrl does not revoke saved auth',
      () async {
        _seedStoredSession();
        final calls = <String>[];
        _mockCookieBridge(calls);
        final oldPlatform = InAppWebViewPlatform.instance;
        final platform = _HeadlessPlatform();
        platform.configure = (view) {
          if (platform.views.length == 1) {
            view.controller.currentUrl = incompleteUrl == null
                ? null
                : WebUri(incompleteUrl);
          }
        };
        InAppWebViewPlatform.instance = platform;
        final session = LmsWebSession(
          ownerId: 'student@example.com',
          schoolId: 'smu',
        );
        try {
          await expectLater(
            session.prepare(),
            throwsA(
              isA<LmsWebSessionException>().having(
                (e) => e.code,
                'code',
                incompleteUrl == null
                    ? LmsWebSessionError.viewUnavailable
                    : LmsWebSessionError.invalidResponse,
              ),
            ),
          );
          expect(await session.hasStoredSession(), isTrue);
          expect(session.storedPrincipalId, '123');
          expect(session.headlessView, isNull);
          expect(platform.views.single.disposals, 1);
          expect(calls, isNot(contains('bind')));
          expect(calls, isNot(contains('write')));
          expect(calls, isNot(contains('clear')));
          await session.prepare();
          expect(session.isAuthenticated, isTrue);
          expect(platform.views, hasLength(2));
        } finally {
          await session.retire();
          session.dispose();
          if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
          _clearMockCookieBridge();
        }
      },
      skip: !Platform.isMacOS && !Platform.isIOS,
    );
  }

  for (final cancelAfterRejection in [false, true]) {
    test(
      'verified rejection discards cookies only in current lifecycle (cancel=$cancelAfterRejection)',
      () async {
        _seedStoredSession();
        final calls = <String>[];
        _mockCookieBridge(calls);
        final oldPlatform = InAppWebViewPlatform.instance;
        final platform = _HeadlessPlatform();
        platform.configure = (view) =>
            view.controller.verification = {'authenticationRequired': true};
        InAppWebViewPlatform.instance = platform;
        final session = LmsWebSession(
          ownerId: 'student@example.com',
          schoolId: 'smu',
        );
        Future<void>? closing;
        var cancelled = false;
        if (cancelAfterRejection) {
          session.addListener(() {
            if (!cancelled) {
              cancelled = true;
              closing = session.close();
            }
          });
        }
        try {
          await expectLater(
            session.prepare(),
            throwsA(
              isA<LmsWebSessionException>().having(
                (e) => e.code,
                'code',
                LmsWebSessionError.authenticationRequired,
              ),
            ),
          );
          await closing;
          expect(await session.hasStoredSession(), cancelAfterRejection);
          expect(session.storedPrincipalId, '123');
          expect(session.isAuthenticated, isFalse);
          expect(calls, contains('write'));
        } finally {
          await session.retire();
          session.dispose();
          if (oldPlatform != null) InAppWebViewPlatform.instance = oldPlatform;
          _clearMockCookieBridge();
        }
      },
      skip: !Platform.isMacOS && !Platform.isIOS,
    );
  }

  test(
    'root-valid repeated endpoint 401 stops retry and preserves authentication',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const channel = MethodChannel('daily/lms_cookie_store');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'read') {
              return [
                {'name': 'MoodleSession', 'value': 'fixture-only'},
              ];
            }
            return true;
          });
      final session = _RecoverySession();
      final web = _AuthenticatedWebController();
      web.onLoadFinished = session.pageLoadFinished;
      try {
        await session.beginLogin();
        session.attachLoginController(web);
        expect(await session.verifyAuthentication(), '123');
        await session.finishLogin(authenticated: true);
        final authError = isA<LmsWebSessionException>().having(
          (error) => error.code,
          'code',
          LmsWebSessionError.authenticationRequired,
        );
        await expectLater(session.fetchHtml(base), throwsA(authError));
        expect(await session.hasStoredSession(), isTrue);
        expect(await session.recoverAuthentication(), isTrue);
        expect(session.preparations, 0);
        expect(web.rootLoads, 1);
        await expectLater(session.fetchHtml(base), throwsA(_invalidResponse));
        expect(await session.recoverAuthentication(), isFalse);
        expect(session.preparations, 0);
        expect(await session.hasStoredSession(), isTrue);
        expect(session.isAuthenticated, isTrue);
        expect(web.rootLoads, 2);
        expect(session.storedPrincipalId, '123');
        expect(web.fetches, 2);
        expect(
          session.authenticationDiagnostics.map((item) => item.reason),
          isNot(contains(LmsAuthenticationReason.credentialsDiscarded)),
        );
      } finally {
        await session.retire();
        session.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  for (final reason in ['redirect', 'origin', 'login-form']) {
    test(
      'repeated $reason keeps verified live store and does not restore old cookies',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final calls = <String>[];
        _mockCookieBridge(calls);
        final session = _RecoverySession();
        final web = _AuthenticatedWebController()..fetchReason = reason;
        web.onLoadFinished = session.pageLoadFinished;
        try {
          await session.beginLogin();
          session.attachLoginController(web);
          await session.verifyAuthentication();
          await session.finishLogin(authenticated: true);
          await expectLater(session.fetchHtml(base), throwsA(_authError));
          expect(await session.recoverAuthentication(), isTrue);
          await expectLater(session.fetchHtml(base), throwsA(_invalidResponse));
          expect(await session.recoverAuthentication(), isFalse);
          expect(session.isAuthenticated, isTrue);
          expect(await session.hasStoredSession(), isTrue);
          expect(calls.where((call) => call == 'write'), isEmpty);
          expect(web.rootLoads, 2);
          expect(web.fetches, 2);
          expect(session.preparations, 0);
          final diagnostics = session.authenticationDiagnostics;
          expect(
            diagnostics.map((entry) => entry.reason),
            containsAllInOrder([
              reason == 'redirect'
                  ? LmsAuthenticationReason.readRedirect
                  : reason == 'origin'
                  ? LmsAuthenticationReason.readOriginChanged
                  : LmsAuthenticationReason.readLoginForm,
              LmsAuthenticationReason.recoveryStarted,
              LmsAuthenticationReason.rootAccepted,
              LmsAuthenticationReason.recoverySucceeded,
            ]),
          );
          expect(diagnostics.every((entry) => entry.occurredAt.isUtc), isTrue);
          expect(diagnostics.every((entry) => entry.generation >= 0), isTrue);
        } finally {
          await session.retire();
          session.dispose();
          _clearMockCookieBridge();
        }
      },
      skip: !Platform.isMacOS && !Platform.isIOS,
    );
  }

  for (final result in [
    'login-form',
    'other-principal',
    'unrecognized',
    'network',
    'cancel',
  ]) {
    test(
      'final root $result determines disposal without another activity retry',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final calls = <String>[];
        _mockCookieBridge(calls);
        final session = _RecoverySession();
        final web = _AuthenticatedWebController();
        web.onLoadFinished = session.pageLoadFinished;
        Future<void>? closing;
        var cancelled = false;
        try {
          await session.beginLogin();
          session.attachLoginController(web);
          await session.verifyAuthentication();
          await session.finishLogin(authenticated: true);
          await expectLater(session.fetchHtml(base), throwsA(_authError));
          expect(await session.recoverAuthentication(), isTrue);
          web.verification = switch (result) {
            'other-principal' => '456',
            'unrecognized' => {'unrecognized': true},
            _ => {'authenticationRequired': true},
          };
          if (result == 'network') {
            web.onLoadFinished = session.pageLoadFailed;
          }
          if (result == 'cancel') {
            session.addListener(() {
              if (!cancelled &&
                  session.authenticationDiagnostics.last.reason ==
                      LmsAuthenticationReason.rootLoginForm) {
                cancelled = true;
                closing = session.close();
              }
            });
          }
          final rejected =
              result == 'login-form' || result == 'other-principal';
          await expectLater(
            session.fetchHtml(base),
            throwsA(
              result == 'network'
                  ? isA<LmsWebSessionException>().having(
                      (error) => error.code,
                      'code',
                      LmsWebSessionError.network,
                    )
                  : result == 'unrecognized'
                  ? _invalidResponse
                  : _authError,
            ),
          );
          await closing;
          expect(await session.hasStoredSession(), !rejected);
          expect(await session.recoverAuthentication(), isFalse);
          expect(calls.where((call) => call == 'write'), isEmpty);
          expect(web.fetches, 2);
          expect(web.rootLoads, 2);
          expect(session.preparations, 0);
          expect(
            session.authenticationDiagnostics.any(
              (entry) =>
                  entry.reason == LmsAuthenticationReason.credentialsDiscarded,
            ),
            rejected,
          );
        } finally {
          await session.retire();
          session.dispose();
          _clearMockCookieBridge();
        }
      },
      skip: !Platform.isMacOS && !Platform.isIOS,
    );
  }

  test(
    'current root login form permits one saved-snapshot restore',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final calls = <String>[];
      _mockCookieBridge(calls);
      final session = _RecoverySession();
      final web = _AuthenticatedWebController();
      web.onLoadFinished = session.pageLoadFinished;
      try {
        await session.beginLogin();
        session.attachLoginController(web);
        await session.verifyAuthentication();
        await session.finishLogin(authenticated: true);
        web.verifications.addAll([
          {'authenticationRequired': true},
          '123',
        ]);
        await expectLater(session.fetchHtml(base), throwsA(_authError));
        expect(await session.recoverAuthentication(), isTrue);
        expect(session.preparations, 1);
        expect(calls.where((call) => call == 'write').length, 1);
        expect(web.rootLoads, 2);
        expect(
          session.authenticationDiagnostics.map((entry) => entry.reason),
          containsAllInOrder([
            LmsAuthenticationReason.rootLoginForm,
            LmsAuthenticationReason.snapshotRestoreStarted,
            LmsAuthenticationReason.rootAccepted,
            LmsAuthenticationReason.recoverySucceeded,
          ]),
        );
      } finally {
        await session.retire();
        session.dispose();
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  for (final reject in ['other-principal', 'unrecognized', 'cancel']) {
    test(
      'current root $reject never overwrites live store from saved snapshot',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final calls = <String>[];
        _mockCookieBridge(calls);
        final session = _RecoverySession();
        final web = _AuthenticatedWebController();
        web.onLoadFinished = session.pageLoadFinished;
        Future<void>? closing;
        var cancelled = false;
        try {
          await session.beginLogin();
          session.attachLoginController(web);
          await session.verifyAuthentication();
          await session.finishLogin(authenticated: true);
          await expectLater(session.fetchHtml(base), throwsA(_authError));
          web.verification = switch (reject) {
            'other-principal' => '456',
            'cancel' => {'authenticationRequired': true},
            _ => {'unrecognized': true},
          };
          if (reject == 'cancel') {
            session.addListener(() {
              if (!cancelled &&
                  session.authenticationDiagnostics.last.reason ==
                      LmsAuthenticationReason.rootLoginForm) {
                cancelled = true;
                closing = session.close();
              }
            });
          }
          if (reject == 'other-principal') {
            expect(await session.recoverAuthentication(), isFalse);
          } else {
            await expectLater(
              session.recoverAuthentication(),
              throwsA(reject == 'cancel' ? _authError : _invalidResponse),
            );
          }
          await closing;
          if (reject == 'unrecognized') {
            await expectLater(session.prepare(), throwsA(_invalidResponse));
            web.verification = '123';
            await session.prepare();
            expect(session.isAuthenticated, isTrue);
          }
          expect(calls.where((call) => call == 'write'), isEmpty);
          expect(session.preparations, reject == 'unrecognized' ? 2 : 0);
          expect(await session.hasStoredSession(), reject != 'other-principal');
        } finally {
          await session.retire();
          session.dispose();
          _clearMockCookieBridge();
        }
      },
      skip: !Platform.isMacOS && !Platform.isIOS,
    );
  }

  test(
    'completed refresh allows a later independent recovery',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final calls = <String>[];
      _mockCookieBridge(calls);
      final session = _RecoverySession();
      final web = _AuthenticatedWebController();
      web.onLoadFinished = session.pageLoadFinished;
      try {
        await session.beginLogin();
        session.attachLoginController(web);
        await session.verifyAuthentication();
        await session.finishLogin(authenticated: true);
        for (var pass = 0; pass < 2; pass++) {
          await expectLater(session.fetchHtml(base), throwsA(_authError));
          expect(await session.recoverAuthentication(), isTrue);
          session.acknowledgeSuccessfulRefresh();
        }
        expect(web.rootLoads, 2);
        expect(await session.hasStoredSession(), isTrue);
        expect(calls.where((call) => call == 'write'), isEmpty);
      } finally {
        await session.retire();
        session.dispose();
        _clearMockCookieBridge();
      }
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  test(
    'retirement waits for one in-flight verification before cleanup',
    () async {
      final session = LmsWebSession(
        ownerId: 'student@example.com',
        schoolId: 'smu',
      );
      await session.beginLogin();
      final controller = _DelayedWebController();
      session.attachLoginController(controller);
      final first = session.verifyAuthentication();
      expect(identical(first, session.verifyAuthentication()), isTrue);
      final expectation = expectLater(
        first,
        throwsA(isA<LmsWebSessionException>()),
      );
      var retired = false;
      final retirement = session.retire().then((_) => retired = true);
      await Future<void>.delayed(Duration.zero);
      expect(retired, isFalse);
      expect(controller.stopCount, 0);
      controller.urlResult.complete(WebUri('https://ecampus.smu.ac.kr/'));
      await expectation;
      await retirement;
      expect(controller.stopCount, 1);
      expect(controller.scriptCount, 0);
      expect(session.principalId, isNull);
      expect(session.isAuthenticated, isFalse);
      session.dispose();
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );
}

final _authError = isA<LmsWebSessionException>().having(
  (error) => error.code,
  'code',
  LmsWebSessionError.authenticationRequired,
);
final _invalidResponse = isA<LmsWebSessionException>().having(
  (error) => error.code,
  'code',
  LmsWebSessionError.invalidResponse,
);

void _seedStoredSession() {
  const owner = 'student@example.com';
  final key = sha256.convert(utf8.encode('$owner\nsmu'));
  FlutterSecureStorage.setMockInitialValues({
    'daily.lms.session.v1.$key': jsonEncode({
      'owner': owner,
      'school': 'smu',
      'principal': '123',
      'cookies': [
        {'name': 'MoodleSession', 'value': 'fixture-only'},
      ],
    }),
  });
}

void _mockCookieBridge(List<String> calls) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('daily/lms_cookie_store'), (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'read') {
          return [
            {'name': 'MoodleSession', 'value': 'fixture-only'},
          ];
        }
        return true;
      });
}

void _clearMockCookieBridge() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('daily/lms_cookie_store'),
        null,
      );
}

class _HeadlessPlatform extends InAppWebViewPlatform {
  final views = <_HeadlessView>[];
  void Function(_HeadlessView)? configure;

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) {
    final view = _HeadlessView(params);
    views.add(view);
    configure?.call(view);
    return view;
  }
}

class _HeadlessView extends PlatformHeadlessInAppWebView {
  _HeadlessView(super.params) : super.implementation();
  final controller = _AuthenticatedWebController();
  int disposals = 0;
  bool failInitialLoad = false;

  @override
  Future<void> run() async {
    controller.onLoadFinished = () => params.onLoadStop?.call(
      controller,
      WebUri('https://ecampus.smu.ac.kr/'),
    );
    params.onWebViewCreated?.call(controller);
    if (failInitialLoad) {
      params.onReceivedError?.call(
        controller,
        WebResourceRequest(
          url: WebUri('https://ecampus.smu.ac.kr/'),
          isForMainFrame: true,
        ),
        WebResourceError(
          description: 'fixture-only',
          type: WebResourceErrorType.UNKNOWN,
        ),
      );
      return;
    }
    controller.onLoadFinished!();
  }

  @override
  Future<void> dispose() async => disposals++;
}

class _RecoverySession extends LmsWebSession {
  _RecoverySession() : super(ownerId: 'student@example.com', schoolId: 'smu');
  int preparations = 0;

  @override
  Future<void> prepare() async {
    preparations++;
    await super.prepare();
  }
}

class _AuthenticatedWebController implements InAppWebViewController {
  int fetches = 0;
  int rootLoads = 0;
  void Function()? onLoadFinished;
  WebUri? currentUrl = WebUri('https://ecampus.smu.ac.kr/');
  Completer<WebUri?>? urlGate;
  int urlReads = 0;
  Object? verification = '123';
  final verifications = <Object?>[];
  String fetchReason = 'unauthorized';
  String? fetchHtml;

  @override
  Future<WebUri?> getUrl() async {
    urlReads++;
    return urlGate == null ? currentUrl : await urlGate!.future;
  }

  @override
  Future<void> stopLoading() async {}

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    expect(urlRequest.url.toString(), 'https://ecampus.smu.ac.kr/');
    rootLoads++;
    onLoadFinished?.call();
  }

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async {
    if (functionBody.contains('await fetch')) {
      fetches++;
      if (fetchHtml != null) {
        return CallAsyncJavaScriptResult(
          value: {'status': 'ok', 'url': arguments['url'], 'html': fetchHtml},
        );
      }
      if (fetchReason == 'login-form') {
        return CallAsyncJavaScriptResult(
          value: {
            'status': 'ok',
            'url': arguments['url'],
            'html': '<form><input type="password"></form>',
          },
        );
      }
      return CallAsyncJavaScriptResult(
        value: {'status': 'auth', 'reason': fetchReason},
      );
    }
    return CallAsyncJavaScriptResult(
      value: functionBody.contains('const ids')
          ? (verifications.isEmpty ? verification : verifications.removeAt(0))
          : '',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingStorage extends FlutterSecureStorage {
  int writes = 0;
  bool failNext = false;
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
    writes++;
    if (failNext) {
      failNext = false;
      throw StateError('fixture secure write failure');
    }
    await super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

class _DelayedStorage extends FlutterSecureStorage {
  final readResult = Completer<String?>();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => readResult.future;
}

class _DelayedWebController implements InAppWebViewController {
  final urlResult = Completer<WebUri?>();
  int stopCount = 0;
  int scriptCount = 0;

  @override
  Future<WebUri?> getUrl() => urlResult.future;

  @override
  Future<void> stopLoading() async => stopCount++;

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async {
    scriptCount++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
