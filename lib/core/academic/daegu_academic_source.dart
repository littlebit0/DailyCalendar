import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// The university (not graduate school) March–February calendar.
class DaeguAcademicSource implements AcademicSource {
  DaeguAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'daegu';
  @override
  String get name => '대구대학교';
  @override
  Uri get website => Uri.https('www.daegu.ac.kr', '/schedule/detail');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final academicYear in [year - 1, year]) {
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'schedule_info_seq': '1',
                'schedule_start_date': '$academicYear',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Daegu calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Daegu calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document.querySelector('h3.sub_title')?.text.trim() !=
            '$academicYear년도 대학 일정' ||
        document
                .querySelector(
                  'select[name=schedule_info_seq] option[selected]',
                )
                ?.attributes['value'] !=
            '1') {
      throw const FormatException('Unexpected Daegu calendar year or school');
    }
    final events = <AcademicEvent>[];
    final months = <int>{};
    final occurrences = <String, int>{};
    for (final row in document.querySelectorAll('table.tbl_cal tr')) {
      final header = row.querySelector('th');
      final cells = row.querySelectorAll('td');
      if (header == null || cells.isEmpty) {
        continue;
      }
      final match = RegExp(r'^(\d{1,2})월$').firstMatch(header.text.trim());
      if (match == null || cells.length != 2) {
        throw const FormatException('Invalid Daegu calendar row');
      }
      final month = int.parse(match[1]!);
      if (month < 1 || month > 12) {
        throw const FormatException('Invalid Daegu month');
      }
      months.add(month);
      final range = cells[0].text.trim().split('~');
      if (range.isEmpty || range.length > 2) {
        throw const FormatException('Invalid Daegu date range');
      }
      DateTime date(String text) {
        final day = RegExp(
          r'^\s*(\d{2})-(\d{2})\s*\([월화수목금토일]\)\s*$',
        ).firstMatch(text);
        if (day == null) {
          throw const FormatException('Invalid Daegu date');
        }
        final m = int.parse(day[1]!);
        final d = int.parse(day[2]!);
        final y = academicYear + (m <= 2 ? 1 : 0);
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid Daegu date');
        }
        return result;
      }

      final start = date(range.first);
      final last = date(range.last);
      if (start.month != month || last.isBefore(start)) {
        throw const FormatException('Conflicting Daegu period');
      }
      final category = cells[1].querySelector('span');
      if (category?.text.trim() != '대학') {
        throw const FormatException('Unexpected Daegu school category');
      }
      category!.remove();
      final titles = cells[1].text
          .split('▪')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (titles.isEmpty) {
        throw const FormatException('Missing Daegu title');
      }
      for (final title in titles) {
        final key = '$academicYear:$title';
        final occurrence = occurrences.update(
          key,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        events.add(
          AcademicEvent(
            sourceId: '$key:$occurrence',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.daegu.ac.kr/schedule/detail?schedule_info_seq=1&schedule_start_date=$academicYear',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Daegu academic calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
