import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// KU's common undergraduate schedule, also referenced by Sejong's official
/// revised calendar notice. The annual view omits period ends; use monthly rows.
class KoreaAcademicSource implements AcademicSource {
  KoreaAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'korea';
  @override
  String get name => '고려대학교';
  @override
  Uri get website => Uri.https('www.korea.ac.kr', '/ko/460/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Include the preceding December to retain any published cross-year period.
    for (var offset = 0; offset <= 12; offset++) {
      final y = offset == 0 ? year - 1 : year;
      final month = offset == 0 ? 12 : offset;
      if (offset > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.korea.ac.kr', '/schdulMng/ko/5/monthSchdul.do'),
            body: {
              'kind': '',
              'year': '$y',
              'month': '$month',
              'schdulType': 'MONTH',
            },
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('KU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), y, month)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published KU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    final d = html.parse(body);
    final tables = d.querySelectorAll('.sche-comt table');
    if (month < 1 ||
        month > 12 ||
        d.querySelector('#year')?.attributes['value'] != '$year' ||
        tables.length != 1 ||
        tables.single.querySelector('caption')?.text.trim() !=
            '$month월 학사일정 일정별 상세 목록입니다.') {
      throw const FormatException('Unexpected KU calendar scope');
    }
    final result = <AcademicEvent>[];
    DateTime date(String text, int y) {
      final match = RegExp(r'^(\d{2})\.(\d{2})$').firstMatch(text.trim());
      if (match == null) {
        throw const FormatException('Invalid KU date');
      }
      final m = int.parse(match[1]!), day = int.parse(match[2]!);
      final value = DateTime(y, m, day);
      if (value.year != y || value.month != m || value.day != day) {
        throw const FormatException('Invalid KU date');
      }
      return value;
    }

    for (final row in tables.single.querySelectorAll('tbody tr')) {
      final text = (row.querySelector('th')?.text ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final title = (row.querySelector('td')?.text ?? '')
          .replaceAll(r'\,', ',')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final range = text.split('~');
      if (title.isEmpty || range.length > 2) {
        throw const FormatException('Invalid KU event');
      }
      var start = date(range.first, year);
      if (start.month > month) {
        start = date(range.first, year - 1);
      }
      var last = date(range.last, start.year);
      if (last.month < start.month) {
        last = date(range.last, start.year + 1);
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected KU period');
      }
      result.add(
        AcademicEvent(
          sourceId:
              '${start.toIso8601String()}:${last.toIso8601String()}:$title',
          title: title,
          start: start,
          end: end,
          url: 'https://www.korea.ac.kr/ko/460/subview.do',
        ),
      );
    }
    if (result.isEmpty) {
      throw const FormatException('Empty KU calendar month');
    }
    return result;
  }

  @override
  void close() => _client.close();
}
