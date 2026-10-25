import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class SsuAcademicSource implements AcademicSource {
  SsuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'ssu';
  @override
  String get name => '숭실대학교';
  @override
  Uri get website => Uri.https('ssu.ac.kr', '/학사/학사일정/');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .get(website.replace(queryParameters: {'years': '$selectedYear'}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('SSU calendar unavailable');
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
      throw const FormatException('Empty SSU calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('#calendar > h4')?.text.trim() != '$year년') {
      throw const FormatException('Unexpected SSU calendar year');
    }
    final months = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final section in document.querySelectorAll('#calendar > div[id]')) {
      final match = RegExp('^calendar$year(\\d{2})\$').firstMatch(section.id);
      final month = match == null ? null : int.tryParse(match[1]!);
      if (month == null || month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid SSU month coverage');
      }
      for (final row in section.querySelectorAll('ul.tb > li')) {
        final cells = row.querySelectorAll('div.row > div');
        if (cells.length != 2) {
          throw const FormatException('Invalid SSU event');
        }
        final title = cells.last.text.trim();
        final range = cells.first.text.trim().split('~');
        if (title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid SSU event');
        }
        DateTime date(String value, int dateYear) {
          final match = RegExp(
            r'^\s*(\d{2})\.(\d{2})\s*\([월화수목금토일]\)\s*$',
          ).firstMatch(value);
          if (match == null) {
            throw const FormatException('Invalid SSU date');
          }
          final m = int.parse(match[1]!);
          final d = int.parse(match[2]!);
          final result = DateTime(dateYear, m, d);
          if (result.year != dateYear || result.month != m || result.day != d) {
            throw const FormatException('Invalid SSU date');
          }
          return result;
        }

        final start = date(range.first, year);
        var last = date(range.last, year);
        if (last.month < start.month) {
          last = date(range.last, year + 1);
        }
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            last.isBefore(DateTime(year, month))) {
          throw const FormatException('Invalid SSU period');
        }
        // Graduate-only rows are labelled "대학원" in the title: "(대학원)"
        // suffix or "대학원 학위수여식"; they are not undergraduate schedules.
        if (title.contains('대학원')) {
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
            url: 'https://ssu.ac.kr/학사/학사일정/?years=$year',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete SSU calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
