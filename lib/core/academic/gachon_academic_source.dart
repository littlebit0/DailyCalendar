import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class GachonAcademicSource implements AcademicSource {
  GachonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'gachon';
  @override
  String get name => '가천대학교';
  @override
  Uri get website => Uri.https('www.gachon.ac.kr', '/kor/1075/subview.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.gachon.ac.kr', '/schdulmanage/kor/25/yearSchdul.do'),
            body: {'kind': '', 'year': '$selected', 'schdulType': 'YEAR'},
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Gachon calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Gachon calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final d = html.parse(body);
    if (d.querySelector('#year')?.attributes['value'] != '$academicYear') {
      throw const FormatException('Unexpected Gachon year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in d.querySelectorAll('#timeTableList > ul > li')) {
      final m = RegExp(
        r'^(\d{1,2})월$',
      ).firstMatch(section.querySelector('.month-count')?.text.trim() ?? '');
      if (m == null) {
        throw const FormatException('Missing Gachon month');
      }
      final month = int.parse(m[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Gachon month');
      }
      final year = academicYear;
      for (final row in section.querySelectorAll('.schd-wrap')) {
        final title =
            row
                .querySelector('.schedule-main')
                ?.text
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim() ??
            '';
        final range = (row.querySelector('.schedule-date')?.text ?? '')
            .trim()
            .split('~');
        if (title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid Gachon event');
        }
        DateTime date(String text, int y) {
          final match = RegExp(r'^\s*(\d{2})\.(\d{2})\s*$').firstMatch(text);
          if (match == null) {
            throw const FormatException('Invalid Gachon date');
          }
          final month = int.parse(match[1]!), day = int.parse(match[2]!);
          final value = DateTime(y, month, day);
          if (value.year != y || value.month != month || value.day != day) {
            throw const FormatException('Invalid Gachon date');
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
          throw const FormatException('Unexpected Gachon period');
        }
        final identity =
            '${start.toIso8601String()}:${last.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: 'https://www.gachon.ac.kr/kor/1075/subview.do',
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Gachon calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
