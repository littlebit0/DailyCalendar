import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Public undergraduate calendar for Chonnam's Gwangju/Yeosu campuses.
class ChonnamAcademicSource implements AcademicSource {
  ChonnamAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'jnu';
  @override
  String get name => '전남대학교';
  @override
  Uri get website =>
      Uri.https('events.jnu.ac.kr', '/Schedule.aspx', {'mode': '1'});

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Each annual page lists only rows starting that year, so a December
    // period running into January appears only on the previous year's page.
    // Those rows keep the previous year's IDs, matching that year's import.
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(queryParameters: {'mode': '1', 'YY': '$selected'}),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final table = RegExp(
      r'<table\b[^>]*\bid=["\x27]ContentPlaceHolder1_SubContentPlaceHolder1_gvList["\x27][^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body)?.group(1);
    if (table == null) {
      throw const FormatException('Missing Chonnam academic table');
    }
    final records = <AcademicCalendarRecord>[];
    for (final row in RegExp(
      r'<tr\b[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(table)) {
      final cells =
          RegExp(r'<td\b[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true)
              .allMatches(row.group(1)!)
              .map((match) => academicHtmlText(match.group(1)!))
              .toList();
      if (cells.isEmpty) continue; // Column headings use th.
      if (cells.length != 2 || cells[1].isEmpty) {
        throw const FormatException('Incomplete Chonnam academic record');
      }
      final dates = RegExp(
        r'(\d{4})[.-](\d{2})[.-](\d{2})',
      ).allMatches(cells[0]).toList();
      if (dates.length != 2) {
        throw const FormatException('Invalid academic date range');
      }
      DateTime date(RegExpMatch match) {
        final y = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final d = int.parse(match.group(3)!);
        final result = DateTime(y, m, d);
        if (y < 1900 ||
            result.year != y ||
            result.month != m ||
            result.day != d) {
          throw const FormatException('Invalid academic date');
        }
        return result;
      }

      records.add((
        title: cells[1],
        start: date(dates[0]),
        last: date(dates[1]),
      ));
    }
    // The official feed repeats the entrance ceremony; the helper keeps one.
    return academicCalendarEvents(
      records,
      year,
      Uri.https('events.jnu.ac.kr', '/Schedule.aspx', {
        'mode': '1',
        'YY': '$year',
      }).toString(),
    );
  }

  @override
  void close() => _client.close();
}
