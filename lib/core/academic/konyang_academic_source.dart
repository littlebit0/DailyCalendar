import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KonyangAcademicSource implements AcademicSource {
  KonyangAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'konyang';
  @override
  String get name => '건양대학교';
  @override
  Uri get website => Uri.https(
    'www.konyang.ac.kr',
    '/prog/schedule/kor/sub06_01_01_01/3/haksa.do',
  );

  /// Academic years run March to February, so [year] spans two pages.
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(queryParameters: {'rdate': '$selected-03-01'}),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 25));
      checkAcademicResponse(response);
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Konyang calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Parses the academic year starting in March of [selected].
  static List<AcademicEvent> parse(String body, int selected) {
    final document = html.parse(body);
    if (document
            .querySelector('#prev_schdule option[selected]')
            ?.attributes['value'] !=
        '$selected-03-01') {
      throw const FormatException('Unexpected Konyang year');
    }
    // The page repeats the calendar in a mobile table without row headings.
    final tables = document
        .querySelectorAll('table')
        .where((table) => table.querySelector('th[scope="row"]') != null)
        .toList();
    if (tables.length != 1) {
      throw const FormatException('Ambiguous Konyang calendar');
    }
    final url = _pageUrl(selected);
    final events = <String, AcademicEvent>{};
    final months = <int>{};
    var month = 0;
    for (final row in tables.single.querySelectorAll('tbody tr')) {
      final heading = row.querySelector('th[scope="row"]');
      if (heading != null) {
        final match = RegExp(r'^(\d{1,2})월$').firstMatch(heading.text.trim());
        if (match == null) {
          throw const FormatException('Invalid Konyang month');
        }
        month = int.parse(match[1]!);
        if (month < 1 || month > 12 || !months.add(month)) {
          throw const FormatException('Invalid Konyang month');
        }
      }
      final cells = row.querySelectorAll('td');
      if (month == 0 || cells.length != 2) {
        throw const FormatException('Invalid Konyang row');
      }
      final current = selected + (month < 3 ? 1 : 0);
      DateTime read(String text) {
        final match = RegExp(
          r'^(?:(\d{1,2})\.)?(\d{1,2})$',
        ).firstMatch(text.trim());
        if (match == null) throw const FormatException('Invalid Konyang date');
        final m = match[1] == null ? month : int.parse(match[1]!);
        final y = current + (m < month ? 1 : 0), d = int.parse(match[2]!);
        final value = DateTime(y, m, d);
        if (value.year != y || value.month != m || value.day != d) {
          throw const FormatException('Invalid Konyang date');
        }
        return value;
      }

      final parts = cells.first.text.trim().split('~');
      final title = cells.last.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (parts.length > 2 || title.isEmpty) {
        throw const FormatException('Invalid Konyang event');
      }
      final start = read(parts.first), last = read(parts.last);
      if (last.isBefore(start)) {
        throw const FormatException('Invalid Konyang range');
      }
      // Same ID format as earlier releases so imported events are kept.
      final sourceId = '${start.toIso8601String()}:$title';
      final event = AcademicEvent(
        sourceId: sourceId,
        title: title,
        start: start,
        end: DateTime(last.year, last.month, last.day + 1),
        url: url,
      );
      final previous = events[sourceId];
      if (previous != null && previous.end != event.end) {
        throw const FormatException('Conflicting Konyang events');
      }
      events[sourceId] = event;
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Konyang calendar');
    }
    return events.values.toList();
  }

  static String _pageUrl(int selected) => Uri.https(
    'www.konyang.ac.kr',
    '/prog/schedule/kor/sub06_01_01_01/3/haksa.do',
    {'rdate': '$selected-03-01'},
  ).toString();

  @override
  void close() => _client.close();
}
