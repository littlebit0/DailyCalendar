import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an event location through the platform's native map chooser.
///
/// Mobile platforms handle installed map apps themselves. Desktop platforms
/// return the map selected in their native dialog so the default browser can
/// open the matching web map.
class MapLauncher {
  MapLauncher({MethodChannel? channel, Future<bool> Function(Uri uri)? openUrl})
    : _channel = channel ?? const MethodChannel(_channelName),
      _openUrl = openUrl ?? _launchExternally;

  static const _channelName = 'daily/map_launcher';

  final MethodChannel _channel;
  final Future<bool> Function(Uri uri) _openUrl;

  static Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Opens [location] in a map. Returns `false` when no map app or web map
  /// could be opened; cancelling the native chooser counts as handled.
  Future<bool> openLocation(String location) async {
    final query = location.trim();
    if (query.isEmpty) {
      return true;
    }

    try {
      final String? destination;
      try {
        destination = await _channel.invokeMethod<String>('openLocation', {
          'location': query,
        });
      } on MissingPluginException {
        return await _openInDefaultBrowser(_fallbackDestination, query);
      } on PlatformException {
        return await _openInDefaultBrowser(_fallbackDestination, query);
      }
      if (destination == null || destination == 'handled') {
        return true;
      }
      if (destination == 'failed') {
        return false;
      }
      try {
        return await _openInDefaultBrowser(destination, query);
      } on PlatformException {
        return await _openInDefaultBrowser(_fallbackDestination, query);
      }
    } on Object {
      return false;
    }
  }

  String get _fallbackDestination {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.windows:
        return 'kakao';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'apple';
    }
  }

  Future<bool> _openInDefaultBrowser(String destination, String query) {
    final encodedQuery = Uri.encodeComponent(query);
    final uri = switch (destination) {
      'kakao' => Uri.parse('https://map.kakao.com/link/search/$encodedQuery'),
      'naver' => Uri.parse('https://map.naver.com/p/search/$encodedQuery'),
      _ => Uri.parse('https://maps.apple.com/?q=$encodedQuery'),
    };
    return _openUrl(uri);
  }
}
