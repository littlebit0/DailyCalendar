import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// The academic-office homepage's public monthly feed includes January/February
/// omitted by its March-to-February annual HTML view.
class TukAcademicSource implements AcademicSource {
  TukAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'tuk';
  @override
  String get name => '한국공학대학교';
  @override
  Uri get website => Uri.https('www.tukorea.ac.kr', '/haksa/3000/subview.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (var offset = 0; offset <= 12; offset++) {
      final selected = offset == 0 ? year - 1 : year;
      final month = offset == 0 ? 12 : offset;
      if (offset > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https(
              'www.tukorea.ac.kr',
              '/schdulmain/haksa/37/jsonYearSchdul.do',
            ),
            body: {
              'year': '$selected',
              'month': month.toString().padLeft(2, '0'),
            },
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('TUK calendar unavailable');
      }
      final rows = parse(utf8.decode(response.bodyBytes), selected, month);
      if (selected == year && rows.isEmpty) {
        throw const FormatException('Incomplete TUK calendar year');
      }
      for (final event in rows) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published TUK calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    final data = jsonDecode(body);
    if (data is! List || month < 1 || month > 12) {
      throw const FormatException('Unexpected TUK calendar');
    }
    DateTime date(Object? raw) {
      if (raw is! String || !RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(raw)) {
        throw const FormatException('Invalid TUK date');
      }
      final p = raw.split('.').map(int.parse).toList();
      final value = DateTime(p[0], p[1], p[2]);
      if (value.year != p[0] || value.month != p[1] || value.day != p[2]) {
        throw const FormatException('Invalid TUK date');
      }
      return value;
    }

    return data.map((row) {
      if (row is! Map || row['sj'] is! String) {
        throw const FormatException('Unexpected TUK event');
      }
      final title = (row['sj'] as String)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final start = date(row['bgnde']);
      final last = date(row['endde']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (title.isEmpty ||
          last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected TUK period');
      }
      return AcademicEvent(
        sourceId: '${start.toIso8601String()}:${last.toIso8601String()}:$title',
        title: title,
        start: start,
        end: end,
        url: 'https://www.tukorea.ac.kr/haksa/3000/subview.do',
      );
    }).toList();
  }

  @override
  void close() => _client.close();
}
