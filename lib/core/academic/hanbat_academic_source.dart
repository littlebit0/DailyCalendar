import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

class HanbatAcademicSource implements AcademicSource {
  HanbatAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'hanbat';
  @override
  String get name => '국립한밭대학교';
  @override
  Uri get website => Uri.https(
    'hanbat.ac.kr',
    '/prog/schafsSchdul/kor/sub05_0201/A/scheduleList.do',
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [year - 1, year]) {
      if (selectedYear == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https(
              'hanbat.ac.kr',
              '/prog/schafsSchdul/kor/sub05_0201/A/getScheduleList.do',
            ),
            body: {
              'searchKeywordFrom': '$selectedYear',
              'searchCondition2': 'A',
            },
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
      )) {
        if (!event.start.isBefore(DateTime(year + 1)) ||
            !event.end.isAfter(DateTime(year))) {
          continue;
        }
        final previous = events[event.sourceId];
        if (previous != null &&
            jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting Hanbat event');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Hanbat calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final decoded = jsonDecode(body);
    if (decoded is! List || decoded.length != 12) {
      throw const FormatException('Incomplete Hanbat academic year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final group in decoded) {
      if (group is! Map || group['list'] is! List) {
        throw const FormatException('Invalid Hanbat month');
      }
      final month = int.tryParse('${group['month']}');
      final year = int.tryParse('${group['year']}');
      if (month == null ||
          month < 1 ||
          month > 12 ||
          !months.add(month) ||
          year != (month < 3 ? academicYear + 1 : academicYear)) {
        throw const FormatException('Unexpected Hanbat academic year');
      }
      for (final row in group['list'] as List) {
        if (row is! Map ||
            row['code'] != 'A' ||
            '${row['month']}' != '${group['month']}' ||
            '${row['year']}' != '${group['year']}') {
          throw const FormatException('Unexpected Hanbat programme');
        }
        DateTime date(dynamic value) {
          final match = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2}) 00:00:00\.0$',
          ).firstMatch('$value');
          if (match == null) {
            throw const FormatException('Invalid Hanbat date');
          }
          final y = int.parse(match[1]!);
          final m = int.parse(match[2]!);
          final d = int.parse(match[3]!);
          final result = DateTime(y, m, d);
          if (result.year != y || result.month != m || result.day != d) {
            throw const FormatException('Invalid Hanbat date');
          }
          return result;
        }

        final start = date(row['bgnde']);
        final last = row['endde'] == '' ? start : date(row['endde']);
        final title = (row['subject'] is String ? row['subject'] as String : '')
            .trim();
        final sourceId = '${row['cntNo']}';
        if (start.year != year ||
            start.month != month ||
            last.isBefore(start) ||
            title.isEmpty ||
            int.tryParse(sourceId) == null) {
          throw const FormatException('Invalid Hanbat event');
        }
        final event = AcademicEvent(
          sourceId: sourceId,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url:
              'https://hanbat.ac.kr/prog/schafsSchdul/kor/sub05_0201/A/scheduleList.do',
        );
        if (events.containsKey(sourceId)) {
          throw const FormatException('Duplicate Hanbat event identity');
        }
        events[sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Hanbat academic year');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
