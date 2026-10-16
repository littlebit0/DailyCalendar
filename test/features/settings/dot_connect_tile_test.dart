import 'dart:async';
import 'package:daily/features/settings/presentation/dot_connect_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('daily/dot_integration');
  TestWidgetsFlutterBinding.ensureInitialized();
  var owned = false;
  var testAccess = false;
  var available = true;
  var setup = <String, Object?>{};
  var purchaseResult = 'cancelled';
  PlatformException? pluginError;
  var googleOpenFailures = 0;
  Completer<String>? requestReply;
  final calls = <String>[];

  setUp(() {
    owned = false;
    testAccess = false;
    available = true;
    setup = {'filesPrepared': true};
    purchaseResult = 'cancelled';
    pluginError = null;
    googleOpenFailures = 0;
    requestReply = null;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'purchaseStatus':
            case 'restorePurchases':
              return {
                'unlocked': owned,
                'testAccess': testAccess,
                'available': available,
                'price': available ? '₩1,000' : '',
              };
            case 'setupStatus':
              return setup;
            case 'preparePlugin':
              if (pluginError != null) throw pluginError!;
              setup = {...setup, 'filesPrepared': true};
              return null;
            case 'openPlugin':
              return null;
            case 'requestSetup':
              if (requestReply != null) return requestReply!.future;
              return 'request-1';
            case 'openGoogle':
              if (googleOpenFailures-- > 0) {
                throw PlatformException(code: 'unavailable');
              }
              return null;
            case 'purchase':
              return purchaseResult;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> show(WidgetTester tester, {bool open = true}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: open ? const DotSetupDialog() : const DotConnectTile(),
        ),
      ),
    );
    if (open) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('suspended Dot entry never opens setup or calls native tools', (
    tester,
  ) async {
    await show(tester, open: false);
    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey('dot-connect-button')),
    );
    expect(tile.enabled, isFalse);
    expect(tile.onTap, isNull);
    expect(find.text('Dot 연동 점검 중 · 사용 중지'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dot-connect-button')));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(DotSetupDialog), findsNothing);
    expect(calls, isEmpty);
    await close(tester);
  });

  testWidgets('hidden on every non-Mac platform', (tester) async {
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.macOS) continue;
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DotConnectTile())),
      );
      expect(find.byKey(const ValueKey('dot-connect-button')), findsNothing);
    }
    expect(calls, isEmpty);
    await close(tester);
  });

  testWidgets('purchase only unlocks Dot and cancellation preserves lock', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('1,000원 일회성 구매로 Dot 기능만 잠금 해제합니다.'), findsOneWidget);
    expect(find.text('플러그인 연결'), findsNothing);
    await tester.ensureVisible(find.text('₩1,000 · Dot 잠금 해제'));
    await tester.tap(find.text('₩1,000 · Dot 잠금 해제'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls.where((x) => x == 'purchase'), hasLength(1));
    expect(find.text('플러그인 연결'), findsNothing);
    expect(calls, isNot(contains('openSkill')));
    await close(tester);
  });

  testWidgets('test access enables plugin without claiming a purchase', (
    tester,
  ) async {
    testAccess = true;
    available = false;
    await show(tester);
    expect(find.text('테스트용 활성화'), findsOneWidget);
    expect(find.text('Dot 구매'), findsNothing);
    await tester.ensureVisible(find.text('플러그인 연결'));
    await tester.tap(find.text('플러그인 연결'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, contains('openPlugin'));
    expect(calls, isNot(contains('purchase')));
    expect(find.text('현재 스토어에서 Dot 구매 상품을 불러올 수 없습니다.'), findsNothing);
    await close(tester);
  });

  testWidgets('unavailable store does not offer an actionable purchase', (
    tester,
  ) async {
    available = false;
    await show(tester);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Dot 잠금 해제'))
          .onPressed,
      isNull,
    );
    expect(find.text('현재 스토어에서 Dot 구매 상품을 불러올 수 없습니다.'), findsOneWidget);
    await close(tester);
  });

  testWidgets('restore rechecks entitlement and later revocation relocks', (
    tester,
  ) async {
    await show(tester);
    owned = true;
    await tester.ensureVisible(find.text('구매 복원'));
    await tester.tap(find.text('구매 복원'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('플러그인 연결'), findsOneWidget);
    owned = false;
    await tester.ensureVisible(find.text('다시 확인'));
    await tester.tap(find.text('다시 확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('플러그인 연결'), findsNothing);
    await close(tester);
  });

  testWidgets(
    'opening plugin never marks installation or Mac access complete',
    (tester) async {
      owned = true;
      await show(tester);
      await tester.ensureVisible(find.text('플러그인 연결'));
      await tester.tap(find.text('플러그인 연결'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(calls, contains('openPlugin'));
      expect(find.text('확인 필요'), findsOneWidget);
      expect(find.text('진행 중'), findsOneWidget);
      expect(find.text('ChatGPT의 Dot 프로필에서 확인'), findsOneWidget);
      setup = {
        'filesPrepared': true,
        'pluginReady': true,
        'googleConnected': true,
        'lastQuery': 1,
      };
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('확인 필요'), findsNothing);
      expect(find.text('ChatGPT의 Dot 프로필에서 확인'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets('pending purchase remains locked', (tester) async {
    purchaseResult = 'pending';
    await show(tester);
    await tester.ensureVisible(find.text('₩1,000 · Dot 잠금 해제'));
    await tester.tap(find.text('₩1,000 · Dot 잠금 해제'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('구매 승인 대기 중입니다.'), findsOneWidget);
    expect(find.text('플러그인 연결'), findsNothing);
    await close(tester);
  });

  testWidgets('checklist actions follow plugin and Google prerequisites', (
    tester,
  ) async {
    testAccess = true;
    await show(tester);
    final google = find.widgetWithText(OutlinedButton, 'Google 연결');
    final read = find.widgetWithText(OutlinedButton, '조회 확인');
    expect(tester.widget<OutlinedButton>(google).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(read).onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dot-step-Google Drive 접근 승인')),
        matching: google,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dot-step-플러그인 설치와 도구 사용')),
        matching: find.text('플러그인 연결'),
      ),
      findsOneWidget,
    );
    setup = {'filesPrepared': true, 'pluginReady': true};
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<OutlinedButton>(google).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(read).onPressed, isNull);
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, contains('requestSetup'));
    setup = {
      'filesPrepared': true,
      'pluginReady': true,
      'googleConnected': true,
      'requestID': 'request-1',
      'requestState': 'complete',
    };
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<OutlinedButton>(read).onPressed, isNotNull);
    await tester.ensureVisible(find.text('Dot 열기'));
    await tester.tap(find.text('Dot 열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, contains('openDot'));
    await close(tester);
  });

  testWidgets(
    'folder cancellation shows retry instead of installation success',
    (tester) async {
      testAccess = true;
      pluginError = PlatformException(code: 'folderCancelled');
      await show(tester);
      await tester.ensureVisible(find.text('연결 파일 만들기'));
      await tester.tap(find.text('연결 파일 만들기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('폴더 선택을 취소했습니다. 연결 파일 만들기를 다시 눌러 주세요.'), findsOneWidget);
      expect(find.text('ChatGPT에서 플러그인 설치와 도구 사용을 허용해 주세요.'), findsNothing);
      expect(find.text('확인 필요'), findsNWidgets(2));
      await close(tester);
    },
  );

  testWidgets(
    'files are generated before plugin handoff and steps are ordered',
    (tester) async {
      testAccess = true;
      setup = {};
      await show(tester);
      final plugin = find.widgetWithText(FilledButton, '플러그인 연결');
      expect(tester.widget<FilledButton>(plugin).onPressed, isNull);
      final stepNames = [
        'Dot 테스트 사용',
        '연결 파일 생성',
        '플러그인 설치와 도구 사용',
        'Google Drive 접근 승인',
        '일정 원본 조회 검증',
        'Dot의 Mac 접근 허용',
      ];
      for (var i = 1; i < stepNames.length; i++) {
        expect(
          tester
              .getTopLeft(find.byKey(ValueKey('dot-step-${stepNames[i]}')))
              .dy,
          greaterThan(
            tester
                .getTopLeft(
                  find.byKey(ValueKey('dot-step-${stepNames[i - 1]}')),
                )
                .dy,
          ),
        );
      }
      await tester.ensureVisible(find.text('연결 파일 만들기'));
      await tester.tap(find.text('연결 파일 만들기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(calls, contains('preparePlugin'));
      expect(calls, isNot(contains('openPlugin')));
      expect(tester.widget<FilledButton>(plugin).onPressed, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dot-step-연결 파일 생성')),
          matching: find.text('완료'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(plugin);
      await tester.tap(plugin);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(calls, contains('openPlugin'));
      await close(tester);
    },
  );

  testWidgets(
    'reopening adopts running request and completion releases buttons',
    (tester) async {
      testAccess = true;
      setup = {
        'filesPrepared': true,
        'pluginReady': true,
        'googleConnected': true,
        'requestID': 'running',
        'requestState': 'running',
        'requestCreatedAt': DateTime.now().millisecondsSinceEpoch / 1000,
      };
      await show(tester);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google 연결'),
            )
            .onPressed,
        isNull,
      );
      setup = {...setup, 'requestState': 'complete', 'lastQuery': 1};
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '조회 확인'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('확인을 완료했습니다.'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets('failed browser opening retries without clearing Google state', (
    tester,
  ) async {
    testAccess = true;
    googleOpenFailures = 1;
    setup = {
      'filesPrepared': true,
      'pluginReady': true,
      'googleConnected': true,
      'requestID': 'running',
      'requestState': 'waiting_for_google',
      'hasAuthURL': true,
      'requestCreatedAt': DateTime.now().millisecondsSinceEpoch / 1000,
    };
    await show(tester);
    expect(calls.where((call) => call == 'openGoogle'), hasLength(1));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dot-step-Google Drive 접근 승인')),
        matching: find.text('진행 중'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls.where((call) => call == 'openGoogle'), hasLength(2));
    await tester.pump(const Duration(seconds: 2));
    expect(calls.where((call) => call == 'openGoogle'), hasLength(2));
    await close(tester);
  });

  testWidgets(
    'running query shows file progress and stops loading on completion',
    (tester) async {
      testAccess = true;
      setup = {
        'filesPrepared': true,
        'pluginReady': true,
        'googleConnected': true,
        'requestID': 'read-running',
        'requestState': 'running',
        'requestAction': 'read',
        'requestCreatedAt': DateTime.now().millisecondsSinceEpoch / 1000,
        'queryPhase': 'downloading',
        'filesRead': 6,
        'filesTotal': 20,
      };
      await show(tester);
      final row = find.byKey(const ValueKey('dot-step-일정 원본 조회 검증'));
      expect(
        find.descendant(
          of: row,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('일정 파일 6/20개 읽는 중'), findsOneWidget);
      setup = {...setup, 'requestState': 'complete', 'lastQuery': 1};
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(
        find.descendant(
          of: row,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await close(tester);
    },
  );

  testWidgets(
    'native updates complete checklist without reopening or waiting for timer',
    (tester) async {
      testAccess = true;
      await show(tester);
      setup = {
        'filesPrepared': true,
        'pluginReady': true,
        'googleConnected': true,
        'lastQuery': 1,
      };
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('setupChanged'),
        ),
        (_) {},
      );
      await tester.pump();
      for (final title in [
        '플러그인 설치와 도구 사용',
        'Google Drive 접근 승인',
        '일정 원본 조회 검증',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('dot-step-$title')),
            matching: find.text('완료'),
          ),
          findsOneWidget,
        );
      }
      await close(tester);
    },
  );

  testWidgets('request shows loading before native acknowledgement', (
    tester,
  ) async {
    testAccess = true;
    setup = {
      'filesPrepared': true,
      'pluginReady': true,
      'googleConnected': true,
    };
    requestReply = Completer<String>();
    await show(tester);
    final button = find.widgetWithText(OutlinedButton, '조회 확인');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    final row = find.byKey(const ValueKey('dot-step-일정 원본 조회 검증'));
    expect(
      find.descendant(of: row, matching: find.text('진행 중')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    requestReply!.complete('new-request');
    await tester.pump();
    await close(tester);
  });

  testWidgets('large text and short window remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const Scaffold(body: DotSetupDialog()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await close(tester);
  });
}
