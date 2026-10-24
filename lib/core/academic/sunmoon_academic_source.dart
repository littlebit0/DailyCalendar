import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class SunmoonAcademicSource implements AcademicSource {
  SunmoonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const _page =
      'https://communication.sunmoon.ac.kr/communication/sv/schdulView/schdulCalendarView.do?mi=40193';
  @override
  String get id => 'sunmoon';
  @override
  String get name => '선문대학교';
  @override
  Uri get website => Uri.https(
    'communication.sunmoon.ac.kr',
    '/communication/sv/schdulView/schdulCalendarView.do',
    {'mi': '40193'},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Academic years run March to February, so January/February of [year]
    // belong to the previous academic year's response.
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https(
              'communication.sunmoon.ac.kr',
              '/communication/sv/schdulView/calendar.do',
            ),
            body: {
              'year': '$selected',
              'monthFirst': '${selected}0301',
              'monthEnmt':
                  '${selected + 1}02${DateTime(selected + 1, 3, 0).day}',
              'sysId': 'communication',
              'section': '',
            },
          )
          .timeout(const Duration(seconds: 25));
      checkAcademicResponse(response);
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          _add(events, event);
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Sunmoon calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static void _add(Map<String, AcademicEvent> events, AcademicEvent event) {
    final previous = events[event.sourceId];
    if (previous != null &&
        jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
      throw const FormatException('Conflicting Sunmoon academic identity');
    }
    events[event.sourceId] = event;
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final doc = html.parse(body);
    if (doc.querySelector('h4[in-data]')?.attributes['in-data'] !=
        '$academicYear') {
      throw const FormatException('Unexpected Sunmoon academic year');
    }
    // The responsive `#schedule_month` mirror repeats every month with
    // literal null labels; only `#schedule_year` is the official calendar, so
    // parsing and month completeness are checked there alone.
    final official = doc.querySelector('#schedule_year');
    if (official == null) {
      throw const FormatException('Missing Sunmoon year calendar');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final table in official.querySelectorAll('table')) {
      final caption = table.querySelector('caption')?.text ?? '';
      if (!caption.contains('내용')) {
        continue;
      }
      final month = RegExp(r'(\d{1,2})월').firstMatch(caption);
      if (month == null) {
        throw const FormatException('Missing Sunmoon month');
      }
      months.add(int.parse(month[1]!));
      for (final row in table.querySelectorAll('tbody tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) {
          throw const FormatException('Invalid Sunmoon row');
        }
        final dates = RegExp(
          r'(\d{2})-(\d{2})',
        ).allMatches(cells[0].text).toList();
        if (dates.isEmpty || dates.length > 2) {
          throw const FormatException('Invalid Sunmoon dates');
        }
        DateTime date(RegExpMatch m) {
          final month = int.parse(m[1]!), day = int.parse(m[2]!);
          final year = month < 3 ? academicYear + 1 : academicYear;
          final value = DateTime(year, month, day);
          if (value.month != month || value.day != day) {
            throw const FormatException('Invalid Sunmoon date');
          }
          return value;
        }

        final start = date(dates.first);
        final last = date(dates.last);
        if (last.isBefore(start)) {
          throw const FormatException('Invalid Sunmoon range');
        }
        for (final item in cells[1].querySelectorAll('li')) {
          final label = item.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (label.isEmpty) throw const FormatException('Empty Sunmoon title');
          // Empty calendar slots render a literal null label.
          if (label == 'null') {
            continue;
          }
          // Multi-month periods and holidays repeat under each month table.
          _add(
            events,
            AcademicEvent(
              sourceId: '${start.toIso8601String()}:$label',
              title: label,
              start: start,
              end: DateTime(last.year, last.month, last.day + 1),
              url: _page,
            ),
          );
        }
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Sunmoon calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
