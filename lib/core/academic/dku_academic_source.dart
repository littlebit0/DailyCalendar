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
    final response = await _client
        .get(
          Uri.https(
            'www.dankook.ac.kr',
            '/o/dku_calendar-rest/calendar/events/0/'
                '${start.millisecondsSinceEpoch}/${end.millisecondsSinceEpoch - 1}',
          ),
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
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
    return academicCalendarEvents(
      records,
      year,
      'https://www.dankook.ac.kr/web/kor/-2014-',
    );
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
