import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

class CauAcademicSource implements AcademicSource {
  CauAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'cau';
  @override
  String get name => '중앙대학교';
  @override
  Uri get website =>
      Uri.https('www.cau.ac.kr', '/cms/FR_CON/index.do', {'MENU_ID': '590'});
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          Uri.https('www.cau.ac.kr', '/ajax/FR_SCH_SVC/ScheduleListData.do'),
          body: {'SCH_YEAR': '$year', 'SCH_SITE_NO': '2'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('CAU calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Invalid CAU calendar');
    }
    final events = <AcademicEvent>[];
    for (final row in decoded['data'] as List) {
      if (row is! Map ||
          row['SUBJECT'] is! String ||
          (row['SUBJECT'] as String).trim().isEmpty) {
        throw const FormatException('Invalid CAU event');
      }
      DateTime date(String prefix) {
        int field(String key) {
          final value = row['${prefix}_$key'];
          if (value is! String || !RegExp(r'^\d+$').hasMatch(value)) {
            throw const FormatException('Invalid CAU date field');
          }
          return int.parse(value);
        }

        final y = field('Y');
        final m = field('M');
        final d = field('D');
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid CAU date');
        }
        return result;
      }

      // Recurring holidays retain historic epoch fields. The official renderer
      // uses these requested-year Y/M/D fields, which publish their actual date.
      final start = date('START');
      final last = date('END');
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year + 1)) ||
          !end.isAfter(DateTime(year))) {
        throw const FormatException('Unexpected CAU calendar period');
      }
      final title = (row['SUBJECT'] as String).trim();
      events.add(
        AcademicEvent(
          sourceId: '$year:$title',
          title: title,
          start: start,
          end: end,
          url:
              'https://www.cau.ac.kr/cms/FR_CON/index.do?MENU_ID=590&SCH_GBN=SUM&SCH_YEAR=$year',
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('No published CAU calendar');
    }
    // Same-title rows are numbered by date, not by their position in the
    // response, so reordering an identical row set keeps each row's identity.
    events.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
    final occurrences = <String, int>{};
    return [
      for (final event in events)
        AcademicEvent(
          sourceId:
              '${event.sourceId}:${occurrences.update(event.sourceId, (n) => n + 1, ifAbsent: () => 0)}',
          title: event.title,
          start: event.start,
          end: event.end,
          url: event.url,
        ),
    ];
  }

  @override
  void close() => _client.close();
}
