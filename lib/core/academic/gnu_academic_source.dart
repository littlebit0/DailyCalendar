import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class GnuAcademicSource implements AcademicSource {
  GnuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'gnu';
  @override
  String get name => '경상국립대학교';
  @override
  Uri get website => Uri.https(
    'www.gnu.ac.kr',
    '/main/ps/schdul/selectSchdulMainList.do',
    {'mi': '1084'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          Uri.https('www.gnu.ac.kr', '/main/ps/schdul/selectSchdulList.do', {
            'mi': '1084',
          }),
          body: {
            'schdulLevel': 'Y',
            'srchYear': '$year',
            'schType': 'ND',
            'menuId': '1084',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('GNU calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! String) {
      throw const FormatException('Invalid GNU calendar response');
    }
    final document = html.parse(decoded);
    final months = <int>{};
    for (final header in document.querySelectorAll('.tbl_tbody_year th')) {
      final match = RegExp(
        r'^(\d{4})년\s*(\d{1,2})월$',
      ).firstMatch(header.text.trim());
      if (match == null) {
        throw const FormatException('Invalid GNU year coverage');
      }
      if (int.parse(match[1]!) == year) {
        months.add(int.parse(match[2]!));
      }
    }
    if (months.length != 12 || months.any((m) => m < 1 || m > 12)) {
      throw const FormatException('Unexpected GNU calendar year');
    }
    final events = <String, AcademicEvent>{};
    for (final link in document.querySelectorAll('.tbl_tbody_year td > a')) {
      final title = link.text.trim();
      final match = RegExp(
        r"^javascript:viewSchdulInfo\('(\d+)', '(\d{4}/\d{2}/\d{2})', '(\d{4}/\d{2}/\d{2})', '#[0-9A-Fa-f]{6}'\);$",
      ).firstMatch(link.attributes['href'] ?? '');
      if (match == null || title.isEmpty) {
        throw const FormatException('Invalid GNU event identity or dates');
      }
      DateTime date(String raw) {
        final parts = raw.split('/').map(int.parse).toList();
        final result = DateTime(parts[0], parts[1], parts[2]);
        if (result.year != parts[0] ||
            result.month != parts[1] ||
            result.day != parts[2]) {
          throw const FormatException('Invalid GNU date');
        }
        return result;
      }

      final start = date(match[2]!);
      final last = date(match[3]!);
      if (last.isBefore(start)) {
        throw const FormatException('Invalid GNU period');
      }
      // 학칙 제35조제4항·학ㆍ석사학위 및 학ㆍ석ㆍ박사학위통합 연계과정 운영규정
      // 제4조(모집)에 따른 연계과정 모집 행은 대학원 행이어도 포함하고, 그 밖의
      // [대학원] 행(논문·학위수여 등 별도 대학원 과정)은 제외한다.
      final graduateLinked =
          title.startsWith('[대학원]') && title.contains('연계과정 모집');
      if (title.startsWith('[대학원]') && !graduateLinked) {
        continue;
      }
      if (!graduateLinked && !title.startsWith('[학부]')) {
        throw const FormatException('Unknown GNU programme');
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      final event = AcademicEvent(
        sourceId: match[1]!,
        title: graduateLinked
            ? title.substring(5).trim().replaceAll(RegExp(r'\s+'), ' ')
            : title.substring(4).trim(),
        start: start,
        end: end,
        url:
            'https://www.gnu.ac.kr/main/ps/schdul/selectSchdulMainList.do?mi=1084&srchYear=$year',
      );
      final previous = events[event.sourceId];
      if (previous != null &&
          jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
        throw const FormatException('Conflicting GNU event');
      }
      events[event.sourceId] = event;
    }
    if (events.isEmpty) {
      throw const FormatException('No GNU undergraduate calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
