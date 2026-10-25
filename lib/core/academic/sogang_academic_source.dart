import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class SogangAcademicSource implements AcademicSource {
  SogangAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'sogang';
  @override
  String get name => '서강대학교';
  @override
  Uri get website =>
      Uri.https('www.sogang.ac.kr', '/ko/academic-support/calendar');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final dates = <String, Set<DateTime>>{};
    for (final selected in [year - 1, year, year + 1]) {
      if (selected != year - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            Uri.https('www.sogang.ac.kr', '/api/api/v1/mainKo/scheduleList', {
              'startDate': '$selected.01.01',
              'endDate': '$selected.12.31',
            }),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
              'Referer': website.toString(),
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Sogang calendar unavailable');
      }
      final records = parse(utf8.decode(response.bodyBytes), selected);
      if (selected == year && records.isEmpty) {
        throw const FormatException('No published Sogang calendar');
      }
      for (final entry in records.entries) {
        dates.putIfAbsent(entry.key, () => <DateTime>{}).addAll(entry.value);
      }
    }
    final events = <AcademicEvent>[];
    for (final entry in dates.entries) {
      final days = entry.value.toList()..sort();
      var start = days.first;
      var last = start;
      void add() {
        final end = DateTime(last.year, last.month, last.day + 1);
        if (start.isBefore(DateTime(year + 1)) && end.isAfter(DateTime(year))) {
          events.add(
            AcademicEvent(
              sourceId: '${start.toIso8601String()}:${entry.key}',
              title: entry.key,
              start: start,
              end: end,
              url: website.toString(),
            ),
          );
        }
      }

      for (final date in days.skip(1)) {
        if (date != DateTime(last.year, last.month, last.day + 1)) {
          add();
          start = date;
        }
        last = date;
      }
      add();
    }
    if (events.isEmpty) {
      throw const FormatException('No published Sogang calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static Map<String, Set<DateTime>> parse(String body, int year) {
    final response = jsonDecode(body);
    if (response is! Map ||
        response['statusCode'] != 200 ||
        response['data'] is! List) {
      throw const FormatException('Invalid Sogang calendar response');
    }
    final result = <String, Set<DateTime>>{};
    for (final row in response['data'] as List) {
      if (row is! Map ||
          row['title'] is! String ||
          row['schedule'] is! String) {
        throw const FormatException('Missing Sogang calendar fields');
      }
      final title = (row['title'] as String).trim();
      final match = RegExp(
        r'^(\d{4})\.(\d{2})\.(\d{2})$',
      ).firstMatch(row['schedule'] as String);
      if (title.isEmpty || match == null || int.parse(match[1]!) != year) {
        throw const FormatException('Unexpected Sogang calendar year/title');
      }
      final month = int.parse(match[2]!);
      final day = int.parse(match[3]!);
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        throw const FormatException('Invalid Sogang calendar date');
      }
      result.putIfAbsent(title, () => <DateTime>{}).add(date);
    }
    return result;
  }

  @override
  void close() => _client.close();
}
