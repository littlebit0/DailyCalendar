import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class LockScreenWallpaperService {
  static const channel = MethodChannel('daily/wallpaper');

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> openSettings() async {
    if (!isSupportedPlatform) return;
    await channel.invokeMethod<void>('openSettings');
  }

  static Future<void> reset() async {
    if (!isSupportedPlatform) return;
    try {
      await channel.invokeMethod<void>('reset');
    } on MissingPluginException {
      // Older host/test engines do not contain wallpaper data.
    }
  }
}
