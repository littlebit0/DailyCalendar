import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class KaistAcademicSource implements AcademicSource {
  KaistAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kaist';
  @override
  String get name => '한국과학기술원';
  @override
  Uri get website => Uri.https('www.kaist.ac.kr', '/kr/html/edu/03110101.html');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .post(
            website,
            body: {
              'groups': 'university',
              'year': '$selectedYear',
              'month': '',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('KAIST calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), selectedYear).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty KAIST calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('#calTitle')?.text.trim() != '$year 학사일정') {
      throw const FormatException('Unexpected KAIST year');
    }
    final events = <AcademicEvent>[];
    final occurrences = <String, int>{};
    final published = <String>{};
    final months = <int>{};
    for (final table in document.querySelectorAll('table.schedule_table')) {
      final section = table.parent?.parent?.parent;
      final monthText =
          section?.querySelector('.calendar_month')?.text.trim() ?? '';
      final match = RegExp(r'^(\d{2})월$').firstMatch(monthText);
      if (match == null) {
        throw const FormatException('Missing KAIST calendar month');
      }
      final month = int.parse(match[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid KAIST month coverage');
      }
      for (final row in table.querySelectorAll('tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) {
          throw const FormatException('Invalid KAIST row');
        }
        final range = cells[0].text.trim().split('~');
        final title = cells[1].text.trim();
        if (range.isEmpty || range.length > 2 || title.isEmpty) {
          throw const FormatException('Invalid KAIST event');
        }
        DateTime date(String value, int selectedYear) {
          final match = RegExp(
            r'^\s*(\d{2})-(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(value);
          if (match == null) {
            throw const FormatException('Invalid KAIST date');
          }
          final m = int.parse(match[1]!);
          final d = int.parse(match[2]!);
          final result = DateTime(selectedYear, m, d);
          if (result.year != selectedYear ||
              result.month != m ||
              result.day != d) {
            throw const FormatException('Invalid KAIST date');
          }
          return result;
        }

        final start = date(range.first, year);
        var last = date(range.last, year);
        if (last.month < start.month) {
          last = date(range.last, year + 1);
        }
        if (start.month != month || last.isBefore(start)) {
          throw const FormatException('Unexpected KAIST period');
        }
        final key = '$year:$title';
        final occurrence = occurrences.update(
          key,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        // The same title and period listed twice is one event. The occurrence
        // number above is still consumed so later IDs stay as they were.
        if (!published.add('$title|$start|$last')) continue;
        events.add(
          AcademicEvent(
            sourceId: '$key:$occurrence',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.kaist.ac.kr/kr/html/edu/03110101.html?year=$year&groups=university',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete KAIST annual calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
