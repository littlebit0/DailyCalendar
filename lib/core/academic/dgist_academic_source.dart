import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class DgistAcademicSource implements AcademicSource {
  DgistAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'dgist';
  @override
  String get name => '대구경북과학기술원';
  @override
  Uri get website => Uri.https(
    'www.dgist.ac.kr',
    '/prog/schafsSchdul/kor/sub05_01_01/list.do',
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // The official server accepts its published year parameter via GET.
      // Normal Dart POST connections reset, whereas GET verifies TLS normally.
      final response = await _client
          .get(
            website.replace(queryParameters: {'searchYear': '$selected'}),
            headers: {
              'User-Agent': 'Mozilla/5.0 DailyCalendar-source-validation',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('DGIST calendar unavailable');
      }
      for (final e in parse(utf8.decode(response.bodyBytes), selected)) {
        if (e.start.isBefore(DateTime(year + 1)) &&
            e.end.isAfter(DateTime(year))) {
          events[e.sourceId] = e;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published DGIST calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    final sections = document.querySelectorAll('.cal_list.panel');
    if (sections.length != 12 ||
        document
                .querySelector('#searchYear option[selected]')
                ?.attributes['value'] !=
            '$year') {
      throw const FormatException('Unexpected DGIST calendar year');
    }
    final months = <int>{};
    final result = <AcademicEvent>[];
    DateTime date(int y, int m, int d) {
      final v = DateTime(y, m, d);
      if (v.year != y || v.month != m || v.day != d) {
        throw const FormatException('Invalid DGIST date');
      }
      return v;
    }

    for (final section in sections) {
      final match = RegExp(
        r'^(\d{2})월$',
      ).firstMatch(section.querySelector('.ctrmm strong')?.text.trim() ?? '');
      if (match == null ||
          section.querySelector('.ctrmm span')?.text.trim() != '$year년') {
        throw const FormatException('Invalid DGIST month');
      }
      final month = int.parse(match[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Duplicate DGIST month');
      }
      for (final row in section.querySelectorAll('.sch_box > div.li')) {
        final raw = (row.querySelector('b')?.text ?? '').replaceAll(
          RegExp(r'\s+'),
          '',
        );
        final r = RegExp(
          r'^(\d{2})\.(\d{2})(?:~(\d{2})\.(\d{2}))?$',
        ).firstMatch(raw);
        final title = (row.querySelector('span.subject')?.text ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (r == null || title.isEmpty) {
          throw const FormatException('Invalid DGIST event');
        }
        final sm = int.parse(r[1]!);
        final start = date(year - (sm > month ? 1 : 0), sm, int.parse(r[2]!));
        final em = r[3] == null ? sm : int.parse(r[3]!);
        final last = r[3] == null
            ? start
            : date(start.year + (em < sm ? 1 : 0), em, int.parse(r[4]!));
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected DGIST period');
        }
        result.add(
          AcademicEvent(
            sourceId:
                '${start.toIso8601String()}:${last.toIso8601String()}:$title',
            title: title,
            start: start,
            end: end,
            url:
                'https://www.dgist.ac.kr/prog/schafsSchdul/kor/sub05_01_01/list.do?searchYear=$year',
          ),
        );
      }
    }
    if (result.isEmpty) {
      throw const FormatException('Empty DGIST calendar');
    }
    return result;
  }

  @override
  void close() => _client.close();
}
