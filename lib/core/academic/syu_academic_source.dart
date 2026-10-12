import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class SyuAcademicSource implements AcademicSource {
  SyuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'syu';
  @override
  String get name => '삼육대학교';
  @override
  Uri get website => Uri.https('www.syu.ac.kr', '/academic/major-schedule/');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .get(website.replace(queryParameters: {'c': '$selectedYear'}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('SYU calendar unavailable');
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
      throw const FormatException('Empty SYU calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    final months = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    // Exclude the separate current-month summary, which repeats annual rows.
    for (final section in document.querySelectorAll(
      '.md_textcalendar_rowbx > .md_textcalendar',
    )) {
      final year = int.tryParse(
        section.querySelector('dl > dt .year')?.text.trim() ?? '',
      );
      final month = int.tryParse(
        section.querySelector('dl > dt .month')?.text.trim() ?? '',
      );
      if (month == null ||
          month < 1 ||
          month > 12 ||
          !months.add(month) ||
          year != (month < 3 ? academicYear + 1 : academicYear)) {
        throw const FormatException('Unexpected SYU academic year or month');
      }
      for (final row in section.querySelectorAll(
        '.md_cal_date_lsbx > ul > li > dl',
      )) {
        final title = row.querySelector('dd')?.text.trim() ?? '';
        final range = (row.querySelector('dt')?.text.trim() ?? '').split('~');
        if (title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid SYU event');
        }
        DateTime date(String value, int dateYear) {
          final match = RegExp(r'^\s*(\d{2})\.(\d{2})\s*$').firstMatch(value);
          if (match == null) {
            throw const FormatException('Invalid SYU date');
          }
          final m = int.parse(match[1]!);
          final d = int.parse(match[2]!);
          final result = DateTime(dateYear, m, d);
          if (result.year != dateYear || result.month != m || result.day != d) {
            throw const FormatException('Invalid SYU date');
          }
          return result;
        }

        final start = date(range.first, year!);
        var last = date(range.last, year);
        if (last.month < start.month) {
          last = date(range.last, year + 1);
        }
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            last.isBefore(DateTime(year, month))) {
          throw const FormatException('Invalid SYU period');
        }
        final occurrence = occurrences.update(
          title,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        events.add(
          AcademicEvent(
            sourceId: '$academicYear:$title:$occurrence',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.syu.ac.kr/academic/major-schedule/?c=$academicYear',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete SYU calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
