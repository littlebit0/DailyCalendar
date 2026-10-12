import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Seoul and WISE publish separate calendars, with explicit dates in every row.
class DonggukAcademicSource implements AcademicSource {
  DonggukAcademicSource({this.wise = false, http.Client? client})
    : _client = client ?? http.Client();

  final bool wise;
  final http.Client _client;

  @override
  String get id => wise ? 'dongguk-wise' : 'dongguk-seoul';
  @override
  String get name => wise ? '동국대학교 WISE캠퍼스' : '동국대학교 서울캠퍼스';
  @override
  Uri get website => Uri.https(
    wise ? 'wise.dongguk.ac.kr' : 'www.dongguk.edu',
    '/schedule/detail',
    {'schedule_info_seq': '22'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    // Seoul publishes March–February; WISE publishes January–December.
    // Reading the previous page also retains winter periods spanning January.
    for (final pageYear in [year - 1, year]) {
      if (pageYear == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'schedule_info_seq': '22',
                'schedule_start_date': '$pageYear',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Dongguk calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), pageYear, wise: wise).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    // WISE may repeat December's spanning event in January's calendar.
    final unique = <String, AcademicEvent>{};
    for (final event in events) {
      final key = '${event.title}:${event.start}:${event.end}';
      unique[key] = event;
    }
    if (unique.isEmpty) {
      throw const FormatException('Empty Dongguk calendar');
    }
    return unique.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int pageYear, {
    bool wise = false,
  }) {
    final document = html.parse(body);
    final heading = document
        .querySelector('.cont_tit')
        ?.text
        .replaceAll(RegExp(r'\s+'), '');
    if ((wise
            ? heading != '$pageYear학년도학사일정'
            : !RegExp(r'^\d{4}학년도교내일정$').hasMatch(heading ?? '')) ||
        document
                .querySelector('input[name=schedule_info_seq]')
                ?.attributes['value'] !=
            '22') {
      throw const FormatException('Unexpected Dongguk calendar year');
    }
    final months = <int>{};
    final events = <AcademicEvent>[];
    final occurrences = <String, int>{};
    DateTime date(String value) {
      final match = RegExp(
        r'^\s*(\d{4})\.(\d{2})\.(\d{2})\.\s*$',
      ).firstMatch(value);
      if (match == null) throw const FormatException('Invalid Dongguk date');
      final y = int.parse(match[1]!);
      final m = int.parse(match[2]!);
      final d = int.parse(match[3]!);
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        throw const FormatException('Invalid Dongguk date');
      }
      return result;
    }

    for (final row in document.querySelectorAll(
      '.schedule table.tbl tbody > tr',
    )) {
      final header = row.querySelector('th');
      final cells = row.querySelectorAll('td');
      if (header == null || cells.length != 2) {
        throw const FormatException('Invalid Dongguk calendar row');
      }
      final m = int.tryParse(header.querySelector('p')?.text.trim() ?? '');
      final y = int.tryParse(header.querySelector('span')?.text.trim() ?? '');
      if (m == null ||
          m < 1 ||
          m > 12 ||
          y == null ||
          y != pageYear + (!wise && m <= 2 ? 1 : 0)) {
        throw const FormatException('Unexpected Dongguk calendar month');
      }
      months.add(m);
      final range = cells[0].text.trim().split('~');
      if (range.length > 2) {
        throw const FormatException('Invalid Dongguk range');
      }
      final start = date(range.first);
      final last = date(range.last);
      if (start.year != y || start.month != m || last.isBefore(start)) {
        throw const FormatException('Unexpected Dongguk period');
      }
      final department = cells[1].querySelector('p')?.text.trim() ?? '';
      final link = cells[1].querySelector('a.schedule_btn')?.attributes['href'];
      for (final extra in cells[1].querySelectorAll('p, a.schedule_btn')) {
        extra.remove();
      }
      final title = cells[1].text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.isEmpty) throw const FormatException('Missing Dongguk title');
      // Graduate-only entries are distinct from joint undergraduate entries.
      // Undergraduate combined-degree applications remain included.
      if (title.contains('대학원') ||
          (department.contains('대학원') &&
              !department.contains('/') &&
              !title.contains('학·석사'))) {
        continue;
      }
      final key = '$title:${start.toIso8601String()}';
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
          url: link == null
              ? 'https://${wise ? 'wise.dongguk.ac.kr' : 'www.dongguk.edu'}/schedule/detail?schedule_info_seq=22&schedule_start_date=$pageYear'
              : Uri.https(
                  wise ? 'wise.dongguk.ac.kr' : 'www.dongguk.edu',
                  '/',
                ).resolve(link).toString(),
        ),
      );
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Dongguk calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
