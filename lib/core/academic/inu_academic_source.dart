import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class InuAcademicSource implements AcademicSource {
  InuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'inu';
  @override
  String get name => '인천대학교';
  @override
  Uri get website => Uri.https('www.inu.ac.kr', '/inu/651/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .post(
            Uri.https('www.inu.ac.kr', '/schdulmanage/inu/10/yearSchdul.do'),
            headers: {
              'Referer': website.toString(),
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
            body: {'kind': '', 'year': '$selectedYear'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('INU calendar unavailable');
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
            throw const FormatException('Conflicting INU calendar event');
          }
          events[event.sourceId] = event;
        }
      }
      if (selectedYear != year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (events.isEmpty) throw const FormatException('Empty INU calendar');
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('input#year')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected INU calendar year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in document.querySelectorAll(
      '#timeTableList > ul > li',
    )) {
      final monthText = section.querySelector('.box-month')?.text.trim();
      final match = RegExp(r'^(\d{1,2})월$').firstMatch(monthText ?? '');
      final month = match == null ? null : int.parse(match[1]!);
      if (section.querySelector('.box-year')?.text.trim() != '$year' ||
          month == null ||
          month < 1 ||
          month > 12 ||
          !months.add(month)) {
        throw const FormatException('Invalid INU month coverage');
      }
      for (final row in section.querySelectorAll('.list-box')) {
        final title = row.querySelector('.list-content')?.text.trim() ?? '';
        final range = row.querySelector('.list-date')?.text.trim().split('~');
        if (title.isEmpty || range == null || range.length > 2) {
          throw const FormatException('Invalid INU calendar row');
        }
        DateTime date(String text, int dateYear) {
          final m = RegExp(
            r'^\s*(\d{2})[.-](\d{2})\s*\((Mon|Tue|Wed|Thu|Fri|Sat|Sun)\)\s*$',
          ).firstMatch(text);
          if (m == null) throw const FormatException('Invalid INU date');
          final mm = int.parse(m[1]!);
          final dd = int.parse(m[2]!);
          final result = DateTime(dateYear, mm, dd);
          if (result.year != dateYear ||
              result.month != mm ||
              result.day != dd) {
            throw const FormatException('Invalid INU date');
          }
          return result;
        }

        final start = date(range.first, year);
        var last = date(range.last, year);
        if (last.month < start.month) last = date(range.last, year + 1);
        if (last.isBefore(start) || start.month != month) {
          throw const FormatException('Invalid INU calendar period');
        }
        final identity = '${start.toIso8601String()}:$title';
        final event = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: 'https://www.inu.ac.kr/inu/651/subview.do',
        );
        if (events.containsKey(identity)) {
          throw const FormatException('Duplicate INU calendar event');
        }
        events[identity] = event;
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete INU calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
