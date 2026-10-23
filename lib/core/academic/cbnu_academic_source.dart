import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class CbnuAcademicSource implements AcademicSource {
  CbnuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'cbnu';
  @override
  String get name => '충북대학교';
  @override
  Uri get website => Uri.https(
    'www.cbnu.ac.kr',
    '/www/selectWebSchdulList.do',
    {'key': '455', 'schdulSeNo': '1', 'month': 'all'},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website.replace(
            queryParameters: {...website.queryParameters, 'currentY': '$year'},
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('CBNU calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('.years_current')?.text.trim() != '$year 학년도') {
      throw const FormatException('Unexpected CBNU year');
    }
    final events = <String, AcademicEvent>{};
    final months = <int>{};
    int? month;
    for (final row in document.querySelectorAll(
      '.schedule_content tbody > tr',
    )) {
      if (row.classes.contains('datenum')) {
        final match = RegExp(
          r'^(\d{1,2})월$',
        ).firstMatch(row.querySelector('th')?.text.trim() ?? '');
        month = match == null ? null : int.parse(match[1]!);
        if (month == null || month < 1 || month > 12 || !months.add(month)) {
          throw const FormatException('Invalid CBNU month');
        }
        continue;
      }
      final cells = row.querySelectorAll('td');
      if (month == null || cells.length != 2) {
        throw const FormatException('Invalid CBNU event');
      }
      final range = cells.first.text.trim().split('~');
      final title = cells.last.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.isEmpty || range.length > 2) {
        throw const FormatException('Invalid CBNU event');
      }
      DateTime date(String text, int y) {
        final match = RegExp(
          r'^\s*(\d{2})\.(\d{2})\.\([월화수목금토일]\)\s*$',
        ).firstMatch(text);
        if (match == null) throw const FormatException('Invalid CBNU date');
        final m = int.parse(match[1]!);
        final d = int.parse(match[2]!);
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid CBNU date');
        }
        return result;
      }

      var start = date(range.first, year);
      if (start.month > month) start = date(range.first, year - 1);
      var last = date(range.last, start.year);
      if (last.month < start.month) last = date(range.last, start.year + 1);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected CBNU calendar period');
      }
      final identity =
          '${start.toIso8601String()}:${last.toIso8601String()}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: end,
        url:
            'https://www.cbnu.ac.kr/www/selectWebSchdulList.do?key=455&schdulSeNo=1&month=all',
      );
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete CBNU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
