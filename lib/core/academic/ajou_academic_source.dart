import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// The undergraduate column of Ajou's March–February academic calendar.
class AjouAcademicSource implements AcademicSource {
  AjouAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'ajou';
  @override
  String get name => '아주대학교';
  @override
  Uri get website => Uri.https('www.ajou.ac.kr', '/kr/bachelor/schedule.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final academicYear in [year - 1, year]) {
      final response = await _client
          .get(
            website.replace(
              queryParameters: {'mode': 'userList', 'year': '$academicYear'},
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Ajou academic calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear).where(
          (event) =>
              event.start.isBefore(DateTime(year + 1)) &&
              event.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) throw const FormatException('Empty Ajou calendar');
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document.querySelector('.b-cal-day-box span')?.text.trim() !=
        '$academicYear') {
      throw const FormatException('Unexpected Ajou academic year');
    }
    final events = <AcademicEvent>[];
    final occurrences = <String, int>{};
    final months = <int>{};
    for (final month in document.querySelectorAll('.b-cal-list-box > div')) {
      final label = month.children
          .where((e) => e.localName == 'p')
          .firstOrNull
          ?.text;
      if (label == null) continue; // Column headers are not month sections.
      final match = RegExp(
        r'^\s*(?:(\d{4})\.\s*)?(\d{1,2})월\s*$',
      ).firstMatch(label);
      if (match == null) throw const FormatException('Invalid Ajou month');
      final y = int.tryParse(match.group(1) ?? '') ?? academicYear;
      final m = int.parse(match.group(2)!);
      if (m < 1 || m > 12 || y != (m <= 2 ? academicYear + 1 : academicYear)) {
        throw const FormatException('Invalid Ajou academic month');
      }
      months.add(m);
      for (final row in month.querySelectorAll('.b-cal-wrap')) {
        final titles = row.querySelectorAll('.b-cal-undergrad > li');
        if (titles.isEmpty) continue; // Graduate-only events are separate.
        final range = row.querySelector('.b-cal-date')?.text.trim().split('~');
        if (range == null || range.isEmpty || range.length > 2) {
          throw const FormatException('Missing Ajou event dates');
        }
        final start = _date(range.first, y, m);
        final last = range.length == 1 ? start : _date(range.last, y, m);
        if (last.isBefore(start)) {
          throw const FormatException('Invalid Ajou period');
        }
        for (final element in titles) {
          final title = element.text
              .replaceFirst(RegExp(r'^\s*\[학부\]\s*'), '')
              .trim();
          if (title.isEmpty) throw const FormatException('Missing Ajou title');
          final key = '$academicYear:$title';
          final occurrence = occurrences.update(
            key,
            (n) => n + 1,
            ifAbsent: () => 0,
          );
          events.add(
            AcademicEvent(
              sourceId: '$key:$occurrence',
              title: title,
              start: start,
              end: DateTime(last.year, last.month, last.day + 1),
              url:
                  'https://www.ajou.ac.kr/kr/bachelor/schedule.do?mode=userList&year=$academicYear',
            ),
          );
        }
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Ajou annual calendar');
    }
    return events;
  }

  static DateTime _date(String text, int year, int month) {
    final match = RegExp(
      r'^\s*(?:(?:(\d{2}|\d{4})\.)?(\d{1,2})\.)?(\d{1,2})\([월화수목금토일]\)\s*$',
    ).firstMatch(text);
    if (match == null) throw const FormatException('Invalid Ajou date');
    var y = int.tryParse(match.group(1) ?? '') ?? year;
    if (y < 100) y += (year ~/ 100) * 100;
    final m = int.tryParse(match.group(2) ?? '') ?? month;
    final d = int.parse(match.group(3)!);
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) {
      throw const FormatException('Invalid Ajou calendar day');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
