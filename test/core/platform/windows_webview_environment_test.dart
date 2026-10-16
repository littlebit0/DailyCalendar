import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview_windows/src/webview_environment/webview_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each environment disposes its own native channel, including failure',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const factory = MethodChannel(
        'com.pichillilorenzo/flutter_webview_environment',
      );
      final created = <String>[];
      final disposed = <String>[];
      messenger.setMockMethodCallHandler(factory, (call) async {
        expect(call.method, 'create');
        final id = (call.arguments as Map)['id'] as String;
        created.add(id);
        final channel = MethodChannel(
          'com.pichillilorenzo/flutter_webview_environment_$id',
        );
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'dispose');
          disposed.add(id);
          if (id == created.first && disposed.length == 1) {
            throw PlatformException(code: 'fixture-dispose');
          }
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(factory, null));
      final a = await WindowsWebViewEnvironment.static().create();
      final b = await WindowsWebViewEnvironment.static().create();
      expect(created.toSet().length, 2);
      await expectLater(a.dispose(), throwsA(isA<PlatformException>()));
      await a.dispose();
      await b.dispose();
      expect(disposed, [created.first, created.first, created.last]);
    },
  );
}
