import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

class UtAcademicSource implements AcademicSource {
  UtAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'ut';
  @override
  String get name => '국립한국교통대학교';
  @override
  Uri get website => Uri.https(
    'www.ut.ac.kr',
    '/prog/schedule/kor/sub05_01/1/scheduleList.do',
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (var month = 1; month <= 12; month++) {
      if (month > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.ut.ac.kr', '/prog/schedule/kor/1/schedule.do'),
            body: {'rdate': '$year-${month.toString().padLeft(2, '0')}'},
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(utf8.decode(response.bodyBytes), year, month)) {
        if (events.containsKey(event.sourceId) &&
            jsonEncode(events[event.sourceId]!.toJson()) !=
                jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting UT calendar identity');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published UT calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    if (month < 1 || month > 12) {
      throw const FormatException('Invalid UT request month');
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('Invalid UT calendar');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid UT date');
      }
      final parts = value.split('-').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid UT date');
      }
      return result;
    }

    final events = <AcademicEvent>[];
    for (final row in decoded) {
      if (row is! Map ||
          row['cntNo'] is! int ||
          row['subject'] is! String ||
          (row['subject'] as String).trim().isEmpty) {
        throw const FormatException('Invalid UT event');
      }
      final start = date(row['startDate']);
      final last = date(row['endDate']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected UT period');
      }
      events.add(
        AcademicEvent(
          sourceId: row['cntNo'].toString(),
          title: (row['subject'] as String).trim(),
          start: start,
          end: end,
          url:
              'https://www.ut.ac.kr/prog/schedule/kor/sub05_01/1/scheduleList.do',
        ),
      );
    }
    return events;
  }

  @override
  void close() => _client.close();
}
