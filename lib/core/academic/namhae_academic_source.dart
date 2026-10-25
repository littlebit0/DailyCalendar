import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Namhae's published March–February academic year only. This source does not
/// import predecessor-college history before the 2026 university integration.
class NamhaeAcademicSource implements AcademicSource {
  NamhaeAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  @override
  String get id => 'changwon-namhae';
  @override
  String get name => '국립창원대학교 남해캠퍼스';
  @override
  Uri get website => Uri.https(
    'univ.namhae.ac.kr',
    '/namhae_01/web/content.do',
    {'proFn': 'namhae1_3'},
  );
  @override
  void close() => _client.close();

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(website, headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
      throw const FormatException('Namhae academic calendar unavailable');
    }
    final body = utf8.decode(response.bodyBytes);
    final document = html.parse(body);
    final heading = _clean(document.querySelector('.sub_txt_05')?.text ?? '');
    if (!heading.contains('국립창원대학교 남해캠퍼스')) {
      throw const FormatException(
        'Namhae integrated institution not confirmed',
      );
    }
    final firstMonth = document.querySelector('table.tb_3 tbody > tr > td');
    final published = RegExp(
      r'^(\d{4})년\s*3월$',
    ).firstMatch(_clean(firstMonth?.text ?? ''));
    final academicYear = int.tryParse(published?[1] ?? '');
    // The predecessor college's dates must not be presented as a four-year
    // Changwon campus calendar. The integration took effect on 2026-03-01.
    if (academicYear == null ||
        academicYear < 2026 ||
        year < 2026 ||
        !heading.contains('$academicYear년 학사일정')) {
      throw const FormatException(
        'Namhae post-integration calendar unavailable',
      );
    }
    final events = parseAnnual(body, academicYear, website.toString())
        .where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        )
        .toList();
    if (events.isEmpty) {
      throw const FormatException('Requested Namhae year not published');
    }
    return events;
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static DateTime _date(int year, int month, int day) {
    final date = DateTime(year, month, day);
    if (year < 1900 ||
        year > 9999 ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      throw const FormatException('Invalid Namhae calendar date');
    }
    return date;
  }

  static DateTime _endpoint(String value, int rowYear) {
    // Numeric dates are authoritative. Printed weekday labels contain an error
    // in the official 2026 December table, so they must not change the date.
    final m = RegExp(
      r'^(?:(\d{4})\s*\.\s*)?(\d{1,2})\s*\.\s*(\d{1,2})\s*\.?\s*\([월화수목금토일]\)$',
    ).firstMatch(_clean(value));
    if (m == null) throw const FormatException('Invalid Namhae date endpoint');
    return _date(
      int.parse(m[1] ?? '$rowYear'),
      int.parse(m[2]!),
      int.parse(m[3]!),
    );
  }

  static List<AcademicEvent> parseAnnual(String body, int year, String url) {
    final tables = html
        .parse(body)
        .querySelectorAll('table.tb_3')
        .where(
          (table) =>
              table
                  .querySelectorAll('thead th')
                  .map((e) => _clean(e.text))
                  .join('|') ==
              '년/월|일정|내용',
        )
        .toList();
    if (tables.length != 1) {
      throw const FormatException('Missing Namhae calendar table');
    }
    final months = <String>[];
    final result = <String, AcademicEvent>{};
    var remaining = 0;
    var rowYear = 0;
    var rowMonth = 0;
    for (final row in tables.single.querySelectorAll('tbody > tr')) {
      final cells = row.children.where((e) => e.localName == 'td').toList();
      var offset = 0;
      if (remaining == 0) {
        if (cells.length != 3) {
          throw const FormatException('Missing Namhae month row');
        }
        final m = RegExp(
          r'^(\d{4})년\s*(\d{1,2})월$',
        ).firstMatch(_clean(cells[0].text));
        remaining = int.tryParse(cells[0].attributes['rowspan'] ?? '1') ?? 0;
        if (m == null || remaining < 1 || remaining > 50) {
          throw const FormatException('Invalid Namhae month span');
        }
        rowYear = int.parse(m[1]!);
        rowMonth = int.parse(m[2]!);
        final expected = DateTime(year, 3 + months.length);
        if (months.length >= 12 ||
            rowYear != expected.year ||
            rowMonth != expected.month) {
          throw const FormatException('Wrong Namhae academic year/month');
        }
        months.add('$rowYear/$rowMonth');
        offset = 1;
      } else if (cells.length != 2 ||
          cells.any((e) => e.attributes.containsKey('rowspan'))) {
        throw const FormatException('Invalid Namhae continued month row');
      }
      final dates = _clean(cells[offset].text).split(RegExp(r'\s*/\s*'));
      final title = _clean(cells[offset + 1].text);
      final titles = dates.length == 1
          ? [title]
          : title.split(RegExp(r'\s*/\s*'));
      if (dates.length != titles.length || titles.any((t) => t.isEmpty)) {
        throw const FormatException('Unmatched Namhae multi-date titles');
      }
      for (var i = 0; i < dates.length; i++) {
        final endpoints = dates[i].split(RegExp(r'\s*~\s*'));
        if (endpoints.length > 2) {
          throw const FormatException('Invalid Namhae date range');
        }
        final start = _endpoint(endpoints.first, rowYear);
        final last = endpoints.length == 1
            ? start
            : _endpoint(endpoints.last, start.year);
        if (start.year != rowYear ||
            start.month != rowMonth ||
            last.isBefore(start) ||
            last.isAfter(DateTime(year + 1, 3, 0))) {
          throw const FormatException('Invalid Namhae event period');
        }
        final id =
            '${start.toIso8601String()}/${last.toIso8601String()}/${titles[i]}';
        final event = AcademicEvent(
          sourceId: id,
          title: titles[i],
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: url,
        );
        if (result.containsKey(id)) {
          throw const FormatException('Duplicate Namhae calendar row');
        }
        result[id] = event;
      }
      remaining--;
    }
    if (remaining != 0 || months.length != 12 || result.isEmpty) {
      throw const FormatException('Incomplete Namhae academic year');
    }
    return result.values.toList()..sort((a, b) {
      final order = a.start.compareTo(b.start);
      return order == 0 ? a.sourceId.compareTo(b.sourceId) : order;
    });
  }
}
