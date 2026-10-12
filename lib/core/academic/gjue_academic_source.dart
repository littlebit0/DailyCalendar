import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class GjueAcademicSource implements AcademicSource {
  GjueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'gjue';
  @override
  String get name => '공주교육대학교';
  @override
  Uri get website => Uri.https('www.gjue.ac.kr', '/kor/13/schedules');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            Uri.https('www.gjue.ac.kr', '/kor/13/schedules/list', {
              'year': '$selected',
            }),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('GJUE calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published GJUE calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('.calheader .green')?.text.trim() != '$year') {
      throw const FormatException('Unexpected GJUE calendar year');
    }
    final events = <String, AcademicEvent>{};
    final months = <int>{};
    for (final heading in document.querySelectorAll('.month_tt[id]')) {
      final m = RegExp(r'^month_(\d{1,2})$').firstMatch(heading.id);
      if (m == null) {
        throw const FormatException('Invalid GJUE month');
      }
      final month = int.parse(m[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid GJUE month');
      }
      final block = heading.parent;
      if (block == null) {
        throw const FormatException('Missing GJUE month');
      }
      for (final row in block.querySelectorAll('.txts > ol > li')) {
        final text = row.querySelector('strong')?.text.trim() ?? '';
        final dates = RegExp(r'(\d{2})\.(\d{2})\.').allMatches(text).toList();
        final titles = row.querySelectorAll('ul > li');
        if (dates.isEmpty || dates.length > 2 || titles.isEmpty) {
          throw const FormatException('Invalid GJUE calendar event');
        }
        DateTime date(RegExpMatch m, int dateYear) {
          final mm = int.parse(m[1]!);
          final dd = int.parse(m[2]!);
          final d = DateTime(dateYear, mm, dd);
          if (d.year != dateYear || d.month != mm || d.day != dd) {
            throw const FormatException('Invalid GJUE date');
          }
          return d;
        }

        final startMonth = int.parse(dates.first[1]!);
        final start = date(dates.first, startMonth > month ? year - 1 : year);
        final last = date(
          dates.last,
          int.parse(dates.last[1]!) < startMonth ? start.year + 1 : start.year,
        );
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected GJUE calendar period');
        }
        for (final item in titles) {
          final title = item.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.isEmpty) {
            throw const FormatException('Empty GJUE event title');
          }
          final identity =
              '${start.toIso8601String()}:${last.toIso8601String()}:$title';
          events[identity] = AcademicEvent(
            sourceId: identity,
            title: title,
            start: start,
            end: end,
            url: 'https://www.gjue.ac.kr/kor/13/schedules',
          );
        }
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete GJUE calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
