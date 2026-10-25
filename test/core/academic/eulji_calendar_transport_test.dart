import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/eulji_calendar_transport_io.dart';

void main() {
  final uri = Uri.parse(
    'https://eulji.ac.kr/renewal/index.html?menuno=8069&calendar_no=105&year=2026&month=0',
  );
  List<int> response(
    String headers,
    String body, {
    String status = '200 OK',
  }) => utf8.encode(
    'HTTP/1.1 $status\r\nContent-Type: text/html; charset=utf-8\r\n$headers\r\n$body',
  );

  test('only the observed metadata typo is ignored, Unicode body preserved', () {
    final result = decodeEuljiCalendarResponse(
      response(
        'Referrer Policy: strict-orgin-when-cross-origin\r\nConnection: close\r\n',
        '학사일정',
      ),
      uri,
    );
    expect(result.body, '학사일정');
    expect(result.headers.containsKey('referrer policy'), isFalse);
  });
  test('other malformed names and changed typo values are rejected', () {
    for (final header in ['Bad Header: value', 'Referrer Policy: other']) {
      expect(
        () => decodeEuljiCalendarResponse(response('$header\r\n', 'body'), uri),
        throwsFormatException,
      );
    }
  });
  test('redirects, compressed bodies and ambiguous framing are rejected', () {
    expect(
      () => decodeEuljiCalendarResponse(
        response('', '', status: '302 Found'),
        uri,
      ),
      throwsFormatException,
    );
    for (final header in [
      'Content-Encoding: gzip',
      'Transfer-Encoding: chunked\r\nContent-Length: 4',
      'Content-Length: 3',
    ]) {
      expect(
        () => decodeEuljiCalendarResponse(response('$header\r\n', 'body'), uri),
        throwsFormatException,
      );
    }
  });
  test('standard chunked codec validates chunks and truncation', () {
    expect(
      decodeEuljiCalendarResponse(
        response('Transfer-Encoding: chunked\r\n', '4\r\nbody\r\n0\r\n\r\n'),
        uri,
      ).body,
      'body',
    );
    expect(
      () => decodeEuljiCalendarResponse(
        response('Transfer-Encoding: chunked\r\n', '4\r\nbod'),
        uri,
      ),
      throwsFormatException,
    );
  });
  test('duplicate framing and control characters are rejected', () {
    for (final header in [
      'Content-Length: 4\r\ncontent-length: 4',
      'X-Test: bad\u0000value',
    ]) {
      expect(
        () => decodeEuljiCalendarResponse(response('$header\r\n', 'body'), uri),
        throwsFormatException,
      );
    }
  });
  test('8MB body and 64KB header limits stay enforced', () {
    expect(
      () => decodeEuljiCalendarResponse(response('', 'a' * 8000001), uri),
      throwsFormatException,
    );
    expect(
      () => decodeEuljiCalendarResponse(
        response('X-Test: ${'a' * 65536}\r\n', 'body'),
        uri,
      ),
      throwsFormatException,
    );
  });
  test(
    'transport cannot be used for another address or login endpoint',
    () async {
      for (final other in [
        Uri.parse('https://example.com'),
        uri.replace(path: '/login'),
        uri.replace(scheme: 'http'),
      ]) {
        await expectLater(fetchEuljiCalendar(other), throwsFormatException);
      }
    },
  );
}
