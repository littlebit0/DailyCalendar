import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class EwhaAcademicSource implements AcademicSource {
  EwhaAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'ewha';
  @override
  String get name => '이화여자대학교';
  @override
  Uri get website =>
      Uri.https('www.ewha.ac.kr', '/ewha/bachelor/calendar2026.do');

  static Uri page(int year) => Uri.https(
    'www.ewha.ac.kr',
    '/ewha/bachelor/calendar2026.do',
    {'mode': 'user_list', 'year': '$year'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final pages = <Map<DateTime, List<AcademicEvent>>>[];
    // Each page is an academic year ending with next year's Jan/Feb, so
    // January of [year] may be published only on the previous year's page.
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(page(selected))
          .timeout(const Duration(seconds: 25));
      checkAcademicResponse(response);
      pages.add(parseMonths(utf8.decode(response.bodyBytes), selected));
    }
    // Both pages list the overlapping January/February months. A month the
    // [year] page publishes is authoritative, so its corrections and removals
    // win; the previous page only fills months the [year] page does not list.
    final months = {...pages.first, ...pages.last};
    final events = <String, AcademicEvent>{};
    for (final event in months.values.expand((rows) => rows)) {
      if (event.start.isBefore(DateTime(year + 1)) &&
          event.end.isAfter(DateTime(year))) {
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published academic calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Every row of one academic-year page, including next year's Jan/Feb.
  static List<AcademicEvent> parse(String body, int year) {
    final events = {
      for (final event in parseMonths(body, year).values.expand((e) => e))
        event.sourceId: event,
    };
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// The page's rows grouped by the month heading they are published under;
  /// only months with at least one row are present.
  static Map<DateTime, List<AcademicEvent>> parseMonths(String body, int year) {
    final doc = html.parse(body);
    // Month titles carry no year, so the page's own year banner is the only proof
    // that the response is the requested year; never relabel another year's page.
    final shownYears = {
      for (final span in doc.querySelectorAll('.b-cal-day-box span'))
        if (RegExp(r'^\d{4}$').hasMatch(span.text.trim())) span.text.trim(),
    };
    if (shownYears.length != 1 || shownYears.single != '$year') {
      throw const FormatException('Unexpected EWHA year');
    }
    final url = page(year).toString();
    final events = <String, AcademicEvent>{};
    final months = <DateTime, List<AcademicEvent>>{};
    for (final p in doc.querySelectorAll('p')) {
      final heading = RegExp(
        r'^(?:(\d{4})년\s*)?(\d{1,2})월$',
      ).firstMatch(p.text.trim());
      if (heading == null) continue;
      final y = heading[1] == null ? year : int.parse(heading[1]!);
      final m = int.parse(heading[2]!);
      final container = p.parent;
      if (container == null) continue;
      for (final li in container.querySelectorAll('li')) {
        final record = li.parent?.parent;
        final dates = record?.querySelector('p')?.text ?? '';
        final matches = RegExp(
          r'(?:(\d{1,2})\.)?(\d{1,2})\([월화수목금토일]\)',
        ).allMatches(dates).toList();
        if (matches.isEmpty || matches.length > 2) {
          throw const FormatException('Invalid EWHA event');
        }
        DateTime date(RegExpMatch v) =>
            _date(y, v[1] == null ? m : int.parse(v[1]!), int.parse(v[2]!));
        final event = _event(
          li.text,
          date(matches.first),
          date(matches.last),
          url,
        );
        final prior = events[event.sourceId];
        if (prior != null &&
            jsonEncode(prior.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting published academic event');
        }
        events[event.sourceId] = event;
        (months[DateTime(y, m)] ??= []).add(event);
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published academic calendar');
    }
    return months;
  }

  static DateTime _date(int year, int month, int day) {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Invalid published academic date');
    }
    return date;
  }

  static AcademicEvent _event(
    String title,
    DateTime start,
    DateTime last,
    String url,
  ) {
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) throw const FormatException('Empty academic title');
    final end = DateTime(last.year, last.month, last.day + 1);
    if (!end.isAfter(start)) {
      throw const FormatException('Invalid published academic range');
    }
    // Same start/last/title identity as the previous release, so existing
    // imported events keep their IDs.
    return AcademicEvent(
      sourceId:
          '${start.toIso8601String().substring(0, 10)}/${last.toIso8601String().substring(0, 10)}/$title',
      title: title,
      start: start,
      end: end,
      url: url,
    );
  }

  @override
  void close() => _client.close();
}
