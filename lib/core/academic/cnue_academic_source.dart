import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class CnueAcademicSource implements AcademicSource {
  CnueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'cnue';
  @override
  String get name => '춘천교육대학교';
  @override
  Uri get website => Uri.https('www.cnue.ac.kr', '/cnue/info/schedule.do');
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
                'mode': 'list',
                'cYear': '$selected',
                'allYn': 'Y',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('CNUE calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published CNUE calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('.b-cal-day-box > p > span')?.text.trim() !=
        '$year') {
      throw const FormatException('Unexpected CNUE calendar year');
    }
    final list = document.querySelector('.b-cal-list-box');
    if (list == null) {
      throw const FormatException('Missing CNUE calendar');
    }
    final events = <String, AcademicEvent>{};
    final months = <int>{};
    for (final group in list.children) {
      final label = group.children.where((e) => e.localName == 'p').toList();
      if (label.isEmpty) {
        continue;
      }
      final match = RegExp(
        r'^(\d{1,2})월$',
      ).firstMatch(label.single.text.trim());
      if (match == null) {
        throw const FormatException('Invalid CNUE month');
      }
      final month = int.parse(match[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid CNUE month');
      }
      for (final row
          in group
              .querySelectorAll('div')
              .where(
                (element) =>
                    element.children.any((child) => child.localName == 'ul'),
              )) {
        final dateText = row.children.where((e) => e.localName == 'p').toList();
        final titles = row.querySelectorAll('ul > li');
        if (dateText.isEmpty && titles.isEmpty) {
          continue;
        }
        if (dateText.length != 1 || titles.isEmpty) {
          throw const FormatException('Missing CNUE event');
        }
        final matches = RegExp(
          r'(?:(\d{1,2})\.)?(\d{1,2})\([^)]*\)',
        ).allMatches(dateText.single.text).toList();
        if (matches.isEmpty || matches.length > 2) {
          throw const FormatException('Invalid CNUE dates');
        }
        DateTime date(RegExpMatch m, int dateYear) {
          final mm = int.parse(m[1] ?? '$month');
          final dd = int.parse(m[2]!);
          final d = DateTime(dateYear, mm, dd);
          if (d.year != dateYear || d.month != mm || d.day != dd) {
            throw const FormatException('Invalid CNUE date');
          }
          return d;
        }

        final startMonth = int.parse(matches.first[1] ?? '$month');
        final start = date(matches.first, startMonth > month ? year - 1 : year);
        final endMonth = int.parse(matches.last[1] ?? '$month');
        final last = date(
          matches.last,
          endMonth < startMonth ? start.year + 1 : start.year,
        );
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected CNUE calendar period');
        }
        for (final item in titles) {
          final title = item.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.isEmpty) {
            throw const FormatException('Empty CNUE event title');
          }
          final identity =
              '${start.toIso8601String()}:${last.toIso8601String()}:$title';
          events[identity] = AcademicEvent(
            sourceId: identity,
            title: title,
            start: start,
            end: end,
            url: 'https://www.cnue.ac.kr/cnue/info/schedule.do',
          );
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published CNUE calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
