import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class YuAcademicSource implements AcademicSource {
  YuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'yu';
  @override
  String get name => '영남대학교';
  @override
  Uri get website => Uri.https('www.yu.ac.kr', '/main/bachelor/calendar.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(website.replace(queryParameters: {'srYear': '$selected'}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('YU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published YU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final scripts = html
        .parse(body)
        .querySelectorAll('script')
        .where((s) => s.text.contains('var calData ='))
        .toList();
    if (scripts.length != 1 ||
        !RegExp("var srYear = '$year';").hasMatch(scripts.single.text)) {
      throw const FormatException('Unexpected YU calendar year');
    }
    final match = RegExp(
      r'var calData = (\[.*?\]);',
      dotAll: true,
    ).firstMatch(scripts.single.text);
    final decoded = match == null ? null : jsonDecode(match[1]!);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('Incomplete YU calendar');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid YU date');
      }
      final p = value.split('-').map(int.parse).toList();
      final result = DateTime(p[0], p[1], p[2]);
      if (result.year != p[0] || result.month != p[1] || result.day != p[2]) {
        throw const FormatException('Invalid YU date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in decoded) {
      if (row is! Map ||
          row['articleNo'] is! int ||
          row['text'] is! String ||
          (row['text'] as String).trim().isEmpty) {
        throw const FormatException('Invalid YU calendar record');
      }
      final start = date(row['startDt']), last = date(row['endDt']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !end.isAfter(DateTime(year)) ||
          start.isAfter(DateTime(year + 1, 2, 28))) {
        throw const FormatException('Unexpected YU period');
      }
      final title = (row['text'] as String).trim();
      // The official page repeats some identical entries with different article IDs.
      final identity =
          '${start.toIso8601String()}:${last.toIso8601String()}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: end,
        url: 'https://www.yu.ac.kr/main/bachelor/calendar.do',
      );
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
