import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';
import 'eulji_calendar_transport_stub.dart'
    if (dart.library.io) 'eulji_calendar_transport_io.dart'
    as eulji_transport;

class EuljiAcademicSource implements AcademicSource {
  EuljiAcademicSource({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  @override
  String get id => 'eulji';
  @override
  String get name => '을지대학교';
  @override
  Uri get website => Uri.https('eulji.ac.kr', '/renewal/index.html', {
    'menuno': '8069',
    'calendar_no': '105',
  });
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    var compatibilityRequired = false;
    for (var month = 0; month < 12; month++) {
      if (month > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final uri = website.replace(
        queryParameters: {
          ...website.queryParameters,
          'year': '$year',
          'month': '$month',
        },
      );
      // The school sends one malformed metadata header ("Referrer Policy").
      // Retry only that known defect, once per fetch; other failures propagate.
      http.Response response;
      if (compatibilityRequired) {
        response = await eulji_transport.fetchEuljiCalendar(uri);
      } else {
        final clock = Stopwatch()..start();
        try {
          response = await client
              .get(
                uri,
                headers: {'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html'},
              )
              .timeout(const Duration(seconds: 25));
        } on http.ClientException catch (error) {
          if (!error.message.contains('Invalid header field name, with 32')) {
            rethrow;
          }
          final remaining = 25000 - clock.elapsedMilliseconds;
          if (remaining <= 0) {
            throw TimeoutException('Eulji calendar request timed out');
          }
          compatibilityRequired = true;
          response = await eulji_transport.fetchEuljiCalendar(
            uri,
            timeout: Duration(milliseconds: remaining),
          );
        }
      }
      checkAcademicResponse(response);
      events.addAll(parse(utf8.decode(response.bodyBytes), year, month + 1));
    }
    return _finish(events, year);
  }

  /// One month list; events spanning months are listed in each month they touch.
  static List<AcademicEvent> parse(String body, int year, int month) {
    final doc = html.parse(body);
    final heading = doc.querySelector('.years-month form');
    if (heading?.querySelector('strong')?.text.trim() != '$year년' ||
        heading?.querySelector('span')?.text.trim() != '$month월') {
      throw const FormatException('Unexpected Eulji calendar month');
    }
    final rows = <AcademicEvent>[];
    for (final row in doc.querySelectorAll('table.board-data tbody tr')) {
      final dateCell = row.querySelector('td.first');
      final title = row.querySelector('td.subject strong')?.text;
      if (dateCell == null) continue;
      final matches = RegExp(
        r'(\d{4})\.(\d{2})\.(\d{2})',
      ).allMatches(dateCell.text).toList();
      if (title == null || matches.isEmpty || matches.length > 2) {
        throw const FormatException('Invalid Eulji calendar event');
      }
      DateTime date(RegExpMatch m) =>
          _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      final start = date(matches.first);
      rows.add(
        _event(
          title,
          start,
          date(matches.last),
          Uri.https('eulji.ac.kr', '/renewal/index.html', {
            'menuno': '8069',
            'calendar_no': '105',
            'year': '${start.year}',
            'month': '${start.month - 1}',
          }),
        ),
      );
    }
    return rows;
  }

  @override
  void close() => client.close();
}

DateTime _date(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw const FormatException('Invalid published academic date');
  }
  return date;
}

AcademicEvent _event(String title, DateTime start, DateTime last, Uri url) {
  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) throw const FormatException('Empty academic title');
  return AcademicEvent(
    sourceId:
        '${start.toIso8601String().substring(0, 10)}/${last.toIso8601String().substring(0, 10)}/$title',
    title: title,
    start: start,
    end: DateTime(last.year, last.month, last.day + 1),
    url: url.toString(),
  );
}

List<AcademicEvent> _finish(List<AcademicEvent> rows, int year) {
  final events = <String, AcademicEvent>{};
  for (final event in rows) {
    if (!event.end.isAfter(event.start)) {
      throw const FormatException('Invalid published academic range');
    }
    if (!event.start.isBefore(DateTime(year + 1)) ||
        !event.end.isAfter(DateTime(year))) {
      continue;
    }
    final prior = events[event.sourceId];
    if (prior != null &&
        jsonEncode(prior.toJson()) != jsonEncode(event.toJson())) {
      throw const FormatException('Conflicting published academic event');
    }
    events[event.sourceId] = event;
  }
  if (events.isEmpty) {
    throw const FormatException('No published academic calendar');
  }
  return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}
