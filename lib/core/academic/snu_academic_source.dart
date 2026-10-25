import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// SNU publishes March through the following February on its official page.
class SnuAcademicSource implements AcademicSource {
  SnuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  String get id => 'snu';
  @override
  String get name => '서울대학교';
  @override
  Uri get website =>
      Uri.https('www.snu.ac.kr', '/academics/resources/calendar');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    // Fetch sequentially: January/February belongs to the preceding academic
    // year. Each page must identify its year so a fallback cannot look complete.
    for (final academicYear in [year - 1, year]) {
      final response = await _client
          .get(website.replace(queryParameters: {'year': '$academicYear'}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('SNU academic source unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear).where(
          (event) =>
              event.start.isBefore(DateTime(year + 1)) &&
              event.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('No published SNU academic calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static final _graduateOnly = RegExp(r'^(?!.*(?:학부|대학/)).*대학원');

  static List<AcademicEvent> parse(String body, int academicYear) {
    final section = html.parse(body).querySelector('section.calendar');
    if (section == null ||
        section.querySelector('.this-year h3')?.text.trim() !=
            '$academicYear학년도') {
      throw const FormatException('Unexpected SNU academic year');
    }
    final result = <AcademicEvent>[];
    final occurrences = <String, int>{};
    final seenMonths = <int>{};
    for (final month in section.querySelectorAll('.work-wrap')) {
      final label = month.querySelector('.month-text')?.text.trim() ?? '';
      final match = RegExp(r'^(?:(\d{4})년\s*)?(\d{1,2})월$').firstMatch(label);
      if (match == null) throw const FormatException('Invalid SNU month');
      final year = int.tryParse(match.group(1) ?? '') ?? academicYear;
      final monthNumber = int.parse(match.group(2)!);
      // An academic year runs March to the following February. Whether SNU
      // ever omits a month without events is not observed (2021-2026 always
      // list all twelve), so omission is accepted; repeated or out-of-window
      // sections are not.
      final inWindow = match.group(1) == null
          ? monthNumber >= 3 && monthNumber <= 12
          : year == academicYear + 1 && monthNumber >= 1 && monthNumber <= 2;
      if (!inWindow || !seenMonths.add(year * 100 + monthNumber)) {
        throw const FormatException('Invalid SNU month');
      }
      for (final work in month.querySelectorAll('.work')) {
        final title = work.querySelector('.desc')?.text.trim() ?? '';
        final range = work.querySelector('.day')?.text.trim().split('~');
        if (title.isEmpty ||
            range == null ||
            range.isEmpty ||
            range.length > 2) {
          throw const FormatException('Incomplete SNU academic event');
        }
        // 사용자 결정(2026-10-24): 대학원 전용 행은 넣지 않는다. 원문이 제목에
        // "대학원 후기모집 신입생 등록"처럼 대상을 대학원으로만 적은 행을 제외하고,
        // 학부와 함께 적은 행은 유지한다.
        if (_graduateOnly.hasMatch(title)) continue;
        final start = _date(range.first, year, monthNumber);
        final last = range.length == 1
            ? start
            : _date(range.last, year, monthNumber);
        if (last.isBefore(start)) {
          throw const FormatException('Invalid SNU period');
        }
        final identity = '$academicYear:$title';
        final occurrence = occurrences.update(
          identity,
          (value) => value + 1,
          ifAbsent: () => 0,
        );
        result.add(
          AcademicEvent(
            sourceId: '$identity:$occurrence',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.snu.ac.kr/academics/resources/calendar?year=$academicYear',
          ),
        );
      }
    }
    if (result.isEmpty) {
      throw const FormatException('Empty SNU academic calendar');
    }
    return result;
  }

  static DateTime _date(String value, int year, int month) {
    final match = RegExp(
      r'^\s*(?:(?:(\d{4})\.)?(\d{1,2})\.)?(\d{1,2})\.?\([월화수목금토일]\)\s*$',
    ).firstMatch(value);
    if (match == null) throw const FormatException('Invalid SNU academic date');
    final y = int.tryParse(match.group(1) ?? '') ?? year;
    final m = int.tryParse(match.group(2) ?? '') ?? month;
    final d = int.parse(match.group(3)!);
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) {
      throw const FormatException('Invalid SNU academic date');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
