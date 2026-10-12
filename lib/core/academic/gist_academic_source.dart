import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class GistAcademicSource implements AcademicSource {
  GistAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'gist';
  @override
  String get name => '광주과학기술원';
  @override
  Uri get website => Uri.https('www.gist.ac.kr', '/kr/html/sub05/0501.html');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          website,
          body: {
            'site_dvs_cd': 'kr',
            'menu_dvs_cd': '0501',
            'groups': 'university',
            'year': '$year',
            'month': '',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('GIST academic calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('.carte_top h2 em')?.text.trim() != '$year') {
      throw const FormatException('Unexpected GIST calendar year');
    }
    final records = <String, AcademicEvent>{};
    final months = <int>{};
    for (final section in document.querySelectorAll('.schlst')) {
      final label = section.querySelector('.ctrmm strong')?.text.trim() ?? '';
      final match = RegExp(r'^(\d{2})월$').firstMatch(label);
      if (match == null) throw const FormatException('Invalid GIST month');
      final month = int.parse(match.group(1)!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid GIST month coverage');
      }
      for (final row in section.querySelectorAll('.schtxt li')) {
        final title = row.querySelector('span')?.text.trim() ?? '';
        final range = row.querySelector('b')?.text.trim().split('~');
        if (title.isEmpty ||
            range == null ||
            range.isEmpty ||
            range.length > 2) {
          throw const FormatException('Incomplete GIST event');
        }
        final first = _monthDay(range.first);
        final startYear = first.$1 > month ? year - 1 : year;
        final start = _date(startYear, first);
        final finalDay = range.length == 1 ? first : _monthDay(range.last);
        final last = _date(
          finalDay.$1 < first.$1 ? startYear + 1 : startYear,
          finalDay,
        );
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Invalid GIST period');
        }
        // Repeated ranges occur in every overlapping month, not separate events.
        final identity = '$start:$title';
        final event = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: end,
          url: 'https://www.gist.ac.kr/kr/html/sub05/0501.html',
        );
        if (records[identity] case final previous?) {
          if (previous.end != end) {
            throw const FormatException('Conflicting GIST event');
          }
        }
        records[identity] = event;
      }
    }
    if (months.length != 12 || records.isEmpty) {
      throw const FormatException('Incomplete GIST annual calendar');
    }
    return records.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static (int, int) _monthDay(String text) {
    final match = RegExp(
      r'^\s*(\d{2})-(\d{2})\([월화수목금토일]\)\s*$',
    ).firstMatch(text);
    if (match == null) throw const FormatException('Invalid GIST date');
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  static DateTime _date(int year, (int, int) value) {
    final date = DateTime(year, value.$1, value.$2);
    if (date.year != year || date.month != value.$1 || date.day != value.$2) {
      throw const FormatException('Invalid GIST calendar day');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
