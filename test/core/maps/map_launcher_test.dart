import 'package:daily/core/maps/map_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('daily/map_launcher');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends a trimmed location to the native map launcher', () async {
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          call = methodCall;
          return 'handled';
        });

    await MapLauncher(channel: channel).openLocation('  서울특별시 중구 세종대로 110  ');

    expect(call?.method, 'openLocation');
    expect(call?.arguments, {'location': '서울특별시 중구 세종대로 110'});
  });

  test('does not call the native launcher for a blank location', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          called = true;
          return 'handled';
        });

    await MapLauncher(channel: channel).openLocation('   ');

    expect(called, isFalse);
  });

  void answer(Object? Function() native) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => native());
  }

  test('handled and cancelled native choices count as opened', () async {
    var webOpened = false;
    answer(() => 'handled');
    final launcher = MapLauncher(
      channel: channel,
      openUrl: (_) async => webOpened = true,
    );
    expect(await launcher.openLocation('서울역'), isTrue);
    expect(webOpened, isFalse);
  });

  test('a native failure result reports failure', () async {
    answer(() => 'failed');
    final launcher = MapLauncher(channel: channel, openUrl: (_) async => true);
    expect(await launcher.openLocation('서울역'), isFalse);
  });

  test('a desktop choice opens the matching web map', () async {
    final opened = <Uri>[];
    answer(() => 'naver');
    final launcher = MapLauncher(
      channel: channel,
      openUrl: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    expect(await launcher.openLocation('서울역'), isTrue);
    expect(opened.single.host, 'map.naver.com');
  });

  test('a web map that cannot be opened reports failure', () async {
    answer(() => 'kakao');
    final launcher = MapLauncher(channel: channel, openUrl: (_) async => false);
    expect(await launcher.openLocation('서울역'), isFalse);
  });

  test(
    'a launch error retries the default map, then reports failure',
    () async {
      var attempts = 0;
      answer(() => 'naver');
      final launcher = MapLauncher(
        channel: channel,
        openUrl: (_) async {
          attempts++;
          throw PlatformException(code: 'open_error');
        },
      );
      expect(await launcher.openLocation('서울역'), isFalse);
      expect(attempts, 2);
    },
  );

  test('a native channel error falls back to the web map', () async {
    final opened = <Uri>[];
    answer(() => throw PlatformException(code: 'boom'));
    final launcher = MapLauncher(
      channel: channel,
      openUrl: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    expect(await launcher.openLocation('서울역'), isTrue);
    expect(opened, hasLength(1));
  });

  test('an unexpected error reports failure instead of escaping', () async {
    answer(() => 'apple');
    final launcher = MapLauncher(
      channel: channel,
      openUrl: (_) async => throw StateError('no browser'),
    );
    expect(await launcher.openLocation('서울역'), isFalse);
  });
}
