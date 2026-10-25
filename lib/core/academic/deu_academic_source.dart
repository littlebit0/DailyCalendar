import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class DeuAcademicSource implements AcademicSource {
  DeuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'deu';
  @override
  String get name => '동의대학교';
  @override
  Uri get website => Uri.https('www.deu.ac.kr', '/www/scheduleList.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final academicYear in [year - 1, year]) {
      final response = await _client
          .get(website.replace(queryParameters: {'schYear': '$academicYear'}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('DEU calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty DEU calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document.querySelector('.calendar-select .subject')?.text.trim() !=
        '$academicYear년') {
      throw const FormatException('Unexpected DEU academic year');
    }
    final semesters = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final table in document.querySelectorAll('table.tbl-basic-dleft')) {
      final heading = table.querySelector('caption')?.text.trim() ?? '';
      final term = RegExp(
        r'^(\d{4})년 ([12])학기 날짜별 내용으로 구성$',
      ).firstMatch(heading);
      if (term == null) {
        continue; // Other university tables share the same visual class.
      }
      if (term[1] != '$academicYear' || !semesters.add(int.parse(term[2]!))) {
        throw const FormatException('Invalid DEU semester coverage');
      }
      for (final row in table.querySelectorAll('tbody tr')) {
        final dateText = row.querySelector('th')?.text.trim() ?? '';
        final title = row.querySelector('td')?.text.trim() ?? '';
        final range = RegExp(
          r'^(\d{1,2})월 (\d{1,2})(?:일)?(?:\s*~\s*(?:(\d{1,2})월 )?(\d{1,2}))?일$',
        ).firstMatch(dateText);
        if (range == null || title.isEmpty) {
          throw const FormatException('Invalid DEU event');
        }
        final m = int.parse(range[1]!);
        final lastMonth = int.tryParse(range[3] ?? '') ?? m;
        DateTime date(int month, int day) {
          final year = academicYear + (month <= 2 ? 1 : 0);
          final result = DateTime(year, month, day);
          if (result.year != year ||
              result.month != month ||
              result.day != day) {
            throw const FormatException('Invalid DEU date');
          }
          return result;
        }

        final start = date(m, int.parse(range[2]!));
        final last = date(lastMonth, int.tryParse(range[4] ?? '') ?? start.day);
        if (last.isBefore(start)) {
          throw const FormatException('Invalid DEU period');
        }
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
                'https://www.deu.ac.kr/www/scheduleList.do?schYear=$academicYear',
          ),
        );
      }
    }
    if (semesters.length != 2 || events.isEmpty) {
      throw const FormatException('Incomplete DEU calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
