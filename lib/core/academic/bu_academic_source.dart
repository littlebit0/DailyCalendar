import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class BuAcademicSource implements AcademicSource {
  BuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'bu';
  @override
  String get name => '백석대학교';
  @override
  Uri get website => Uri.https('www.bu.ac.kr', '/web/3443/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final requestedYear in [year - 1, year]) {
      if (requestedYear == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.bu.ac.kr', '/totalSchdul/web/jsonYearSchdul.do'),
            headers: {'Referer': website.toString()},
            body: {'year': '$requestedYear'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('BU calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        requestedYear,
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published BU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded.isEmpty ||
        decoded.keys.any((key) => !RegExp(r'^\d+$').hasMatch(key.toString()))) {
      throw const FormatException('Invalid BU calendar response');
    }
    DateTime date(Object? value) {
      if (value is! String ||
          !RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid BU calendar date');
      }
      final p = value.split('.').map(int.parse).toList();
      final date = DateTime(p[0], p[1], p[2]);
      if (date.year != p[0] || date.month != p[1] || date.day != p[2]) {
        throw const FormatException('Invalid BU calendar date');
      }
      return date;
    }

    final events = <String, AcademicEvent>{};
    for (final row in decoded.values) {
      if (row is! Map ||
          row['sj'] is! String ||
          (row['sj'] as String).trim().isEmpty) {
        throw const FormatException('Invalid BU calendar event');
      }
      final start = date(row['bgnde']);
      final last = date(row['endde']);
      if (last.isBefore(start) ||
          start.year < year ||
          start.year > year + 1 ||
          (start.year == year + 1 && start.month > 2)) {
        throw const FormatException('Unexpected BU calendar period');
      }
      final title = (row['sj'] as String).trim();
      final identity = '${row['bgnde']}:${row['endde']}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: DateTime(last.year, last.month, last.day + 1),
        url: 'https://www.bu.ac.kr/web/3443/subview.do',
      );
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
