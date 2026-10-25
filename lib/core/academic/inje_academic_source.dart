import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';
import 'month_structure.dart';

class InjeAcademicSource implements AcademicSource {
  InjeAcademicSource({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  @override
  String get id => 'inje';
  @override
  String get name => '인제대학교';
  @override
  Uri get website => Uri.https('www.inje.ac.kr', '/kor/setRoute/B_Page.asp', {
    'pCode': 'IF010010000',
    'viewType': 'vy',
  });
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await client
        .get(
          website.replace(
            queryParameters: {
              ...website.queryParameters,
              'setYear': '$year',
              'setMonth': '1',
            },
          ),
        )
        .timeout(const Duration(seconds: 25));
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final doc = html.parse(body);
    if (doc.querySelector('.yearPart h4')?.text.trim() != '$year년') {
      throw const FormatException('Unexpected INJE calendar year');
    }
    // Observed 2019-2027: the server always sends twelve month cards, and a
    // month without events is an empty card, so a missing, repeated or
    // misnumbered card means a damaged response.
    requireTwelveMonths(
      doc.querySelectorAll('.monthCard .monthNum').map((node) => node.text),
      'INJE',
    );
    final events = <AcademicEvent>[];
    for (final row in doc.querySelectorAll('.eventList li')) {
      final title = row.querySelector('.titleTxt')?.text;
      final dates = RegExp(
        r'(\d{2})\.\s*(\d{2})\.',
      ).allMatches(row.querySelector('.dateTxt')?.text ?? '').toList();
      if (title == null || dates.isEmpty || dates.length > 2) {
        throw const FormatException('Invalid INJE event');
      }
      final start = _date(
        year,
        int.parse(dates.first[1]!),
        int.parse(dates.first[2]!),
      );
      final last = _date(
        year,
        int.parse(dates.last[1]!),
        int.parse(dates.last[2]!),
      );
      events.add(
        _event(
          title,
          start,
          last,
          Uri.https('www.inje.ac.kr', '/kor/setRoute/B_Page.asp', {
            'pCode': 'IF010010000',
            'viewType': 'vy',
            'setYear': '$year',
          }),
        ),
      );
    }
    return _finish(events, year);
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
    // The 2025 page lists some rows twice verbatim; only a differing repeat
    // under the same identity is a conflict.
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
