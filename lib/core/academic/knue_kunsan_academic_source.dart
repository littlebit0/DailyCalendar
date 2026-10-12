import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// The two official undergraduate calendars publish complete March–February
/// tables with row-spanning month headings, but distinct date/identity formats.
class KnueKunsanAcademicSource implements AcademicSource {
  KnueKunsanAcademicSource.knue({http.Client? client})
    : _knue = true,
      _client = client ?? http.Client();
  KnueKunsanAcademicSource.kunsan({http.Client? client})
    : _knue = false,
      _client = client ?? http.Client();
  final bool _knue;
  final http.Client _client;
  @override
  String get id => _knue ? 'knue' : 'kunsan';
  @override
  String get name => _knue ? '한국교원대학교' : '국립군산대학교';
  @override
  Uri get website => _knue
      ? Uri.https('www.knue.ac.kr', '/www/selectSchdleWebList.do', {
          'key': '542',
        })
      : Uri.https('www.kunsan.ac.kr', '/index.kunsan', {
          'menuCd': 'DOM_000000103001001000',
          'sso': 'ok',
        });

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [year - 1, year]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                ...website.queryParameters,
                if (_knue) ...{
                  'searchY': '$selectedYear',
                  'searchM': '03',
                  'searchD': '01',
                } else
                  'sYear': '$selectedYear',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw FormatException('$id annual calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
        knue: _knue,
        requestedYear: year,
      )) {
        if (!event.start.isBefore(DateTime(year + 1)) ||
            !event.end.isAfter(DateTime(year))) {
          continue;
        }
        final previous = events[event.sourceId];
        if (previous != null &&
            jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
          throw FormatException('Conflicting $id event');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw FormatException('Empty $id calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int academicYear, {
    required bool knue,
    int? requestedYear,
  }) {
    final document = html.parse(body);
    final tables = document
        .querySelectorAll(knue ? 'table.more_year' : 'table.ctable02')
        .where(
          (t) =>
              t.querySelector('caption')?.text.trim() ==
              (knue
                  ? '$academicYear년 전체 일정표 - 학기, 월별, 기간, 일정 순으로 안내합니다.'
                  : '$academicYear학년도 학부 학사 일정의 월, 일정, 내용, 비고를 안내하는 목록입니다.'),
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
      if (month == null || cells.length != (knue ? 2 : 3)) {
        throw const FormatException('Incomplete calendar event row');
      }
      final title = cells[1].text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final year = academicYear + (month < 3 ? 1 : 0);
      late final int startMonth, startDay, endMonth, endDay;
      late final String sourceId, url;
      if (knue) {
        int part(String selector) {
          final value = int.tryParse(
            cells[0].querySelector(selector)?.text.trim() ?? '',
          );
          if (value == null) {
            throw const FormatException('Invalid KNUE calendar date');
          }
          return value;
        }

        startMonth = part('.start .month');
        startDay = part('.start .days');
        endMonth = cells[0].querySelector('.end') == null
            ? startMonth
            : part('.end .month');
        endDay = cells[0].querySelector('.end') == null
            ? startDay
            : part('.end .days');
        final href = cells[1].querySelector('a.more_link')?.attributes['href'];
        final detail = href == null ? null : Uri.parse(href);
        sourceId = detail?.queryParameters['schdleNum'] ?? '';
        if (detail?.path != 'selectSchdleWebView.do' ||
            detail?.queryParameters['key'] != '542' ||
            int.tryParse(sourceId) == null) {
          throw const FormatException('Invalid KNUE event identity');
        }
        url = Uri.https('www.knue.ac.kr', '/www/selectSchdleWebView.do', {
          'key': '542',
          'schdleNum': sourceId,
        }).toString();
      } else {
        final text = cells[0].text
            .replaceAll(RegExp(r'\([월화수목금토일]\)'), '')
            .replaceAll(RegExp(r'\s+'), '');
        final match = RegExp(
          r'^(\d{2})/(\d{2})(?:~(\d{2})/(\d{2}))?$',
        ).firstMatch(text);
        if (match == null) {
          throw const FormatException('Invalid Kunsan calendar date');
        }
        startMonth = int.parse(match[1]!);
        startDay = int.parse(match[2]!);
        endMonth = match[3] == null ? startMonth : int.parse(match[3]!);
        endDay = match[4] == null ? startDay : int.parse(match[4]!);
        sourceId = '$title:$year-$startMonth-$startDay';
        url =
            'https://www.kunsan.ac.kr/index.kunsan?menuCd=DOM_000000103001001000&sYear=$academicYear&sso=ok';
      }
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
      // Joint university/graduate enrolment applies to undergraduates too.
      if (knue && title.contains('대학원') && !RegExp(r'대학[·ㆍ]').hasMatch(title)) {
        continue;
      }
      if (events.containsKey(sourceId)) {
        throw const FormatException('Duplicate calendar event identity');
      }
      events[sourceId] = AcademicEvent(
        sourceId: sourceId,
        title: title,
        start: start,
        end: DateTime(last.year, last.month, last.day + 1),
        url: url,
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
