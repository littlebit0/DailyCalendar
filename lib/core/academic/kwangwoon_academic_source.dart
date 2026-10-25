import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class KwangwoonAcademicSource implements AcademicSource {
  KwangwoonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kwangwoon';
  @override
  String get name => '광운대학교';
  @override
  Uri get website =>
      Uri.https('www.kw.ac.kr', '/ko/life/bachelor_calendar.jsp');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .post(
            Uri.https('www.kw.ac.kr', '/KWBoard/list5_detail.jsp'),
            headers: {
              'Referer': website.toString(),
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
            body: {'sy': '$selectedYear', 'sm': ''},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Kwangwoon calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          final previous = events[event.sourceId];
          if (previous != null &&
              jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
            throw const FormatException('Conflicting Kwangwoon calendar event');
          }
          events[event.sourceId] = event;
        }
      }
      if (selectedYear != year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (events.isEmpty) throw const FormatException('Empty Kwangwoon calendar');
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    final annual = document.querySelector('.schedule-this-year');
    if (annual?.querySelector('h3')?.text.trim() != '$year CALENDAR') {
      throw const FormatException('Unexpected Kwangwoon calendar year');
    }
    // The annual view omits months with no published events. The separate
    // current-month list is deliberately excluded to avoid duplicate imports.
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in annual!.querySelectorAll('.month_box')) {
      final month = int.tryParse(
        section.querySelector('.month span')?.text.trim() ?? '',
      );
      if (month == null || month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Kwangwoon month coverage');
      }
      for (final row in section.querySelectorAll('.list li')) {
        final title = row.querySelector('p')?.text.trim() ?? '';
        final range = row.querySelector('strong')?.text.trim().split('~');
        if (title.isEmpty ||
            range == null ||
            range.isEmpty ||
            range.length > 2) {
          throw const FormatException('Invalid Kwangwoon calendar row');
        }
        DateTime date(String text, int dateYear) {
          final match = RegExp(
            r'^\s*(\d{2})\.(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(text);
          if (match == null) {
            throw const FormatException('Invalid Kwangwoon date');
          }
          final mm = int.parse(match[1]!);
          final dd = int.parse(match[2]!);
          final result = DateTime(dateYear, mm, dd);
          if (result.year != dateYear ||
              result.month != mm ||
              result.day != dd) {
            throw const FormatException('Invalid Kwangwoon date');
          }
          return result;
        }

        final start = date(range.first, year);
        var last = date(range.last, year);
        if (last.month < start.month) last = date(range.last, year + 1);
        if (last.isBefore(start) || start.month != month) {
          throw const FormatException('Invalid Kwangwoon calendar period');
        }
        final identity = '${start.toIso8601String()}:$title';
        if (events.containsKey(identity)) {
          throw const FormatException('Duplicate Kwangwoon calendar event');
        }
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: 'https://www.kw.ac.kr/ko/life/bachelor_calendar.jsp',
        );
      }
    }
    if (months.isEmpty || events.isEmpty) {
      throw const FormatException('Empty Kwangwoon annual calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
