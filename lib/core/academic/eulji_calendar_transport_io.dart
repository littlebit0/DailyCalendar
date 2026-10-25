import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

const _maxBodyBytes = 8000000;
const _maxHeaderBytes = 65536;

/// Compatibility for the school's one invalid, non-framing response header.
/// Certificate checks, all other header checks and body framing stay strict.
Future<http.Response> fetchEuljiCalendar(
  Uri uri, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  if (timeout <= Duration.zero ||
      timeout > const Duration(seconds: 25) ||
      uri.queryParametersAll.values.any((v) => v.length != 1) ||
      uri.scheme != 'https' ||
      uri.host != 'eulji.ac.kr' ||
      uri.port != 443 ||
      uri.path != '/renewal/index.html' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.queryParameters['menuno'] != '8069' ||
      uri.queryParameters['calendar_no'] != '105' ||
      !RegExp(r'^\d{4}$').hasMatch(uri.queryParameters['year'] ?? '') ||
      !RegExp(
        r'^(?:[0-9]|1[01])$',
      ).hasMatch(uri.queryParameters['month'] ?? '') ||
      uri.queryParameters.length != 4) {
    throw const FormatException('Unexpected Eulji calendar address');
  }
  SecureSocket? socket;
  var cancelled = false;
  try {
    return await (() async {
      final connected = await SecureSocket.connect(
        uri.host,
        443,
        timeout: const Duration(seconds: 10),
      );
      if (cancelled) {
        connected.destroy();
        throw TimeoutException('Eulji calendar request timed out');
      }
      socket = connected;
      connected.write(
        'GET ${uri.path}?${uri.query} HTTP/1.0\r\n'
        'Host: eulji.ac.kr\r\nUser-Agent: Mozilla/5.0\r\n'
        'Accept: text/html\r\nAccept-Encoding: identity\r\n'
        'Connection: close\r\n\r\n',
      );
      await connected.flush();
      final bytes = BytesBuilder(copy: false);
      await for (final part in connected) {
        if (bytes.length + part.length > _maxBodyBytes + _maxHeaderBytes) {
          throw const FormatException('Eulji calendar response too large');
        }
        bytes.add(part);
      }
      return decodeEuljiCalendarResponse(bytes.takeBytes(), uri);
    })().timeout(timeout);
  } finally {
    cancelled = true;
    socket?.destroy();
  }
}

http.Response decodeEuljiCalendarResponse(List<int> bytes, Uri uri) {
  if (bytes.length > _maxBodyBytes + _maxHeaderBytes) {
    throw const FormatException('Eulji calendar response too large');
  }
  var boundary = -1;
  for (var i = 0; i + 3 < bytes.length && i < _maxHeaderBytes; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      boundary = i;
      break;
    }
  }
  if (boundary < 0) {
    throw const FormatException('Invalid Eulji response headers');
  }
  final lines = latin1.decode(bytes.sublist(0, boundary)).split('\r\n');
  if (!RegExp(r'^HTTP/1\.[01] 200(?: |$)').hasMatch(lines.first)) {
    throw const FormatException('Eulji calendar unavailable');
  }
  final headers = <String, String>{};
  final fieldName = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
  for (final line in lines.skip(1)) {
    // School typo verified in actual public HTTP responses. It is unrelated
    // to authentication, transport framing or content and is never trusted.
    if (line == 'Referrer Policy: strict-orgin-when-cross-origin') {
      continue;
    }
    final colon = line.indexOf(':');
    if (colon <= 0 || !fieldName.hasMatch(line.substring(0, colon))) {
      throw const FormatException('Invalid Eulji response header');
    }
    final name = line.substring(0, colon).toLowerCase();
    final value = line.substring(colon + 1).trim();
    if (value.codeUnits.any((c) => c < 32 && c != 9 || c == 127)) {
      throw const FormatException('Invalid Eulji response header value');
    }
    if (headers.containsKey(name) && name != 'set-cookie') {
      throw const FormatException('Duplicate Eulji response header');
    }
    if (name != 'set-cookie') headers[name] = value;
  }
  var body = bytes.sublist(boundary + 4);
  final transfer = headers['transfer-encoding']?.toLowerCase();
  if (transfer != null) {
    if (transfer != 'chunked' || headers.containsKey('content-length')) {
      throw const FormatException('Unsupported Eulji response framing');
    }
    body = chunkedCoding.decode(body);
  } else if (headers.containsKey('content-length')) {
    final length = int.tryParse(headers['content-length']!);
    if (length == null || length != body.length) {
      throw const FormatException('Truncated Eulji response');
    }
  }
  final encoding = headers['content-encoding']?.toLowerCase();
  if (encoding != null && encoding != 'identity') {
    throw const FormatException('Unsupported Eulji content encoding');
  }
  if (body.length > _maxBodyBytes ||
      !RegExp(
        r'^text/html(?:;|$)',
      ).hasMatch((headers['content-type'] ?? '').toLowerCase())) {
    throw const FormatException('Invalid Eulji calendar body');
  }
  return http.Response.bytes(
    body,
    200,
    headers: headers,
    request: http.Request('GET', uri),
  );
}
