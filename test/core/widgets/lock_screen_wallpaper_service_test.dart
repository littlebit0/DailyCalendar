import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/widgets/lock_screen_wallpaper_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = LockScreenWallpaperService.channel;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'iOS settings opens native guide, never runs or installs a shortcut',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      await LockScreenWallpaperService.openSettings();
      expect(calls.map((call) => call.method), ['openSettings']);
      expect(calls.single.arguments, isNull);
    },
  );

  for (final platform in TargetPlatform.values.where(
    (p) => p != TargetPlatform.iOS,
  )) {
    test('$platform does not invoke wallpaper methods', () async {
      debugDefaultTargetPlatformOverride = platform;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return null;
      });
      expect(LockScreenWallpaperService.isSupportedPlatform, isFalse);
      await LockScreenWallpaperService.openSettings();
      await LockScreenWallpaperService.reset();
      expect(calls, 0);
    });
  }

  test(
    'opening a missing native implementation is not reported as success',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await expectLater(
        LockScreenWallpaperService.openSettings(),
        throwsA(isA<MissingPluginException>()),
      );
      await LockScreenWallpaperService.reset();
    },
  );

  test(
    'native reset failure propagates instead of claiming data was cleared',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'wallpaper_reset');
      });
      await expectLater(
        LockScreenWallpaperService.reset(),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'local account reset clears wallpaper before changing calendar settings',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({'weekStartsOnMonday': true});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        expect(preferences.getBool('weekStartsOnMonday'), isTrue);
        return null;
      });
      await SettingsRepository(preferences: preferences).resetAll();
      expect(calls, ['reset']);
      expect(preferences.getBool('weekStartsOnMonday'), isNull);
    },
  );
}
