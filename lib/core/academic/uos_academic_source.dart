import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class UosAcademicSource implements AcademicSource {
  UosAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'uos';
  @override
  String get name => '서울시립대학교';
  @override
  Uri get website => Uri.https('www.uos.ac.kr', '/korCalendarYear/list.do', {
    'list_id': 'CA1',
    'menuid': '2000003003001000000',
    'identified': 'anonymous',
  });
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final uri = website.replace(
      queryParameters: {...website.queryParameters, 'year_code': '$year'},
    );
    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('UOS calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('#year_code')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected UOS calendar year');
    }
    DateTime date(String value) {
      final p = value.split('-').map(int.parse).toList();
      final d = DateTime(p[0], p[1], p[2]);
      if (d.year != p[0] || d.month != p[1] || d.day != p[2]) {
        throw const FormatException('Invalid UOS calendar date');
      }
      return d;
    }

    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final row in document.querySelectorAll('tr[id]')) {
      final match = RegExp('^m$year(\\d{2})c(\\d+)\$').firstMatch(row.id);
      if (match == null) continue;
      final month = int.parse(match[1]!);
      if (month < 1 || month > 12) {
        throw const FormatException('Invalid UOS calendar month');
      }
      months.add(month);
      final title = row
          .querySelector('.title01')
          ?.text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final detail = document.getElementById('m$year${match[1]}cc${match[2]}');
      final dates = detail
          ?.querySelectorAll('li')
          .where((e) => e.text.trim().startsWith('일자'))
          .toList();
      if (title == null ||
          title.isEmpty ||
          dates == null ||
          dates.length != 1) {
        throw const FormatException('Missing UOS calendar event detail');
      }
      final period = RegExp(
        r'일자\s*:\s*(\d{4}-\d{2}-\d{2})\s*~\s*(\d{4}-\d{2}-\d{2})',
      ).firstMatch(dates.single.text);
      if (period == null) {
        throw const FormatException('Invalid UOS calendar period');
      }
      final start = date(period[1]!);
      final last = date(period[2]!);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected UOS calendar period');
      }
      final identity = '${period[1]}:${period[2]}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: end,
        url:
            'https://www.uos.ac.kr/korCalendarYear/list.do?list_id=CA1&menuid=2000003003001000000&identified=anonymous',
      );
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete UOS calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
