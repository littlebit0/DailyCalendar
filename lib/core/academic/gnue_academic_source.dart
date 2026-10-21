import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class GnueAcademicSource implements AcademicSource {
  GnueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _first = '4a9f18ab5c48fe8c015caa01ed5507e9';
  static const _second = '4a9f18ab5c48fe8c015caa0228a707eb';
  @override
  String get id => 'gnue';
  @override
  String get name => '광주교육대학교';
  @override
  Uri get website =>
      Uri.https('www.gnue.ac.kr', '/index.9is', {'contentUid': _first});
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final result = <String, AcademicEvent>{};
    for (final (selected, semester) in [(year - 1, 2), (year, 1), (year, 2)]) {
      if (result.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'contentUid': semester == 1 ? _first : _second,
                'yyyy': '$selected',
              },
            ),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('GNUE calendar unavailable');
      }
      for (final e in parse(
        utf8.decode(response.bodyBytes),
        selected,
        semester,
      )) {
        if (e.start.isBefore(DateTime(year + 1)) &&
            e.end.isAfter(DateTime(year))) {
          result[e.sourceId] = e;
        }
      }
    }
    if (result.isEmpty) {
      throw const FormatException('No published GNUE calendar');
    }
    return result.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int semester) {
    if (semester != 1 && semester != 2) {
      throw const FormatException('Invalid GNUE semester');
    }
    final sections = html.parse(body).querySelectorAll('div.month_txt');
    if (sections.length != 6) {
      throw const FormatException('Incomplete GNUE semester');
    }
    final events = <AcademicEvent>[];
    DateTime date(int y, int m, int d) {
      final value = DateTime(y, m, d);
      if (value.year != y || value.month != m || value.day != d) {
        throw const FormatException('Invalid GNUE date');
      }
      return value;
    }

    for (var i = 0; i < 6; i++) {
      final expected = DateTime(year, (semester == 1 ? 3 : 9) + i);
      final heading = sections[i].querySelector('p.month_tit')?.text.trim();
      if (heading !=
          '${expected.year}년 ${expected.month.toString().padLeft(2, '0')}월') {
        throw const FormatException('Unexpected GNUE year/month');
      }
      for (final row in sections[i].querySelectorAll('ul > li')) {
        final span = row.querySelector('span');
        final raw = span?.text.replaceAll(RegExp(r'\s+'), '') ?? '';
        final match = RegExp(
          r'^(\d{2})\.(\d{2})(?:~(\d{2})\.(\d{2}))?$',
        ).firstMatch(raw);
        span?.remove();
        final title = row.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (match == null || title.isEmpty) {
          throw const FormatException('Invalid GNUE event');
        }
        final sm = int.parse(match[1]!);
        final start = date(
          expected.year - (sm > expected.month ? 1 : 0),
          sm,
          int.parse(match[2]!),
        );
        final em = match[3] == null ? sm : int.parse(match[3]!);
        final last = match[3] == null
            ? start
            : date(start.year + (em < sm ? 1 : 0), em, int.parse(match[4]!));
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(expected.year, expected.month + 1)) ||
            !end.isAfter(expected)) {
          throw const FormatException('Unexpected GNUE period');
        }
        events.add(
          AcademicEvent(
            sourceId:
                '${start.toIso8601String()}:${last.toIso8601String()}:$title',
            title: title,
            start: start,
            end: end,
            // The page this event was read from: its semester and year.
            url: Uri.https('www.gnue.ac.kr', '/index.9is', {
              'contentUid': semester == 1 ? _first : _second,
              'yyyy': '$year',
            }).toString(),
          ),
        );
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty GNUE semester');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
