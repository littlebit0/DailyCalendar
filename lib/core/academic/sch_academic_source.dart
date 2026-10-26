import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// SCH's public annual calendar, including the previous year's winter overlap.
class SchAcademicSource implements AcademicSource {
  SchAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  String get id => 'sch';
  @override
  String get name => '순천향대학교';
  @override
  Uri get website => Uri.https('home.sch.ac.kr', '/sch/05/010000.jsp');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'board_no': '20110224223754285127',
                'defparam-year_month': '$selected-01',
              },
            ),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
              // This public JSP returns HTTP 500 without a request language.
              'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('SCH academic calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published SCH calendar');
    }
    return events.values.toList()..sort((a, b) {
      final order = a.start.compareTo(b.start);
      return order == 0 ? a.sourceId.compareTo(b.sourceId) : order;
    });
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    final calendar = document.querySelector('.schedule-board');
    if (calendar?.querySelector('.calendar .year h4')?.text.trim() != '$year') {
      throw const FormatException('Unexpected SCH calendar year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in calendar!.querySelectorAll('.info > .section')) {
      final monthClasses = section.classes.where((c) => c.startsWith('month_'));
      if (monthClasses.length != 1) {
        throw const FormatException('Invalid SCH calendar month');
      }
      final month = int.tryParse(monthClasses.single.substring(6));
      if (month == null || month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid SCH calendar month');
      }
      final entries = section.querySelectorAll('.list dl > dt, .list dl > dd');
      if (entries.length.isOdd) {
        throw const FormatException('Incomplete SCH calendar entry');
      }
      for (var index = 0; index < entries.length; index += 2) {
        if (entries[index].localName != 'dt' ||
            entries[index + 1].localName != 'dd') {
          throw const FormatException('Invalid SCH calendar entry order');
        }
        final title = entries[index + 1].text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final parts = entries[index].text.trim().split('~');
        if (title.isEmpty || parts.length > 2) {
          throw const FormatException('Invalid SCH calendar entry');
        }
        DateTime date(String text, int selectedYear) {
          final match = RegExp(
            r'^\s*(\d{2})\.(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(text);
          if (match == null) {
            throw const FormatException('Invalid SCH academic date');
          }
          final m = int.parse(match[1]!), day = int.parse(match[2]!);
          final value = DateTime(selectedYear, m, day);
          if (value.year != selectedYear ||
              value.month != m ||
              value.day != day) {
            throw const FormatException('Invalid SCH academic date');
          }
          // Published weekday labels can contain typos; numeric dates govern.
          return value;
        }

        final start = date(parts.first, year);
        var last = date(parts.last, year);
        if (last.month < start.month) last = date(parts.last, year + 1);
        if (start.month != month || last.isBefore(start)) {
          throw const FormatException('Unexpected SCH academic period');
        }
        final identity =
            '${start.toIso8601String()}:${last.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: Uri.https('home.sch.ac.kr', '/sch/05/010000.jsp', {
            'board_no': '20110224223754285127',
            'defparam-year_month': '$year-01',
          }).toString(),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete SCH annual calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
