import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class SungshinAcademicSource implements AcademicSource {
  SungshinAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'sungshin';
  @override
  String get name => '성신여자대학교';
  @override
  Uri get website =>
      Uri.https('www.sungshin.ac.kr', '/main_kor/10999/subview.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Despite its name, yearSchdul only renders the selected month in this skin.
    for (var step = 0; step <= 12; step++) {
      final selectedYear = step == 0 ? year - 1 : year;
      final month = step == 0 ? 12 : step;
      if (step > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https(
              'www.sungshin.ac.kr',
              '/schdulmanage/main_kor/25/yearSchdul.do',
            ),
            body: {'year': '$selectedYear', 'kind': 'N', 'month': '$month'},
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
        month,
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          final existing = events[event.sourceId];
          if (existing != null &&
              (existing.title != event.title ||
                  existing.start != event.start ||
                  existing.end != event.end)) {
            throw const FormatException('Inconsistent Sungshin calendar event');
          }
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Sungshin calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    final d = html.parse(body);
    final active = d.querySelector('.calendar .nav button span.active');
    final container = d.querySelector('#cal');
    if (d.querySelector('input#year')?.attributes['value'] != '$year' ||
        active?.text.trim() != '$month월' ||
        container == null) {
      throw const FormatException('Unexpected Sungshin calendar selection');
    }
    final events = <AcademicEvent>[];
    for (final row in container.querySelectorAll('dl')) {
      final a = row.querySelector('dd a.onDate');
      final id = RegExp(
        r"set_layer\('(\d+)',\s*'main_kor',\s*'25'\)",
      ).firstMatch(a?.attributes['onclick'] ?? '');
      final title = a?.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final ranges = (row.querySelector('dt')?.text ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .split('~');
      if (id == null ||
          title == null ||
          title.isEmpty ||
          ranges.isEmpty ||
          ranges.length > 2) {
        throw const FormatException('Invalid Sungshin calendar event');
      }
      DateTime date(String text, int y) {
        final m = RegExp(
          r'^(\d{2})-(\d{2})\s*\([월화수목금토일]\)$',
        ).firstMatch(text.trim());
        if (m == null) {
          throw const FormatException('Invalid Sungshin date');
        }
        final mm = int.parse(m[1]!), dd = int.parse(m[2]!);
        final v = DateTime(y, mm, dd);
        if (v.year != y || v.month != mm || v.day != dd) {
          throw const FormatException('Invalid Sungshin date');
        }
        return v;
      }

      var start = date(ranges.first, year);
      if (start.month > month) {
        start = date(ranges.first, year - 1);
      }
      var last = date(ranges.last, start.year);
      if (last.month < start.month) {
        last = date(ranges.last, start.year + 1);
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected Sungshin period');
      }
      events.add(
        AcademicEvent(
          sourceId: id[1]!,
          title: title,
          start: start,
          end: end,
          url: 'https://www.sungshin.ac.kr/main_kor/10999/subview.do',
        ),
      );
    }
    return events;
  }

  @override
  void close() => _client.close();
}
