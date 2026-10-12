import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

class UnistAcademicSource implements AcademicSource {
  UnistAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'unist';
  @override
  String get name => '울산과학기술원';
  @override
  Uri get website =>
      Uri.https('www.unist.ac.kr', '/unist/education/academic/schedule.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website.replace(
            queryParameters: {
              'mode': 'getCalendarData',
              'siteId': 'unist',
              'start': '$year-01-01',
              'end': '${year + 1}-01-01',
            },
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('UNIST calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Unexpected UNIST calendar');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid UNIST date');
      }
      final parts = value.split('-').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid UNIST date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in decoded['data'] as List) {
      if (row is! Map ||
          row['siteId'] != 'unist' ||
          row['cSeq'] is! int ||
          row['content'] is! String ||
          (row['content'] as String).trim().isEmpty) {
        throw const FormatException('Invalid UNIST record');
      }
      final start = date(row['beginDt']);
      final last = date(row['endDt']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start)) {
        throw const FormatException('Invalid UNIST period');
      }
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      final id = row['cSeq'].toString();
      final event = AcademicEvent(
        sourceId: id,
        title: (row['content'] as String).trim(),
        start: start,
        end: end,
        url:
            'https://www.unist.ac.kr/unist/education/academic/schedule.do?mode=list&selectedYear=$year',
      );
      if (events.containsKey(id) &&
          jsonEncode(events[id]!.toJson()) != jsonEncode(event.toJson())) {
        throw const FormatException('Conflicting UNIST record');
      }
      events[id] = event;
    }
    if (events.isEmpty) {
      throw const FormatException('No published UNIST calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
