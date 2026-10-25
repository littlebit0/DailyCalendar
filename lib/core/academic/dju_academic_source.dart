import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class DjuAcademicSource implements AcademicSource {
  DjuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'dju';
  @override
  String get name => '대전대학교';
  @override
  Uri get website => Uri.https(
    'www.dju.ac.kr',
    '/dju/sv/schdulView/schdulCalendarView.do',
    {'mi': '1166'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    // Each academic year runs March to February, so January and February
    // belong to the previous academic year's calendar.
    final records = <AcademicCalendarRecord>[];
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.dju.ac.kr', '/dju/sv/schdulView/calendar.do'),
            body: {
              'mi': '1166',
              'sysId': 'dju',
              'year': '$selected',
              'srchYear': '$selected',
              'firstDay': '${selected}0301',
              // Last day of February, 29 in leap years.
              'endDay': '${selected + 1}02${DateTime(selected + 1, 3, 0).day}',
              'section': '3',
            },
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 25));
      checkAcademicResponse(response);
      records.addAll(parse(utf8.decode(response.bodyBytes), selected));
    }
    // Same IDs as earlier versions: start date and title. Only rows sharing
    // both but ending differently also carry their final day.
    String key(AcademicCalendarRecord r) =>
        '${r.start.toIso8601String()}:${r.title}';
    final ends = <String, Set<DateTime>>{};
    for (final r in records) {
      (ends[key(r)] ??= {}).add(r.last);
    }
    final events = <String, AcademicEvent>{};
    for (final r in records) {
      final end = DateTime(r.last.year, r.last.month, r.last.day + 1);
      if (!r.start.isBefore(DateTime(year + 1)) ||
          !end.isAfter(DateTime(year))) {
        continue;
      }
      final id = ends[key(r)]!.length > 1
          ? '${r.start.toIso8601String()}:${r.last.toIso8601String()}:${r.title}'
          : key(r);
      events[id] = AcademicEvent(
        sourceId: id,
        title: r.title,
        start: r.start,
        end: end,
        url: website.toString(),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('No published DJU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Every distinct published row of one academic year. The page repeats all
  /// twelve month tables for mobile, and periods crossing a month boundary
  /// appear under both months.
  static List<AcademicCalendarRecord> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document.querySelector('h4[in-data]')?.attributes['in-data'] !=
        '$academicYear') {
      throw const FormatException('Unexpected DJU year');
    }
    final months = <int>{};
    final records = <String, AcademicCalendarRecord>{};
    for (final table in document.querySelectorAll(
      '.schedule_calendar > table',
    )) {
      final heading = RegExp(
        r'^(\d{4})년 (\d{1,2})월 학사일정을',
      ).firstMatch(table.querySelector('caption')?.text.trim() ?? '');
      if (heading == null) {
        throw const FormatException('Missing DJU month');
      }
      final y = int.parse(heading[1]!), month = int.parse(heading[2]!);
      final expectedYear = month >= 3 ? academicYear : academicYear + 1;
      if (month < 1 || month > 12 || y != expectedYear) {
        throw const FormatException('Invalid DJU month');
      }
      months.add(month);
      for (final row in table.querySelectorAll('tbody tr')) {
        final cells = row.querySelectorAll('td');
        final title = cells.length == 2
            ? cells.last.text.replaceAll(RegExp(r'\s+'), ' ').trim()
            : '';
        final range = RegExp(
          r'^(\d{2})-(\d{2})(?:\s*~\s*(\d{2})-(\d{2}))?$',
        ).firstMatch(cells.isEmpty ? '' : cells.first.text.trim());
        if (title.isEmpty || range == null) {
          throw const FormatException('Invalid DJU event row');
        }
        DateTime date(int year, String m, String d) {
          final month = int.parse(m), day = int.parse(d);
          final value = DateTime(year, month, day);
          if (value.month != month || value.day != day) {
            throw const FormatException('Invalid DJU date');
          }
          return value;
        }

        final startMonth = int.parse(range[1]!);
        final start = date(
          startMonth > month ? y - 1 : y,
          range[1]!,
          range[2]!,
        );
        var last = start;
        if (range[3] != null) {
          final endMonth = int.parse(range[3]!);
          last = date(
            endMonth < startMonth ? start.year + 1 : start.year,
            range[3]!,
            range[4]!,
          );
        }
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(y, month + 1)) ||
            last.isBefore(DateTime(y, month))) {
          throw const FormatException('Unexpected DJU period');
        }
        records['${start.toIso8601String()}:${last.toIso8601String()}:$title'] =
            (title: title, start: start, last: last);
      }
    }
    if (months.length != 12 || records.isEmpty) {
      throw const FormatException('Incomplete DJU calendar');
    }
    return records.values.toList();
  }

  @override
  void close() => _client.close();
}
