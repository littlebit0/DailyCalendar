import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The mobile report omits identities used by the desktop progress parser.
/// Request only this verified read-only report in its desktop representation;
/// keep the user's login view, cookie store and all other requests unchanged.
class LmsLearningReportClient {
  LmsLearningReportClient({HttpClient Function()? createClient})
    : _createClient = createClient ?? HttpClient.new;

  final HttpClient Function() _createClient;

  Future<Map<String, dynamic>> read(
    Uri uri,
    List<Map<String, dynamic>> cookies,
  ) async {
    if (uri.scheme != 'https' ||
        uri.host != 'ecampus.smu.ac.kr' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path != '/report/ubcompletion/user_progress.php' ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['id']?.length != 1 ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(uri.queryParameters['id'] ?? '')) {
      return {'status': 'invalid'};
    }
    final client = _createClient();
    try {
      return await _read(
        client,
        uri,
        cookies,
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      // No URL, cookies, headers, response text or native exception is logged.
      return {'status': 'network'};
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _read(
    HttpClient client,
    Uri uri,
    List<Map<String, dynamic>> cookies,
  ) async {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15',
    );
    for (final cookie in cookies) {
      final name = cookie['name'];
      final value = cookie['value'];
      if (name is String &&
          value is String &&
          (name == 'MoodleSession' || name.startsWith('MoodleSession_'))) {
        request.cookies.add(Cookie(name, value));
      }
    }
    if (request.cookies.isEmpty) {
      return {'status': 'auth', 'reason': 'unauthorized'};
    }
    final response = await request.close();
    if (response.statusCode >= 300 && response.statusCode < 400) {
      return {'status': 'auth', 'reason': 'redirect'};
    }
    if (response.statusCode == 401) {
      return {'status': 'auth', 'reason': 'unauthorized'};
    }
    if (response.statusCode == 403) return {'status': 'invalid'};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {'status': 'network'};
    }
    if (response.headers.contentType?.mimeType != 'text/html' ||
        response.contentLength > 4000000) {
      return {'status': 'invalid'};
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > 4000000) return {'status': 'invalid'};
      bytes.addAll(chunk);
    }
    // Preserve server rotation in the dedicated WebView store only after the
    // caller verifies the HTML's current principal and generation.
    final rotated = <Map<String, dynamic>>[];
    for (final cookie in response.cookies) {
      if (cookie.name != 'MoodleSession' &&
          !cookie.name.startsWith('MoodleSession_')) {
        continue;
      }
      final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');
      if (domain != null && domain != uri.host && domain != 'smu.ac.kr') {
        return {'status': 'invalid'};
      }
      if (cookie.path != null && cookie.path != '/') {
        return {'status': 'invalid'};
      }
      if (cookie.maxAge != null && cookie.maxAge! <= 0 ||
          cookie.expires?.isBefore(DateTime.now().toUtc()) == true) {
        return {'status': 'auth', 'reason': 'unauthorized'};
      }
      final expires =
          cookie.expires ??
          (cookie.maxAge == null
              ? null
              : DateTime.now().toUtc().add(Duration(seconds: cookie.maxAge!)));
      rotated.add({
        'name': cookie.name,
        'value': cookie.value,
        if (expires != null) 'expires': expires.millisecondsSinceEpoch,
      });
    }
    return {
      'status': 'ok',
      'url': uri.toString(),
      'html': utf8.decode(bytes),
      if (rotated.isNotEmpty) 'rotatedCookies': rotated,
    };
  }
}
