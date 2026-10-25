import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class JbnuAcademicSource implements AcademicSource {
  JbnuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'jbnu';
  @override
  String get name => '전북대학교';
  @override
  Uri get website =>
      Uri.https('www.jbnu.ac.kr', '/mobile/academic/schedule.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    // An anonymous page visit supplies the CSRF value and session cookie used
    // by the public annual-calendar UI. No university login is involved.
    final entry = await _client
        .get(website)
        .timeout(const Duration(seconds: 20));
    if (entry.statusCode != 200 || entry.bodyBytes.length > 8000000) {
      throw const FormatException('JBNU calendar unavailable');
    }
    final csrf = html
        .parse(utf8.decode(entry.bodyBytes))
        .querySelector('meta[name="_csrf"]')
        ?.attributes['content'];
    final setCookie = entry.headers['set-cookie'];
    if (csrf == null || csrf.isEmpty || setCookie == null) {
      throw const FormatException('JBNU public calendar session unavailable');
    }
    final cookies = RegExp(
      r'(?:^|,)\s*([^=;,\s]+)=([^;,]*)',
    ).allMatches(setCookie).map((m) => '${m[1]}=${m[2]}').join('; ');
    if (cookies.isEmpty) {
      throw const FormatException('JBNU anonymous cookie unavailable');
    }
    final events = <AcademicEvent>[];
    for (final (academicYear, semester) in [
      (year - 1, 2),
      (year, 1),
      (year, 2),
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = await _client
          .post(
            Uri.https(
              'www.jbnu.ac.kr',
              '/mobile/academic/schedule/dataAjax.do',
            ),
            headers: {'X-CSRF-Token': csrf, 'AJAX': 'true', 'Cookie': cookies},
            body: {
              'type': 'yearly',
              'acSemester': '$semester',
              'acYear': '$academicYear',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('JBNU annual calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear, semester).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) throw const FormatException('Empty JBNU calendar');
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int academicYear,
    int semester,
  ) {
    if (![1, 2].contains(semester) ||
        !RegExp("var semesterVal = '$semester';").hasMatch(body) ||
        !RegExp("var yearVal = '$academicYear';").hasMatch(body)) {
      throw const FormatException('Unexpected JBNU year or semester');
    }
    final document = html.parse(body);
    final events = <AcademicEvent>[];
    final months = <int>{};
    DateTime date(String value) {
      final match = RegExp(
        r'^\s*(\d{4})-(\d{2})-(\d{2})\s*$',
      ).firstMatch(value);
      if (match == null) throw const FormatException('Invalid JBNU date');
      final y = int.parse(match[1]!);
      final m = int.parse(match[2]!);
      final d = int.parse(match[3]!);
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        throw const FormatException('Invalid JBNU date');
      }
      return result;
    }

    for (final monthBlock in document.querySelectorAll(
      'ul.com-brd-list-07 > li',
    )) {
      final m = int.tryParse(
        (monthBlock.attributes['id'] ?? '').replaceFirst('calendar-', ''),
      );
      if (m == null ||
          !(semester == 1 ? [3, 4, 5, 6, 7, 8] : [9, 10, 11, 12, 1, 2])
              .contains(m)) {
        throw const FormatException('Unexpected JBNU month');
      }
      months.add(m);
      for (final row in monthBlock.querySelectorAll('dl.academic > div')) {
        final dt = row.querySelector('dt');
        final dd = row.querySelector('dd');
        if (dt == null || dd == null) {
          throw const FormatException('Invalid JBNU row');
        }
        final range = dt.text.trim().split('~');
        if (range.length > 2) throw const FormatException('Invalid JBNU range');
        final start = date(range.first);
        final last = date(range.last);
        if (start.year != academicYear + (m <= 2 ? 1 : 0) ||
            start.month != m ||
            last.isBefore(start)) {
          throw const FormatException('Unexpected JBNU period');
        }
        // Some rows combine an undergraduate opening and graduate exam.
        // Retain the undergraduate portion instead of dropping the whole row.
        final title = dd.text
            .trim()
            .split(',')
            .map((s) => s.trim())
            .where((s) => !s.contains('대학원'))
            .join(', ');
        if (title.isEmpty) continue;
        events.add(
          AcademicEvent(
            sourceId: '$title:${start.toIso8601String()}',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url: 'https://www.jbnu.ac.kr/mobile/academic/schedule.do',
          ),
        );
      }
    }
    if (months.length != 6 || events.isEmpty) {
      throw const FormatException('Incomplete JBNU semester');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
