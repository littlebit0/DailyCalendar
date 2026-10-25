import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KoreatechAcademicSource implements AcademicSource {
  KoreatechAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'koreatech';
  @override
  String get name => '한국기술교육대학교';
  @override
  Uri get website => Uri.https('www.koreatech.ac.kr', '/board.es', {
    'mid': 'a10501010000',
    'bid': '0006',
  });
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                ...website.queryParameters,
                'sel_date': '${selected}1001',
                'sel_month': '10',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Koreatech calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Koreatech calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document.querySelector('.year_area > div > strong')?.text.trim() !=
        '$academicYear') {
      throw const FormatException('Unexpected Koreatech year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in document.querySelectorAll('.CalendarList')) {
      final match = RegExp(
        r'^(\d{4})\. (\d{2})$',
      ).firstMatch(section.querySelector('h2 > strong')?.text.trim() ?? '');
      if (match == null) throw const FormatException('Missing Koreatech month');
      final year = int.parse(match[1]!);
      final month = int.parse(match[2]!);
      if (month < 1 ||
          month > 12 ||
          year != (month < 3 ? academicYear + 1 : academicYear) ||
          !months.add(month)) {
        throw const FormatException('Invalid Koreatech month');
      }
      for (final row in section.parent!.querySelectorAll(
        '.lst table tbody > tr',
      )) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) {
          throw const FormatException('Invalid Koreatech event');
        }
        final title = cells.last.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final range = cells.first.text.trim().split('~');
        if (title.isEmpty || range.length > 2) {
          throw const FormatException('Invalid Koreatech event');
        }
        DateTime date(String text, int y) {
          final m = RegExp(
            r'^\s*(\d{2})\.(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(text);
          if (m == null) throw const FormatException('Invalid Koreatech date');
          final mm = int.parse(m[1]!);
          final d = int.parse(m[2]!);
          final result = DateTime(y, mm, d);
          if (result.year != y || result.month != mm || result.day != d) {
            throw const FormatException('Invalid Koreatech date');
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
          throw const FormatException('Unexpected Koreatech period');
        }
        final identity =
            '${start.toIso8601String()}:${last.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: end,
          url: 'https://www.koreatech.ac.kr/board.es?bid=0006&mid=a10501010000',
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Koreatech calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
