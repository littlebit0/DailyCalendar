import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class CnuAcademicSource implements AcademicSource {
  CnuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'cnu';
  @override
  String get name => '충남대학교';
  @override
  Uri get website => Uri.https('plus.cnu.ac.kr', '/_prog/academic_calendar/', {
    'site_dvs_cd': 'kr',
    'menu_dvs_cd': '05020101',
  });
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
                'year': '$selected',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('CNU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published CNU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final d = html.parse(body);
    if (d.querySelector('.calen_year .year')?.text.trim() != '$academicYear') {
      throw const FormatException('Unexpected CNU year');
    }
    final months = <int>[];
    final events = <String, AcademicEvent>{};
    for (final section in d.querySelectorAll('.calen_box')) {
      final m = RegExp(r'^(\d{1,2})월$').firstMatch(
        section.querySelector('.fl_month > strong')?.text.trim() ?? '',
      );
      if (m == null) {
        throw const FormatException('Missing CNU month');
      }
      final month = int.parse(m[1]!);
      final expected = months.isEmpty ? 12 : months.length;
      if (month != expected || months.length >= 13) {
        throw const FormatException('Invalid CNU month');
      }
      final year = months.isEmpty ? academicYear - 1 : academicYear;
      months.add(month);
      for (final row in section.querySelectorAll('.fr_list > ul > li')) {
        final title =
            row
                .querySelector('.list')
                ?.text
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim() ??
            '';
        final range = (row.querySelector('strong')?.text ?? '').trim().split(
          '~',
        );
        if (title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid CNU event');
        }
        DateTime date(String text, int y) {
          final match = RegExp(
            r'^\s*(\d{2})\.(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(text);
          if (match == null) {
            throw const FormatException('Invalid CNU date');
          }
          final month = int.parse(match[1]!), day = int.parse(match[2]!);
          final value = DateTime(y, month, day);
          if (value.year != y || value.month != month || value.day != day) {
            throw const FormatException('Invalid CNU date');
          }
          return value;
        }

        var start = date(range.first, year);
        if (start.month > month) {
          start = date(range.first, year - 1);
        }
        var last = date(range.last, start.year);
        if (last.month < start.month) {
          last = date(range.last, start.year + 1);
        }
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !DateTime(
              last.year,
              last.month,
              last.day + 1,
            ).isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected CNU period');
        }
        final identity =
            '${start.toIso8601String()}:${last.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url:
              'https://plus.cnu.ac.kr/_prog/academic_calendar/?site_dvs_cd=kr&menu_dvs_cd=05020101',
        );
      }
    }
    if (months.length != 13 || events.isEmpty) {
      throw const FormatException('Incomplete CNU calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
