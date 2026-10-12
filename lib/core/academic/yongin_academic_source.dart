import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class YonginAcademicSource implements AcademicSource {
  YonginAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'yongin';
  @override
  String get name => '용인대학교';
  @override
  Uri get website =>
      Uri.https('www.yongin.ac.kr', '/cmn/wvtex/nibr/academic/academicMain.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .post(website, body: {'srchYear': '$selectedYear'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Yongin calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
      )) {
        if (selectedYear < year && !event.start.isBefore(DateTime(year))) {
          continue; // Current year's page is authoritative for its Jan/Feb.
        }
        if (!event.start.isBefore(DateTime(year + 1)) ||
            !event.end.isAfter(DateTime(year))) {
          continue;
        }
        if (events.containsKey(event.sourceId) &&
            jsonEncode(events[event.sourceId]!.toJson()) !=
                jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting Yongin calendar record');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Yongin calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int selectedYear) {
    final document = html.parse(body);
    if (document.querySelector('#srchYear')?.attributes['value'] !=
        '$selectedYear') {
      throw const FormatException('Unexpected Yongin year');
    }
    final months = <String>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final section in document.querySelectorAll(
      '.tbl-schedule > table > tbody',
    )) {
      final y = int.tryParse(
        section.querySelector('.calendar-cell .yy strong')?.text.trim() ?? '',
      );
      final m = int.tryParse(
        section.querySelector('.calendar-cell .mm strong')?.text.trim() ?? '',
      );
      if (y == null ||
          m == null ||
          m < 1 ||
          m > 12 ||
          y < selectedYear ||
          y > selectedYear + 1 ||
          (y == selectedYear + 1 && m > 2) ||
          !months.add('$y-$m')) {
        throw const FormatException('Invalid Yongin month coverage');
      }
      for (final row in section.children.where((e) => e.localName == 'tr')) {
        if (row.querySelector('td.no_data')?.text.trim() == '등록된 일정이 없습니다.') {
          continue;
        }
        final text = row.querySelector('td.date')?.text.trim() ?? '';
        final title = row.querySelector('td.cont')?.text.trim() ?? '';
        final range = text.split('~');
        if (text.isEmpty || title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid Yongin event');
        }
        DateTime date(String value, int year) {
          final match = RegExp(
            r'^\s*(\d{2})\.(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(value);
          if (match == null) {
            throw const FormatException('Invalid Yongin date');
          }
          final month = int.parse(match[1]!);
          final day = int.parse(match[2]!);
          final result = DateTime(year, month, day);
          if (result.year != year ||
              result.month != month ||
              result.day != day) {
            throw const FormatException('Invalid Yongin date');
          }
          return result;
        }

        final start = date(range.first, y);
        var last = date(range.last, y);
        if (last.month < start.month) {
          last = date(range.last, y + 1);
        }
        if (start.month != m || last.isBefore(start)) {
          throw const FormatException('Unexpected Yongin period');
        }
        // January/February appear on both adjacent annual pages. Their actual
        // start year yields the same identity instead of importing them twice.
        final key = '${start.year}:$title';
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
                'https://www.yongin.ac.kr/cmn/wvtex/nibr/academic/academicMain.do',
          ),
        );
      }
    }
    if (months.length != 14 || events.isEmpty) {
      throw const FormatException('Incomplete Yongin calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
