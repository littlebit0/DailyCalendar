import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// The official undergraduate calendar publishes a complete March–February
/// table per academic year with row-spanning month headings.
class KunsanAcademicSource implements AcademicSource {
  KunsanAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kunsan';
  @override
  String get name => '국립군산대학교';
  @override
  Uri get website => Uri.https('www.kunsan.ac.kr', '/index.kunsan', {
    'menuCd': 'DOM_000000103001001000',
    'sso': 'ok',
  });

  // The official 2025 table publishes 10/30 ~ 10/02 for one row, so only
  // academic years from 2026 are imported (user decision, 2026-10-24).
  static const firstAcademicYear = 2026;

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    if (year < firstAcademicYear) {
      throw const FormatException('Unsupported kunsan academic year');
    }
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [
      if (year - 1 >= firstAcademicYear) year - 1,
      year,
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                ...website.queryParameters,
                'sYear': '$selectedYear',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
        requestedYear: year,
      )) {
        if (!event.start.isBefore(DateTime(year + 1)) ||
            !event.end.isAfter(DateTime(year))) {
          continue;
        }
        final previous = events[event.sourceId];
        if (previous != null &&
            jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting kunsan event');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty kunsan calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int academicYear, {
    int? requestedYear,
  }) {
    final document = html.parse(body);
    final tables = document
        .querySelectorAll('table.ctable02')
        .where(
          (t) =>
              t.querySelector('caption')?.text.trim() ==
              '$academicYear학년도 학부 학사 일정의 월, 일정, 내용, 비고를 안내하는 목록입니다.',
        )
        .toList();
    if (tables.length != 1) {
      throw const FormatException('Unexpected annual table selection');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    int? month;
    for (final row in tables.single.querySelectorAll('tbody > tr')) {
      for (final heading in row.querySelectorAll('th')) {
        final text = heading.text.replaceAll(RegExp(r'\s+'), '');
        if (RegExp(r'^[12]학기$').hasMatch(text)) {
          continue;
        }
        final match = RegExp(r'^(?:(\d{4})년)?(\d{1,2})월$').firstMatch(text);
        if (match == null) {
          throw const FormatException('Unknown calendar row heading');
        }
        month = int.parse(match[2]!);
        if (month < 1 ||
            month > 12 ||
            !months.add(month) ||
            (match[1] != null &&
                int.parse(match[1]!) != academicYear + (month < 3 ? 1 : 0))) {
          throw const FormatException('Invalid annual month coverage');
        }
      }
      final cells = row.querySelectorAll('td');
      if (month == null || cells.length != 3) {
        throw const FormatException('Incomplete calendar event row');
      }
      final title = cells[1].text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final year = academicYear + (month < 3 ? 1 : 0);
      final text = cells[0].text
          .replaceAll(RegExp(r'\([월화수목금토일]\)'), '')
          .replaceAll(RegExp(r'\s+'), '');
      final match = RegExp(
        r'^(\d{2})/(\d{2})(?:~(\d{2})/(\d{2}))?$',
      ).firstMatch(text);
      if (match == null) {
        throw const FormatException('Invalid Kunsan calendar date');
      }
      final startMonth = int.parse(match[1]!);
      final startDay = int.parse(match[2]!);
      final endMonth = match[3] == null ? startMonth : int.parse(match[3]!);
      final endDay = match[4] == null ? startDay : int.parse(match[4]!);
      // Same identity as earlier releases, so imported events keep their IDs.
      final sourceId = '$title:$year-$startMonth-$startDay';
      DateTime date(int y, int m, int d) {
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid calendar date');
        }
        return result;
      }

      final start = date(year, startMonth, startDay);
      final last = date(
        endMonth < startMonth ? year + 1 : year,
        endMonth,
        endDay,
      );
      // The preceding academic year is fetched for winter overlaps. Its
      // March–November entries wholly outside the requested calendar year
      // are not imported. Keep validating every potentially relevant range,
      // especially December and periods ending in the following year.
      if (requestedYear != null &&
          startMonth >= 3 &&
          startMonth <= 11 &&
          endMonth >= startMonth &&
          start.isBefore(DateTime(requestedYear)) &&
          last.isBefore(DateTime(requestedYear))) {
        continue;
      }
      if (title.isEmpty || startMonth != month || last.isBefore(start)) {
        throw FormatException(
          'Invalid calendar period: month $month, $start to $last, $title',
        );
      }
      if (events.containsKey(sourceId)) {
        throw const FormatException('Duplicate calendar event identity');
      }
      events[sourceId] = AcademicEvent(
        sourceId: sourceId,
        title: title,
        start: start,
        end: DateTime(last.year, last.month, last.day + 1),
        url:
            'https://www.kunsan.ac.kr/index.kunsan?menuCd=DOM_000000103001001000&sYear=$academicYear&sso=ok',
      );
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete annual undergraduate calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
