import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

class CjeAcademicSource implements AcademicSource {
  CjeAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'cje';
  @override
  String get name => '청주교육대학교';
  @override
  Uri get website => Uri.https('www.cje.ac.kr', '/web/schedule/list.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          Uri.https('www.cje.ac.kr', '/web/schedule/ajax/list.do'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Referer': website.toString(),
          },
          body: jsonEncode({
            'schedule_start_dt': '$year-01-01',
            'schedule_end_dt': '$year-12-31',
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('CJE calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['scheduleList'] is! List) {
      throw const FormatException('Invalid CJE calendar response');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid CJE date');
      }
      final parts = value.split('-').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid CJE date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in decoded['scheduleList'] as List) {
      if (row is! Map ||
          row['schedule_id'] is! int ||
          row['schedule'] is! String ||
          (row['schedule'] as String).trim().isEmpty ||
          row['code_nm'] != '학사') {
        throw const FormatException('Invalid CJE calendar event');
      }
      final start = date(row['schedule_start_dt']);
      final last = date(row['schedule_end_dt']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year + 1)) ||
          !end.isAfter(DateTime(year))) {
        throw const FormatException('Unexpected CJE calendar year or period');
      }
      final identity = row['schedule_id'].toString();
      if (events.containsKey(identity)) {
        throw const FormatException('Duplicate CJE calendar event');
      }
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: (row['schedule'] as String).trim(),
        start: start,
        end: end,
        url: 'https://www.cje.ac.kr/web/schedule/list.do',
      );
    }
    if (events.isEmpty) {
      throw const FormatException('No published CJE calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
