import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class DnueAcademicSource implements AcademicSource {
  DnueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'dnue';
  @override
  String get name => '대구교육대학교';
  @override
  Uri get website => Uri.https(
    'www.dnue.ac.kr',
    '/kor/CMS/ScheduleMgr/YearList.do',
    {'mCode': 'MN119'},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                ...website.queryParameters,
                'calendar_year': '$selected',
              },
            ),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('DNUE calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published DNUE calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final block in document.querySelectorAll(
      '.sch-data-wr .sch-monlist-wr',
    )) {
      final heading = block.querySelector('.cal-month')?.text.trim();
      final m = RegExp(r'^(\d{4})\.\s*(\d{2})$').firstMatch(heading ?? '');
      if (m == null ||
          int.parse(m[1]!) != year ||
          !months.add(int.parse(m[2]!)) ||
          int.parse(m[2]!) < 1 ||
          int.parse(m[2]!) > 12) {
        throw const FormatException('Unexpected DNUE calendar month');
      }
      final month = int.parse(m[2]!);
      for (final row in block.querySelectorAll('.daily-li:not(.no-data)')) {
        final text = row.querySelector('.date-core')?.text.trim() ?? '';
        final dates = RegExp(
          r'(\d{2})\.\s*(\d{2})\([^)]*\)',
        ).allMatches(text).toList();
        final title = row
            .querySelector('.body-core')
            ?.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (dates.isEmpty ||
            dates.length > 2 ||
            title == null ||
            title.isEmpty) {
          throw const FormatException('Invalid DNUE calendar event');
        }
        DateTime date(RegExpMatch match, int dateYear) {
          final month = int.parse(match[1]!);
          final day = int.parse(match[2]!);
          final d = DateTime(dateYear, month, day);
          if (d.year != dateYear || d.month != month || d.day != day) {
            throw const FormatException('Invalid DNUE date');
          }
          return d;
        }

        final firstMonth = int.parse(dates.first[1]!);
        final start = date(dates.first, firstMonth > month ? year - 1 : year);
        final last = date(
          dates.last,
          int.parse(dates.last[1]!) < firstMonth ? start.year + 1 : start.year,
        );
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected DNUE calendar period');
        }
        final identity =
            '${start.toIso8601String()}:${last.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: end,
          url:
              'https://www.dnue.ac.kr/kor/CMS/ScheduleMgr/YearList.do?mCode=MN119&calendar_year=$year',
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete DNUE calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
