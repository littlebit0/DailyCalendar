import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Sejong's public calendar separates undergraduate and graduate schedules.
class SejongAcademicSource implements AcademicSource {
  SejongAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'sejong';
  @override
  String get name => '세종대학교';
  @override
  Uri get website =>
      Uri.https('www.sejong.ac.kr', '/kor/academics/academic-calendar.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website.replace(
            queryParameters: {
              'mode': 'getCalendarData',
              'collDiv': '0001',
              'start': '$year-01-01',
              'end': '${year + 1}-01-01',
            },
          ),
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Invalid Sejong calendar');
    }
    final records = <AcademicCalendarRecord>[];
    for (final row in decoded['data'] as List) {
      if (row is! Map || row['collDiv'] is! String) {
        throw const FormatException('Invalid Sejong record');
      }
      if (row['collDiv'] != '0001') {
        continue;
      }
      final title = row['scmSubject'];
      if (title is! String || title.trim().isEmpty) {
        throw const FormatException('Invalid academic title');
      }
      records.add((
        title: title.trim(),
        start: _date(row['frDt']),
        last: _date(row['toDt']),
      ));
    }
    return academicCalendarEvents(
      records,
      year,
      'https://www.sejong.ac.kr/kor/academics/academic-calendar.do?mode=list&selectedYear=$year',
    );
  }

  static DateTime _date(dynamic raw) {
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw const FormatException('Invalid academic date');
    }
    final parts = raw.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    if (date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2]) {
      throw const FormatException('Invalid academic date');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
