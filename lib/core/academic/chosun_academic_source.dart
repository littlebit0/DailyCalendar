import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// Annual rows were cross-checked against every monthly event's full-date layer.
class ChosunAcademicSource implements AcademicSource {
  ChosunAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'chosun';
  @override
  String get name => '조선대학교';
  @override
  Uri get website => Uri.https('csu.chosun.ac.kr', '/chosun/224/subview.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https(
              'csu.chosun.ac.kr',
              '/schdulmanage/chosun/1/yearSchdul.do',
            ),
            body: {'year': '$selected', 'kind': ''},
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Chosun calendar unavailable');
      }
      for (final e in parse(utf8.decode(response.bodyBytes), selected)) {
        if (e.start.isBefore(DateTime(year + 1)) &&
            e.end.isAfter(DateTime(year))) {
          events[e.sourceId] = e;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Chosun calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    final sections = document.querySelectorAll(
      '#timeTableList.yearSchdul > ul > li',
    );
    if (document.querySelector('#year')?.attributes['value'] != '$year' ||
        sections.length != 12) {
      throw const FormatException('Unexpected Chosun year');
    }
    final months = <int>{};
    final events = <AcademicEvent>[];
    DateTime date(int y, int m, int d) {
      final v = DateTime(y, m, d);
      if (v.year != y || v.month != m || v.day != d) {
        throw const FormatException('Invalid Chosun date');
      }
      return v;
    }

    for (final section in sections) {
      final heading = RegExp(
        r'^(\d{1,2})월$',
      ).firstMatch(section.querySelector('h3')?.text.trim() ?? '');
      if (heading == null) {
        throw const FormatException('Missing Chosun month');
      }
      final month = int.parse(heading[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Chosun month');
      }
      final dates = section.querySelectorAll('dl > dt');
      final titles = section.querySelectorAll('dl > dd');
      if (dates.length != titles.length) {
        throw const FormatException('Incomplete Chosun rows');
      }
      for (var i = 0; i < dates.length; i++) {
        final raw = dates[i].text
            .replaceAll(RegExp(r'\([월화수목금토일]\)'), '')
            .replaceAll(RegExp(r'\s+'), '');
        final match = RegExp(
          r'^(\d{2})-(\d{2})(?:~(\d{2})-(\d{2}))?$',
        ).firstMatch(raw);
        final title = titles[i].text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (match == null || title.isEmpty) {
          throw const FormatException('Invalid Chosun event');
        }
        final sm = int.parse(match[1]!);
        final start = date(
          year - (sm > month ? 1 : 0),
          sm,
          int.parse(match[2]!),
        );
        final em = match[3] == null ? sm : int.parse(match[3]!);
        final last = match[3] == null
            ? start
            : date(start.year + (em < sm ? 1 : 0), em, int.parse(match[4]!));
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected Chosun period');
        }
        events.add(
          AcademicEvent(
            sourceId:
                '${start.toIso8601String()}:${last.toIso8601String()}:$title',
            title: title,
            start: start,
            end: end,
            url: 'https://csu.chosun.ac.kr/chosun/224/subview.do',
          ),
        );
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Chosun calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
