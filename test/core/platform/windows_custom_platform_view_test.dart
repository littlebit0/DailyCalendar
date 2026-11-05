import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview_windows/src/in_app_webview/custom_platform_view.dart';

const _manager = MethodChannel('com.pichillilorenzo/flutter_inappwebview_manager');
const _textureId = 7;

class _FakeNative {
  _FakeNative(this.created) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_manager, (call) async {
      switch (call.method) {
        case 'createInAppWebView':
          return created.future;
        case 'dispose':
          disposed.add((call.arguments as Map)['id'] as int);
          return null;
      }
      return null;
    });
    for (final name in [
      'com.pichillilorenzo/custom_platform_view_$_textureId',
      'com.pichillilorenzo/custom_platform_view_${_textureId}_events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        viewCalls.add(call.method);
        return null;
      });
    }
  }

  final Completer<int> created;
  final disposed = <int>[];
  final viewCalls = <String>[];

  void reset() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_manager, null);
    for (final name in [
      'com.pichillilorenzo/custom_platform_view_$_textureId',
      'com.pichillilorenzo/custom_platform_view_${_textureId}_events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  }
}

Widget _view(void Function(int) onCreated) => Directionality(
      textDirection: TextDirection.ltr,
      child: CustomPlatformView(onPlatformViewCreated: onCreated),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('closing before creation completes skips the removed view',
      (tester) async {
    final native = _FakeNative(Completer<int>());
    addTearDown(native.reset);
    final created = <int>[];
    await tester.pumpWidget(_view(created.add));
    await tester.pumpWidget(const SizedBox());

    native.created.complete(_textureId);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(created, isEmpty);
    expect(native.disposed, [_textureId]);
    expect(native.viewCalls, isNot(contains('setPosition')));
    expect(native.viewCalls, isNot(contains('setSize')));
  });

  testWidgets('a created view reports once, then disposes once on close',
      (tester) async {
    final native = _FakeNative(Completer<int>());
    addTearDown(native.reset);
    final created = <int>[];
    await tester.pumpWidget(_view(created.add));
    native.created.complete(_textureId);
    await tester.pumpAndSettle();

    expect(created, [_textureId]);
    expect(native.viewCalls, containsAll(['setSize', 'setPosition']));

    await tester.pumpWidget(const SizedBox());
    // The event-stream cancel reply is delivered outside fake async.
    await tester.runAsync(
      () => tester.binding.defaultBinaryMessenger.platformMessagesFinished,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(native.disposed, [_textureId]);
  });

  test('failed creation reports the error and disposes without native call',
      () async {
    final native = _FakeNative(Completer<int>());
    addTearDown(native.reset);
    final controller = CustomPlatformViewController();
    final created = <int>[];
    final init = controller.initialize(onPlatformViewCreated: created.add);
    native.created.completeError(PlatformException(code: 'create-failed'));

    await expectLater(init, throwsA(isA<PlatformException>()));
    await controller.dispose();
    expect(created, isEmpty);
    expect(native.disposed, isEmpty);
  });

  test('repeated dispose releases the native view once', () async {
    final native = _FakeNative(Completer<int>()..complete(_textureId));
    addTearDown(native.reset);
    final controller = CustomPlatformViewController();
    await controller.initialize();

    final first = controller.dispose();
    final second = controller.dispose();
    await Future.wait([first, second]);
    expect(native.disposed, [_textureId]);
  });
}
