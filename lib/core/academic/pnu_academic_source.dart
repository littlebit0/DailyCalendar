import 'dart:convert';
import 'dart:math';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// The anonymous schedule popup on PNU's student support sign-in page.
class PnuAcademicSource implements AcademicSource {
  PnuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'pnu';
  @override
  String get name => '부산대학교';
  @override
  Uri get website => Uri.https('onestop.pusan.ac.kr', '/login');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final page = await _client
        .get(website)
        .timeout(const Duration(seconds: 20));
    if (page.statusCode != 200 || page.bodyBytes.length > 8000000) {
      throw const FormatException('PNU public calendar unavailable');
    }
    final body = utf8.decode(page.bodyBytes);
    String parameter(String pattern) {
      final match = RegExp(pattern).firstMatch(body);
      if (match == null) {
        throw const FormatException('Missing PNU public request parameter');
      }
      return match[1]!;
    }

    final modulus = BigInt.parse(
      parameter(r"RSAModulus = '([0-9a-fA-F]+)'"),
      radix: 16,
    );
    final exponent = BigInt.parse(
      parameter(r"RSAExponent = '([0-9a-fA-F]+)'"),
      radix: 16,
    );
    if (modulus.bitLength < 2048 ||
        modulus.bitLength > 4096 ||
        exponent != BigInt.from(65537)) {
      throw const FormatException('Unexpected PNU public key');
    }
    final token = parameter(r'scwin.token = "([a-zA-Z0-9-]+)"');
    final cookies = <String, String>{};
    void rememberCookies(http.Response response) {
      for (final part in (response.headers['set-cookie'] ?? '').split(
        RegExp(r',(?=\s*[^;,=]+=)'),
      )) {
        final pair = part.split(';').first.trim();
        final split = pair.indexOf('=');
        if (split > 0) {
          cookies[pair.substring(0, split)] = pair.substring(split + 1);
        }
      }
    }

    rememberCookies(page);
    Object? authorization;
    Future<String> request(String path, Map<String, Object?> data) async {
      final inner = jsonEncode({
        '_data': jsonEncode({...data, 'locale': '0001'}),
        'AUTH_STR': authorization,
      });
      // Published gfn_ajax_request splits UTF-8 text after 200 bytes. RSA is
      // public-key transport encoding here, never credential storage/signing.
      final chunks = <String>[];
      var chunk = <int>[];
      for (final rune in inner.runes) {
        chunk.addAll(utf8.encode(String.fromCharCode(rune)));
        if (chunk.length > 200) {
          chunks.add(_encode(chunk, modulus, exponent));
          chunk = <int>[];
        }
      }
      if (chunk.isNotEmpty) chunks.add(_encode(chunk, modulus, exponent));
      final response = await _client
          .post(
            website.replace(path: path),
            headers: {
              'content-type': 'application/json',
              'AJAX': 'true',
              'X-CSRF-TOKEN': token,
              'Referer': website.toString(),
              if (cookies.isNotEmpty)
                'Cookie': cookies.entries
                    .map((e) => '${e.key}=${e.value}')
                    .join('; '),
            },
            body: jsonEncode({'_data': chunks.join(',')}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('PNU public calendar request failed');
      }
      rememberCookies(response);
      return utf8.decode(response.bodyBytes);
    }

    final info = jsonDecode(
      await request('/global/info', {'menuCD': '000000000000000'}),
    );
    final menus = info is Map ? info['_Menu'] : null;
    if (menus is! List) {
      throw const FormatException('PNU anonymous menu unavailable');
    }
    final menu = menus
        .whereType<Map>()
        .where((m) => m['MENU_CD'] == '000000000000000')
        .toList();
    if (menu.length != 1 || menu.single['AUTH_STR'] == null) {
      throw const FormatException('PNU anonymous calendar menu unavailable');
    }
    authorization = menu.single['AUTH_STR'];
    final events = <String, AcademicEvent>{};
    // Next year's first term opens its leave-return windows in this autumn.
    for (final selection in [
      (year - 1, '0020', false),
      (year, '0010', false),
      (year, '0020', false),
      (year + 1, '0010', true),
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = await request('/core/main/selectScheduleListPop.do', {
        'SCH_SYEAR': '${selection.$1}',
        'SCH_TERM_GCD': selection.$2,
      });
      for (final event in parse(
        response,
        selection.$1,
        selection.$2,
        allowEmpty: selection.$3,
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published PNU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static String _encode(List<int> message, BigInt modulus, BigInt exponent) {
    final size = (modulus.bitLength + 7) ~/ 8;
    if (message.length > size - 11) {
      throw const FormatException('PNU request too long');
    }
    final random = Random.secure();
    final padding = List.generate(
      size - message.length - 3,
      (_) => random.nextInt(255) + 1,
    );
    var encoded = BigInt.zero;
    for (final value in [0, 2, ...padding, 0, ...message]) {
      encoded = (encoded << 8) | BigInt.from(value);
    }
    return encoded
        .modPow(exponent, modulus)
        .toRadixString(16)
        .padLeft(size * 2, '0');
  }

  /// [allowEmpty] accepts a term whose schedule is not yet published.
  static List<AcademicEvent> parse(
    String body,
    int year,
    String term, {
    bool allowEmpty = false,
  }) {
    if (!body.contains('\$("#SCH_SYEAR").val("$year")') ||
        !body.contains('\$("#SCH_TERM_GCD").val("$term")')) {
      throw const FormatException('Unexpected PNU selected term');
    }
    final document = html.parse(body);
    final rows = document.querySelectorAll('#resultTbody > tr');
    final total = int.tryParse(
      document.querySelector('.text-total')?.text.trim() ?? '',
    );
    if (total == null || total != rows.length || (total == 0 && !allowEmpty)) {
      throw const FormatException('Incomplete PNU calendar');
    }
    final events = <String, AcademicEvent>{};
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length != 3) throw const FormatException('Invalid PNU event');
      final text = cells[1].text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final dates = RegExp(
        r'(\d{4})-(\d{2})-(\d{2}) \([월화수목금토일]\) \d{2}:\d{2}',
      ).allMatches(text).toList();
      if (dates.length != 2) throw const FormatException('Invalid PNU dates');
      DateTime date(RegExpMatch match) {
        final y = int.parse(match[1]!),
            m = int.parse(match[2]!),
            d = int.parse(match[3]!);
        final value = DateTime(y, m, d);
        if (value.year != y || value.month != m || value.day != d) {
          throw const FormatException('Invalid PNU date');
        }
        return value;
      }

      final start = date(dates.first), last = date(dates.last);
      final title = cells[2].text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.isEmpty ||
          last.isBefore(start) ||
          start.year < year - 1 ||
          last.year > year + 1) {
        throw const FormatException('Invalid PNU period');
      }
      final identity =
          '${start.toIso8601String()}:${last.toIso8601String()}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: DateTime(last.year, last.month, last.day + 1),
        url: 'https://onestop.pusan.ac.kr/login',
      );
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
