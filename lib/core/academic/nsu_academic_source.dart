import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

class NsuAcademicSource implements AcademicSource {
  NsuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'nsu';
  @override
  String get name => '남서울대학교';
  @override
  Uri get website =>
      Uri.https('nsu.ac.kr', '/', {'m1': 'page', 'menu_id': '218'});
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (var month = 1; month <= 12; month++) {
      if (month > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('nsu.ac.kr', '/api/calendar/getScheduleSummaryList'),
            headers: {
              'Referer': website.toString(),
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
            body: {
              'departmentIdx': '1',
              'year': '$year',
              'month': '$month',
              'orderByCode': '2',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('NSU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), year, month)) {
        if (events.containsKey(event.sourceId) &&
            jsonEncode(events[event.sourceId]!.toJson()) !=
                jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting NSU calendar identity');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published NSU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    if (month < 1 || month > 12) {
      throw const FormatException('Invalid NSU request month');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['code'] != 10000 ||
        decoded['body'] is! Map) {
      throw const FormatException('Invalid NSU calendar');
    }
    final data = decoded['body'] as Map;
    final rows = data['list'];
    final total = data['total_count'];
    // Official monthly responses may include additional overlapping events
    // beyond total_count. Keep every returned row, never truncate to that count.
    if (rows is! List || total is! int || total < 0 || rows.length < total) {
      throw const FormatException('Incomplete NSU calendar response');
    }
    DateTime date(Object? value) {
      if (value is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2} 00:00:00$').hasMatch(value)) {
        throw const FormatException('Invalid NSU date');
      }
      final parts = value.split(' ').first.split('-').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid NSU date');
      }
      return result;
    }

    final events = <AcademicEvent>[];
    for (final row in rows) {
      if (row is! Map ||
          row['department_idx'] != 1 ||
          row['id'] is! int ||
          row['title'] is! String ||
          (row['title'] as String).trim().isEmpty) {
        throw const FormatException('Invalid NSU event');
      }
      final start = date(row['start_date']);
      final last = date(row['end_date']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected NSU period');
      }
      events.add(
        AcademicEvent(
          sourceId: row['id'].toString(),
          title: (row['title'] as String).trim(),
          start: start,
          end: end,
          url: 'https://nsu.ac.kr/?m1=page&menu_id=218',
        ),
      );
    }
    return events;
  }

  @override
  void close() => _client.close();
}
