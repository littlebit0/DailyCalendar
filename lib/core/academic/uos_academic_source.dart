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
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('#year_code')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected UOS calendar year');
    }
    DateTime date(int y, String m, String d) {
      final month = int.parse(m), day = int.parse(d);
      final value = DateTime(y, month, day);
      if (value.month != month || value.day != day) {
        throw const FormatException('Invalid UOS calendar date');
      }
      return value;
    }

    String day(DateTime d) => d.toIso8601String().substring(0, 10);
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final row in document.querySelectorAll('tr[id]')) {
      final match = RegExp('^m$year(\\d{2})c\\d+\$').firstMatch(row.id);
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
      // Rows show "[MM-DD ~ MM-DD]" under their year/month heading.
      final period = RegExp(
        r'^\[(\d{2})-(\d{2})\s*~\s*(\d{2})-(\d{2})\]$',
      ).firstMatch(row.querySelector('.date02')?.text.trim() ?? '');
      if (title == null || title.isEmpty || period == null) {
        throw const FormatException('Missing UOS calendar event detail');
      }
      // A January row may start in December; a December row may end in January.
      final startMonth = int.parse(period[1]!);
      final start = date(
        startMonth > month ? year - 1 : year,
        period[1]!,
        period[2]!,
      );
      final last = date(
        int.parse(period[3]!) < startMonth ? start.year + 1 : start.year,
        period[3]!,
        period[4]!,
      );
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected UOS calendar period');
      }
      // Same start:last:title ID as earlier versions, so old imports carry over.
      final identity = '${day(start)}:${day(last)}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: end,
        url:
            'https://www.uos.ac.kr/korCalendarYear/list.do?list_id=CA1&menuid=2000003003001000000&identified=anonymous&year_code=$year',
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
