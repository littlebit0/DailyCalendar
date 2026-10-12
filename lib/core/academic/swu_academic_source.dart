import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class SwuAcademicSource implements AcademicSource {
  SwuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'swu';
  @override
  String get name => '서울여자대학교';
  @override
  Uri get website => Uri.https('www.swu.ac.kr', '/swu/689/subview.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Annual HTML omits ends. Monthly public rows contain full ranges.
    for (var month = 1; month <= 12; month++) {
      if (month > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.swu.ac.kr', '/schdulMng/swu/15/monthSchdul.do'),
            body: {'kind': '', 'year': '$year', 'month': '$month'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('SWU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), year, month)) {
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published SWU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    final document = html.parse(body);
    if (document.querySelector('#year')?.attributes['value'] != '$year' ||
        document.querySelector('.monthTitle > span')?.text.trim() !=
            '$month월') {
      throw const FormatException('Unexpected SWU year/month');
    }
    final list = document.querySelector('.monthList');
    if (list == null) throw const FormatException('Missing SWU calendar rows');
    final events = <String, AcademicEvent>{};
    for (final row in list.querySelectorAll('dl')) {
      final title =
          row
              .querySelector('dd')
              ?.text
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim() ??
          '';
      final range = row.querySelector('dt')?.text.trim().split('~');
      if (title.isEmpty || range == null || range.isEmpty || range.length > 2) {
        throw const FormatException('Invalid SWU event');
      }
      DateTime date(String text, int y) {
        final match = RegExp(r'^\s*(\d{2})\.(\d{2})\s*$').firstMatch(text);
        if (match == null) throw const FormatException('Invalid SWU date');
        final m = int.parse(match[1]!);
        final d = int.parse(match[2]!);
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid SWU date');
        }
        return result;
      }

      var start = date(range.first, year);
      if (start.month > month) start = date(range.first, year - 1);
      var last = date(range.last, start.year);
      if (last.month < start.month) last = date(range.last, start.year + 1);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected SWU calendar period');
      }
      final identity =
          '${start.toIso8601String()}:${last.toIso8601String()}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: end,
        url: 'https://www.swu.ac.kr/swu/689/subview.do',
      );
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
