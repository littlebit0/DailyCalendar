import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// The official Mirae calendar uses the Sinchon sc/28 annual feed too.
class YonseiAcademicSource implements AcademicSource {
  YonseiAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'yonsei';
  @override
  String get name => '연세대학교';
  @override
  Uri get website => Uri.https('yonsei.ac.kr', '/sc/373/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('yonsei.ac.kr', '/schdulMng/sc/28/yearSchdul.do'),
            body: {'kind': '', 'year': '$selected'},
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Yonsei calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Yonsei calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('#year')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected Yonsei year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    final pattern = RegExp(
      r'^(\d{2})-(\d{2})\s*\((Mon|Tue|Wed|Thu|Fri|Sat|Sun)\)(?:\s*~\s*(?:(\d{2})-)?(\d{2})\s*\((Mon|Tue|Wed|Thu|Fri|Sat|Sun)\))?$',
    );
    DateTime date(int y, int m, int day) {
      final value = DateTime(y, m, day);
      if (value.year != y || value.month != m || value.day != day) {
        throw const FormatException('Invalid Yonsei date');
      }
      return value;
    }

    for (final section in document.querySelectorAll(
      '#timeTableList > ul > li',
    )) {
      final heading =
          section.querySelector('.box-sch .num h3 span')?.text.trim() ?? '';
      final match = RegExp(r'^(\d{1,2})월$').firstMatch(heading);
      if (match == null) throw const FormatException('Missing Yonsei month');
      final month = int.parse(match[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Yonsei month');
      }
      for (final row in section.querySelectorAll('.desc dl')) {
        final title = (row.querySelector('dd')?.text ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final text = (row.querySelector('dt')?.text ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final range = pattern.firstMatch(text);
        if (title.isEmpty || range == null) {
          throw const FormatException('Invalid Yonsei event');
        }
        final startMonth = int.parse(range[1]!);
        final startDay = int.parse(range[2]!);
        final start = date(
          startMonth > month ? year - 1 : year,
          startMonth,
          startDay,
        );
        var last = start;
        if (range[5] != null) {
          final lastDay = int.parse(range[5]!);
          final explicitMonth = range[4] == null ? null : int.parse(range[4]!);
          // A written end month is a calendar month; only an omitted one may
          // roll over (December to the next January) by normalization below.
          if (explicitMonth != null && (explicitMonth < 1 || explicitMonth > 12)) {
            throw const FormatException('Invalid Yonsei date');
          }
          final lastMonth =
              explicitMonth ?? startMonth + (lastDay < startDay ? 1 : 0);
          final normalized = DateTime(start.year, lastMonth, 1);
          final lastYear = range[4] != null && lastMonth < startMonth
              ? start.year + 1
              : normalized.year;
          last = date(lastYear, normalized.month, lastDay);
        }
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected Yonsei period');
        }
        final identity =
            '${start.toIso8601String()}:${last.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: end,
          url: 'https://yonsei.ac.kr/sc/373/subview.do',
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Yonsei calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
