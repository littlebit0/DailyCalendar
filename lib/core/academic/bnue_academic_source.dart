import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

class BnueAcademicSource implements AcademicSource {
  BnueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'bnue';
  @override
  String get name => '부산교육대학교';
  @override
  Uri get website => Uri.https('www.bnue.ac.kr', '/calendar/life01');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          Uri.https('www.bnue.ac.kr', '/home/calendar/data/CALENDAR_000004', {
            'year': '$year',
            'month': '',
            'viewType': 'yearly',
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('BNUE calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['calendarid'] != 'CALENDAR_000004' ||
        decoded['year'].toString() != '$year' ||
        decoded['dataList'] is! List) {
      throw const FormatException('Unexpected BNUE calendar');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid BNUE date');
      }
      final parts = value.split('-').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid BNUE date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in decoded['dataList'] as List) {
      if (row is! Map ||
          row['calendarid'] != 'CALENDAR_000004' ||
          row['idx'] is! int ||
          row['del'] != 'N' ||
          row['useyn'] != 'Y' ||
          row['schedule'] is! String ||
          (row['schedule'] as String).trim().isEmpty) {
        throw const FormatException('Invalid BNUE record');
      }
      final start = date(row['sdate']);
      final last = date(row['edate']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start)) {
        throw const FormatException('Invalid BNUE period');
      }
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      final id = row['idx'].toString();
      final event = AcademicEvent(
        sourceId: id,
        title: (row['schedule'] as String).trim(),
        start: start,
        end: end,
        url: 'https://www.bnue.ac.kr/calendar/life01?year=$year',
      );
      if (events.containsKey(id) &&
          jsonEncode(events[id]!.toJson()) != jsonEncode(event.toJson())) {
        throw const FormatException('Conflicting BNUE record');
      }
      events[id] = event;
    }
    if (events.isEmpty) {
      throw const FormatException('No published BNUE calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
