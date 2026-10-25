import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Public undergraduate calendar shared by Dankook's Jukjeon/Cheonan campuses.
/// The university page itself requests this endpoint without authentication.
class DankookAcademicSource implements AcademicSource {
  DankookAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'dku';
  @override
  String get name => '단국대학교';
  @override
  Uri get website => Uri.https('www.dankook.ac.kr', '/web/kor/-2014-');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    // Source timestamps describe Korean calendar dates, regardless of the
    // device's current timezone. Its query includes overlapping events.
    final start = DateTime.utc(year).subtract(const Duration(hours: 9));
    final end = DateTime.utc(year + 1).subtract(const Duration(hours: 9));
    // The official page requests its site group (20118) and the portal
    // group (0) and shows both lists together; identical rows are merged.
    final records = <AcademicCalendarRecord>[];
    for (final group in ['20118', '0']) {
      final response = await _client
          .get(
            Uri.https(
              'www.dankook.ac.kr',
              '/o/dku_calendar-rest/calendar/events/$group/'
                  '${start.millisecondsSinceEpoch}/${end.millisecondsSinceEpoch - 1}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      records.addAll(_records(utf8.decode(response.bodyBytes)));
    }
    return academicCalendarEvents(records, year, _url);
  }

  static const _url = 'https://www.dankook.ac.kr/web/kor/-2014-';

  static List<AcademicEvent> parse(String body, int year) =>
      academicCalendarEvents(_records(body), year, _url);

  static List<AcademicCalendarRecord> _records(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['status'] != true ||
        decoded['data'] is! List) {
      throw const FormatException('Invalid Dankook academic response');
    }
    final records = <AcademicCalendarRecord>[];
    for (final raw in decoded['data'] as List) {
      if (raw is! Map || raw['title'] is! String) {
        throw const FormatException('Incomplete Dankook academic record');
      }
      final title = (raw['title'] as String).trim();
      if (title.isEmpty) {
        throw const FormatException('Empty academic title');
      }
      final start = _koreanTimestampDate(raw['startTime']);
      final last = _koreanTimestampDate(raw['endTime']);
      records.add((title: title, start: start, last: last));
    }
    return records;
  }

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
