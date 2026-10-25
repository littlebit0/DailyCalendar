import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// The same public annual request used by Sookmyung's calendar editor/view.
class SookmyungAcademicSource implements AcademicSource {
  SookmyungAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'sookmyung';
  @override
  String get name => '숙명여자대학교';
  @override
  Uri get website => Uri.https(
    'www.sookmyung.ac.kr',
    '/kr/university-life/academic-calendar.do',
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Each annual response groups rows by start month, so December periods
    // that run into January appear only in the previous year's response.
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'mode': 'getYearCalendar',
                'selectedYear': '$selected',
                'siteId': 'kr',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in _events(utf8.decode(response.bodyBytes), selected)) {
        if (_overlaps(event, year)) _add(events, event);
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Sookmyung calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Events of one annual response ([year]) that fall within [year].
  static List<AcademicEvent> parse(String body, int year) {
    final events = <String, AcademicEvent>{};
    for (final event in _events(body, year)) {
      if (_overlaps(event, year)) _add(events, event);
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Sookmyung calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Every published row of the [year] response, including next January.
  static List<AcademicEvent> _events(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Invalid Sookmyung calendar');
    }
    final months = decoded['data'] as List;
    // Twelve calendar months, next January and a publication flag.
    if (months.length != 14 ||
        months.last is! Map ||
        (months.last as Map)['hasData'] != true ||
        months.take(13).any((month) => month is! List)) {
      throw const FormatException('Unpublished Sookmyung annual calendar');
    }
    final events = <String, AcademicEvent>{};
    var index = 0;
    for (final month in months.take(13).cast<List>()) {
      final bucket = DateTime(year, index + 1);
      index++;
      for (final raw in month) {
        if (raw is! Map ||
            raw['calendarSeq'] is! int ||
            raw['siteId'] != 'kr' ||
            raw['content'] is! String ||
            (raw['content'] as String).trim().isEmpty) {
          throw const FormatException('Invalid Sookmyung event');
        }
        final start = _koreanTimestampDate(raw['beginDatetime']);
        final last = _koreanTimestampDate(raw['endDatetime']);
        if (last.isBefore(start)) {
          throw const FormatException('Invalid academic period');
        }
        // Rows are grouped by start month; anything else means another year.
        if (start.year != bucket.year || start.month != bucket.month) {
          throw const FormatException('Unexpected Sookmyung period');
        }
        if (isCombinedDegreeApplication(raw['content'] as String)) continue;
        _add(
          events,
          AcademicEvent(
            sourceId: raw['calendarSeq'].toString(),
            title: (raw['content'] as String).trim(),
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.sookmyung.ac.kr/kr/university-life/academic-calendar.do?mode=list&selectedYear=${start.year}',
          ),
        );
      }
    }
    return events.values.toList();
  }

  /// Recruiting and admission results of the combined bachelor-master track,
  /// which students enter by selection after admission.
  static bool isCombinedDegreeApplication(String content) =>
      content.trim().startsWith('학석사연계과정');

  static bool _overlaps(AcademicEvent event, int year) =>
      event.start.isBefore(DateTime(year + 1)) &&
      event.end.isAfter(DateTime(year));

  static void _add(Map<String, AcademicEvent> events, AcademicEvent event) {
    final previous = events[event.sourceId];
    if (previous != null &&
        jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
      throw const FormatException('Conflicting Sookmyung event');
    }
    events[event.sourceId] = event;
  }

  /// Epoch milliseconds published as Korean midnight, as a local date.
  static DateTime _koreanTimestampDate(Object? value) {
    final milliseconds = int.tryParse(value.toString());
    if (milliseconds == null) {
      throw const FormatException('Invalid academic timestamp');
    }
    final DateTime korean;
    try {
      korean = DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).add(const Duration(hours: 9));
    } on ArgumentError {
      throw const FormatException('Invalid academic timestamp');
    }
    if (korean.year < 1900 || korean.year > 9999) {
      throw const FormatException('Invalid academic timestamp');
    }
    return DateTime(korean.year, korean.month, korean.day);
  }

  @override
  void close() => _client.close();
}
