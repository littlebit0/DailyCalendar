import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// The Catholic University of Korea's all-campus (성심·성의·성신) calendar.
class CatholicAcademicSource implements AcademicSource {
  CatholicAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'catholic';
  @override
  String get name => '가톨릭대학교';
  @override
  Uri get website =>
      Uri.https('www.catholic.ac.kr', '/ko/support/calendar2024_list.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website.replace(
            queryParameters: {
              'mode': 'getCalendarData',
              'siteId': 'ko',
              'start': '$year-01-01',
              'end': '${year + 1}-01-01',
            },
          ),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static final graduateOnly = RegExp(r'[(\[]\s*대학원\s*[)\]]');

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Invalid CUK calendar');
    }
    final events = <String, AcademicEvent>{};
    for (final raw in decoded['data'] as List) {
      if (raw is! Map ||
          raw['siteId'] != 'ko' ||
          raw['cSeq'] is! int ||
          raw['content'] is! String ||
          (raw['content'] as String).trim().isEmpty ||
          raw['campus'] is! String) {
        throw const FormatException('Invalid CUK event');
      }
      final campuses = (raw['campus'] as String)
          .split(',')
          .map((c) => c.trim())
          .toList();
      if (campuses.any((c) => !const ['성심', '성의', '성신'].contains(c))) {
        throw const FormatException('Unknown CUK campus');
      }
      // Graduate-school-only rows carry a "(대학원)" marker in the feed.
      if (graduateOnly.hasMatch(raw['content'] as String)) continue;
      final start = _koreanDate(raw['beginDt']);
      final last = _koreanDate(raw['endDt']);
      if (last.isBefore(start)) {
        throw const FormatException('Invalid academic period');
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      final id = raw['cSeq'].toString();
      // The table view is per academic year (March to February).
      final tableYear = start.month < 3 ? start.year - 1 : start.year;
      final event = AcademicEvent(
        sourceId: id,
        title:
            '${(raw['content'] as String).trim()} (${campuses.map((c) => '$c교정').join('·')})',
        start: start,
        end: end,
        url:
            'https://www.catholic.ac.kr/ko/support/calendar2024_list.do?mode=list&siteId=ko&selectedYear=$tableYear',
      );
      final previous = events[id];
      if (previous != null &&
          jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
        throw const FormatException('Conflicting CUK event');
      }
      events[id] = event;
    }
    if (events.isEmpty) {
      throw const FormatException('Unpublished CUK calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// The feed sends Korean midnight as epoch milliseconds.
  static DateTime _koreanDate(Object? value) {
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
