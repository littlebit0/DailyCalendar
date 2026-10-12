import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class InhaAcademicSource implements AcademicSource {
  InhaAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'inha';
  @override
  String get name => '인하대학교';
  @override
  Uri get website => Uri.https('www.inha.ac.kr', '/kr/1908/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    // The official annual view explicitly includes preceding December.
    // Its mobile monthly view incorrectly mixes a later winter into January.
    final response = await _client
        .post(
          Uri.https('www.inha.ac.kr', '/schdulmanage/kr/5/yearSchdul.do'),
          headers: {
            'Referer': website.toString(),
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
          body: {'kind': '', 'year': '$year'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('INHA calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('input#year')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected INHA calendar year');
    }
    final coverage = <String>{};
    final events = <String, AcademicEvent>{};
    for (final section in document.querySelectorAll(
      '#timeTableList > ul > li',
    )) {
      final header = section.querySelector('h3')?.text.trim() ?? '';
      final match = RegExp(
        r'^(\d{1,2})\s*월(?:\s*\((\d{4})년\))?$',
      ).firstMatch(header);
      if (match == null) throw const FormatException('Invalid INHA month');
      final month = int.parse(match[1]!);
      final sectionYear = match[2] == null ? year : int.parse(match[2]!);
      if (month < 1 ||
          month > 12 ||
          (sectionYear != year && !(sectionYear == year - 1 && month == 12)) ||
          !coverage.add('$sectionYear/$month')) {
        throw const FormatException('Invalid INHA year coverage');
      }
      final dates = section.querySelectorAll('dl > dt');
      final titles = section.querySelectorAll('dl > dd');
      if (dates.length != titles.length) {
        throw const FormatException('Invalid INHA rows');
      }
      for (var i = 0; i < dates.length; i++) {
        final title = titles[i].text.trim();
        final range = dates[i].text.trim().split('~');
        if (title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid INHA event');
        }
        DateTime date(String value, int dateYear) {
          final m = RegExp(
            r'^\s*(\d{2})\.(\d{2})\.\([월화수목금토일]\)\s*$',
          ).firstMatch(value);
          if (m == null) throw const FormatException('Invalid INHA date');
          final mm = int.parse(m[1]!);
          final dd = int.parse(m[2]!);
          final result = DateTime(dateYear, mm, dd);
          if (result.year != dateYear ||
              result.month != mm ||
              result.day != dd) {
            throw const FormatException('Invalid INHA date');
          }
          return result;
        }

        final start = date(range.first, sectionYear);
        var last = date(range.last, sectionYear);
        if (last.month < start.month) last = date(range.last, sectionYear + 1);
        if (last.isBefore(start) || start.month != month) {
          throw const FormatException('Invalid INHA period');
        }
        final end = DateTime(last.year, last.month, last.day + 1);
        if (!start.isBefore(DateTime(year + 1)) ||
            !end.isAfter(DateTime(year))) {
          continue;
        }
        final identity = '${start.toIso8601String()}:$title';
        if (events.containsKey(identity)) {
          throw const FormatException('Duplicate INHA event');
        }
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: end,
          url: 'https://www.inha.ac.kr/kr/1908/subview.do',
        );
      }
    }
    if (coverage.length != 13 ||
        !coverage.contains('${year - 1}/12') ||
        events.isEmpty) {
      throw const FormatException('Incomplete INHA calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
