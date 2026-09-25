import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show
        InAppWebViewController,
        WebUri,
        CallAsyncJavaScriptResult,
        ContentWorld;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final base = Uri.parse('https://ecampus.smu.ac.kr/');
  final policy = LmsWebRequestPolicy(base);

  test(
    'automatic reads are restricted to verified dashboard and activity indexes',
    () {
      for (final path in [
        '/',
        '/mod/assign/index.php?id=12',
        '/mod/quiz/index.php?id=34',
      ]) {
        expect(policy.allowsRead(base.resolve(path)), isTrue, reason: path);
      }
      for (final path in [
        '/my/',
        '/course/view.php?id=1',
        '/mod/assign/view.php?id=12',
        '/mod/quiz/view.php?id=12',
        '/mod/vod/view.php?id=12',
        '/login/token.php',
        '/user/managetoken.php',
        '/grade/report/index.php',
        '/lib/ajax/service.php',
        '/mod/assign/index.php?id=0',
        '/mod/assign/index.php?id=1&id=2',
        '/mod/assign/index.php?id=1&action=submit',
        '/mod/assign/index.php?id=1#detail',
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
