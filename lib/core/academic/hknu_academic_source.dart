import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class HknuAcademicSource implements AcademicSource {
  HknuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'hknu';
  @override
  String get name => '한경국립대학교';
  @override
  Uri get website => Uri.https('www.hknu.ac.kr', '/kor/464/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [year - 1, year]) {
      if (selectedYear == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // The official previous-year navigation subtracts one from `year`.
      final response = await _client
          .post(
            Uri.https('www.hknu.ac.kr', '/schdulmanage/kor/5/yearSchdul.do'),
            body: {'kind': 'preYear', 'year': '${selectedYear + 1}'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('HKNU calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty HKNU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('input[name="year"]')?.attributes['value'] !=
        '$year') {
      throw const FormatException('Unexpected HKNU calendar year');
    }
    final months = <int>{};
    final events = <AcademicEvent>[];
    final identities = <String>{};
    for (final section in document.querySelectorAll(
      '#timeTableList.yearSchdul > ul > li',
    )) {
      final month = int.tryParse(
        (section.querySelector('.box-month')?.text ?? '')
            .replaceAll('월', '')
            .trim(),
      );
      if (month == null ||
          month < 1 ||
          month > 12 ||
          !months.add(month) ||
          section.querySelector('.box-year')?.text.trim() != '$year') {
        throw const FormatException('Invalid HKNU month coverage');
      }
      for (final row in section.querySelectorAll('.list-box')) {
        final title = (row.querySelector('.list-content')?.text ?? '')
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        final rawDate = (row.querySelector('.list-date')?.text ?? '')
            .replaceAll(RegExp(r'\([월화수목금토일]\)'), '')
            .replaceAll(RegExp(r'\s+'), '');
        final match = RegExp(
          r'^(\d{2})\.(\d{2})(?:~(\d{2})-(\d{2}))?$',
        ).firstMatch(rawDate);
        if (title.isEmpty || match == null) {
          throw const FormatException('Invalid HKNU event');
        }
        DateTime date(int y, int m, int d) {
          final result = DateTime(y, m, d);
          if (result.year != y || result.month != m || result.day != d) {
            throw const FormatException('Invalid HKNU date');
          }
          return result;
        }

        final startMonth = int.parse(match[1]!);
        final start = date(year, startMonth, int.parse(match[2]!));
        final endMonth = match[3] == null ? startMonth : int.parse(match[3]!);
        final last = match[3] == null
            ? start
            : date(
                endMonth < startMonth ? year + 1 : year,
                endMonth,
                int.parse(match[4]!),
              );
        if (startMonth != month || last.isBefore(start)) {
          throw const FormatException('Invalid HKNU period');
        }
        final sourceId = '$title:${start.toIso8601String()}';
        if (!identities.add(sourceId)) {
          throw const FormatException('Duplicate HKNU event identity');
        }
        events.add(
          AcademicEvent(
            sourceId: sourceId,
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url: 'https://www.hknu.ac.kr/kor/464/subview.do',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete HKNU calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
