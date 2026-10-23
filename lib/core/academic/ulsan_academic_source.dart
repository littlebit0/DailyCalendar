import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class UlsanAcademicSource implements AcademicSource {
  UlsanAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'ulsan';
  @override
  String get name => '울산대학교';
  @override
  Uri get website =>
      Uri.https('www.ulsan.ac.kr', '/kor/CMS/ScheduleMgr/YearList.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    // Retain winter courses/vacations that begin the previous December.
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'mCode': 'MN080',
                'calendar_year': '$selectedYear',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Ulsan calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), selectedYear).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Ulsan calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('h3.sch-date')?.text.trim() != '$year년') {
      throw const FormatException('Unexpected Ulsan year');
    }
    final months = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final section in document.querySelectorAll('.sch-monlist-wr')) {
      final caption =
          section.querySelector('table.cal-tbl caption')?.text.trim() ?? '';
      final match = RegExp(r'^(\d{4})년 (\d{1,2})월 학사일정').firstMatch(caption);
      if (match == null || int.parse(match[1]!) != year) {
        throw const FormatException('Invalid Ulsan month heading');
      }
      final month = int.parse(match[2]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Ulsan month coverage');
      }
      for (final row in section.querySelectorAll('.daily-li')) {
        if (row.classes.contains('no-data') &&
            row.text.trim() == '등록된 일정이 없습니다.') {
          continue;
        }
        final range = row.querySelector('.date-core')?.text.trim().split('∼');
        final title = row.querySelector('.body-core')?.text.trim() ?? '';
        if (range == null ||
            range.isEmpty ||
            range.length > 2 ||
            title.isEmpty) {
          throw const FormatException('Invalid Ulsan event');
        }
        DateTime date(String text, int y) {
          final day = RegExp(
            r'^\s*(\d{2})\.\s*(\d{2})\([월화수목금토일]\)\s*$',
          ).firstMatch(text);
          if (day == null) {
            throw const FormatException('Invalid Ulsan date');
          }
          final m = int.parse(day[1]!);
          final d = int.parse(day[2]!);
          final result = DateTime(y, m, d);
          if (result.year != y || result.month != m || result.day != d) {
            throw const FormatException('Invalid Ulsan date');
          }
          return result;
        }

        final start = date(range.first, year);
        var last = date(range.last, year);
        if (last.month < start.month) {
          last = date(range.last, year + 1);
        }
        if (start.month != month || last.isBefore(start)) {
          throw const FormatException('Conflicting Ulsan period');
        }
        final key = '$year:$title';
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
                'https://www.ulsan.ac.kr/kor/CMS/ScheduleMgr/YearList.do?mCode=MN080&calendar_year=$year',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Ulsan calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
