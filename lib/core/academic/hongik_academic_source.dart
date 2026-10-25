import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// University-wide calendar shared by the Seoul and Sejong campuses.
class HongikAcademicSource implements AcademicSource {
  HongikAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const _page =
      'https://www.hongik.ac.kr/kr/education/academic-schedule.do';
  @override
  String get id => 'hongik';
  @override
  String get name => '홍익대학교';
  @override
  Uri get website => Uri.parse(_page);
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Each feed runs to February of the next year; ranges that begin in
    // December and continue into [year] appear only in the previous feed.
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.hongik.ac.kr', '/sso/APICipher.jsp'),
            body: {
              'data': jsonEncode({
                'url': '/schedule/get_schedule.php',
                'url2': '&GUBUN=',
                'url3': '0',
                'url4': '&YEAR=',
                'url5': '$selected',
              }),
            },
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 25));
      checkAcademicResponse(response);
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        final carried =
            selected == year || event.start.isBefore(DateTime(year));
        if (carried &&
            event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Hongik calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Every exactly dated row of the [year] feed, which spans into next year.
  static List<AcademicEvent> parse(String body, int year) {
    final data = jsonDecode(body);
    if (data is! Map || data['result'] != 'Y' || data['data'] is! List) {
      throw const FormatException('Invalid Hongik calendar');
    }
    final events = <String, AcademicEvent>{};
    for (final row in data['data'] as List) {
      if (row is! Map ||
          row['YEAR'] != '$year' ||
          row['TITLE'] is! String ||
          row['START'] is! String ||
          row['END'] is! String) {
        throw const FormatException('Invalid Hongik record');
      }
      final start = row['START'] as String, end = row['END'] as String;
      // Month-only notices do not specify dates; do not manufacture day 1.
      if (RegExp(r'^\d{4}-\d{2}$').hasMatch(start) ||
          RegExp(r'^\d{4}-\d{2}$').hasMatch(end)) {
        continue;
      }
      final first = _date(start), last = _date(end);
      if (last.isBefore(first)) {
        throw const FormatException('Invalid Hongik range');
      }
      final title = Uri.decodeComponent(
        (row['TITLE'] as String).replaceAll('+', ' '),
      ).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.isEmpty) throw const FormatException('Empty Hongik title');
      final sourceId =
          '${first.toIso8601String().substring(0, 10)}/'
          '${last.toIso8601String().substring(0, 10)}/$title';
      events[sourceId] = AcademicEvent(
        sourceId: sourceId,
        title: title,
        start: first,
        end: DateTime(last.year, last.month, last.day + 1),
        url: _page,
      );
    }
    if (events.isEmpty) {
      throw const FormatException('No published Hongik calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static DateTime _date(String value) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (m == null) throw const FormatException('Invalid Hongik date');
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) {
      throw const FormatException('Invalid Hongik date');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
