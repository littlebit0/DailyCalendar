import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class JejuAcademicSource implements AcademicSource {
  JejuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'jeju';
  @override
  String get name => '제주대학교';
  @override
  Uri get website => Uri.https(
    'www.jejunu.ac.kr',
    '/admission/eduguide/degree/academyschedule/academic.htm',
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .get(website.replace(queryParameters: {'year': '$selectedYear'}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Jeju calendar unavailable');
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
      throw const FormatException('Empty Jeju calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('.this-year > span')?.text.trim() !=
        '$year 년도') {
      throw const FormatException('Unexpected Jeju calendar year');
    }
    final months = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final section in document.querySelectorAll(
      '.academic-contents .month-wrap',
    )) {
      final month = int.tryParse(
        section.querySelector('h3 strong')?.text.trim() ?? '',
      );
      if (month == null || month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Jeju month coverage');
      }
      for (final row in section.querySelectorAll('li')) {
        final title = row.querySelector('span')?.text.trim() ?? '';
        final range = (row.querySelector('strong')?.text.trim() ?? '').split(
          '~',
        );
        if (title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid Jeju event');
        }
        DateTime date(String text, int dateYear) {
          final match = RegExp(
            r'^\s*(\d{2})\.\s*(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(text);
          if (match == null) throw const FormatException('Invalid Jeju date');
          final m = int.parse(match[1]!);
          final d = int.parse(match[2]!);
          final result = DateTime(dateYear, m, d);
          if (result.year != dateYear || result.month != m || result.day != d) {
            throw const FormatException('Invalid Jeju date');
          }
          return result;
        }

        final start = date(range.first, year);
        var last = date(range.last, year);
        if (last.month < start.month) {
          last = date(range.last, year + 1);
        }
        // The university lists summer classes under July although they begin
        // in late June. Validate overlap with the displayed month instead.
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            last.isBefore(DateTime(year, month))) {
          throw const FormatException('Invalid Jeju period');
        }
        if (title.startsWith('(대학원)')) {
          continue;
        }
        final occurrence = occurrences.update(
          title,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        events.add(
          AcademicEvent(
            sourceId: '$year:$title:$occurrence',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.jejunu.ac.kr/admission/eduguide/degree/academyschedule/academic.htm?year=$year',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Jeju calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
