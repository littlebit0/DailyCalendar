// Vendored platform packages are pinned through dependency_overrides; the test
// exercises their real headless lifecycle code directly.
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview_android/src/in_app_webview/headless_in_app_webview.dart'
    as android;
import 'package:flutter_inappwebview_ios/src/in_app_webview/headless_in_app_webview.dart'
    as ios;
import 'package:flutter_inappwebview_macos/src/in_app_webview/headless_in_app_webview.dart'
    as macos;
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_inappwebview_windows/src/in_app_webview/headless_in_app_webview.dart'
    as windows;
import 'package:flutter_test/flutter_test.dart';

const _sharedChannel =
    MethodChannel('com.pichillilorenzo/flutter_headless_inappwebview');

class _Platform {
  const _Platform(this.name, this.create, this.internalDispose);

  final String name;
  final PlatformHeadlessInAppWebView Function(
      void Function(dynamic) onWebViewCreated) create;
  final Future<void> Function(PlatformHeadlessInAppWebView) internalDispose;
}

final _platforms = <_Platform>[
  _Platform(
    'macOS',
    (cb) => macos.MacOSHeadlessInAppWebView(
        PlatformHeadlessInAppWebViewCreationParams(onWebViewCreated: cb)),
    (w) => macos.InternalHeadlessInAppWebView(
            w as macos.MacOSHeadlessInAppWebView)
        .internalDispose(),
  ),
  _Platform(
    'Windows',
    (cb) => windows.WindowsHeadlessInAppWebView(
        PlatformHeadlessInAppWebViewCreationParams(onWebViewCreated: cb)),
    (w) => windows.InternalHeadlessInAppWebView(
            w as windows.WindowsHeadlessInAppWebView)
        .internalDispose(),
  ),
  _Platform(
    'iOS',
    (cb) => ios.IOSHeadlessInAppWebView(
        PlatformHeadlessInAppWebViewCreationParams(onWebViewCreated: cb)),
    (w) =>
        ios.InternalHeadlessInAppWebView(w as ios.IOSHeadlessInAppWebView)
            .internalDispose(),
  ),
  _Platform(
    'Android',
    (cb) => android.AndroidHeadlessInAppWebView(
        PlatformHeadlessInAppWebViewCreationParams(onWebViewCreated: cb)),
    (w) => android.InternalHeadlessInAppWebView(
            w as android.AndroidHeadlessInAppWebView)
        .internalDispose(),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> sendFromNative(String channelName, String method) async {
    await messenger.handlePlatformMessage(
      channelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
      (_) {},
    );
  }

  for (final platform in _platforms) {
    group('${platform.name} headless WebView channel', () {
      late List<String> nativeCalls;
      late int createdCalls;
      late PlatformHeadlessInAppWebView webView;
      late String headlessChannel;

      setUp(() async {
        nativeCalls = [];
        createdCalls = 0;
        messenger.setMockMethodCallHandler(_sharedChannel, (call) async {
          nativeCalls.add('shared:${call.method}');
          return null;
        });
        webView = platform.create((_) => createdCalls++);
        headlessChannel =
            'com.pichillilorenzo/flutter_headless_inappwebview_${webView.id}';
        messenger.setMockMethodCallHandler(MethodChannel(headlessChannel),
            (call) async {
          nativeCalls.add('headless:${call.method}');
          return null;
        });
        await webView.run();
        await sendFromNative(headlessChannel, 'onWebViewCreated');
        expect(createdCalls, 1);
      });

      tearDown(() {
        messenger.setMockMethodCallHandler(_sharedChannel, null);
        messenger.setMockMethodCallHandler(
            MethodChannel(headlessChannel), null);
      });

      test('transfer releases the headless-only handler and controller',
          () async {
        await platform.internalDispose(webView);

        expect(webView.isRunning(), isFalse);
        expect(webView.webViewController, isNull);
        await sendFromNative(headlessChannel, 'onWebViewCreated');
        expect(createdCalls, 1);
      });

      test('dispose after transfer does not dispose the transferred native view',
          () async {
        await platform.internalDispose(webView);
        await webView.dispose();
        await webView.dispose();

        expect(nativeCalls, isNot(contains('headless:dispose')));
        await sendFromNative(headlessChannel, 'onWebViewCreated');
        expect(createdCalls, 1);
      });

      test('normal dispose still disposes native view and handler', () async {
        await webView.dispose();
        await webView.dispose();

        expect(
            nativeCalls.where((c) => c == 'headless:dispose'), hasLength(1));
        await sendFromNative(headlessChannel, 'onWebViewCreated');
        expect(createdCalls, 1);
      });
    });
  }
}
