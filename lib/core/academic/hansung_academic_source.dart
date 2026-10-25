import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class HansungAcademicSource implements AcademicSource {
  HansungAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'hansung';
  @override
  String get name => '한성대학교';
  @override
  Uri get website => Uri.https('www.hansung.ac.kr', '/hansung/6096/subview.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https(
              'www.hansung.ac.kr',
              '/schdulMng/hansung/39/yearSchdul.do',
            ),
            body: {'kind': '', 'year': '$selected'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Hansung calendar unavailable');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final december = await _client
          .post(
            Uri.https(
              'www.hansung.ac.kr',
              '/schdulMng/hansung/39/monthSchdul.do',
            ),
            body: {'kind': '', 'year': '$selected', 'month': '12'},
          )
          .timeout(const Duration(seconds: 20));
      if (december.statusCode != 200 || december.bodyBytes.length > 8000000) {
        throw const FormatException('Hansung December calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selected,
        decemberBody: utf8.decode(december.bodyBytes),
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Hansung calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int year, {
    String? decemberBody,
  }) {
    final document = html.parse(body);
    if (document.querySelector('#year')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected Hansung year');
    }
    final decemberDates = <String, String>{};
    if (decemberBody != null) {
      final monthly = html.parse(decemberBody);
      if (monthly.querySelector('#year')?.attributes['value'] != '$year') {
        throw const FormatException('Unexpected Hansung December year');
      }
      for (final row
          in monthly.querySelectorAll('table').last.querySelectorAll('tr')) {
        final dateCell = row.querySelector('th');
        final titleCell = row.querySelector('td');
        if (dateCell == null || titleCell == null) continue;
        final title = titleCell.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (title.isEmpty || decemberDates.containsKey(title)) {
          throw const FormatException('Ambiguous Hansung December entry');
        }
        decemberDates[title] = dateCell.text;
      }
      if (decemberDates.isEmpty) {
        throw const FormatException('Missing Hansung December rows');
      }
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in document.querySelectorAll('.box-sch')) {
      final match = RegExp(
        r'^(\d{1,2})월$',
      ).firstMatch(section.querySelector('.num p')?.text.trim() ?? '');
      final month = match == null ? 0 : int.parse(match[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Hansung month');
      }
      for (final row in section.querySelectorAll('.desc dl')) {
        final title =
            row
                .querySelector('dd')
                ?.text
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim() ??
            '';
        // Annual rendering carries the next year into later December rows.
        // Use the separate official month view for every December row, matched
        // by title; do not infer or subtract a year from the malformed date.
        final text = month == 12 && decemberBody != null
            ? decemberDates.remove(title)
            : row.querySelector('dt')?.text;
        if (text == null) {
          throw const FormatException('Missing Hansung official dates');
        }
        final dates = RegExp(
          r'(\d{4})\.(\d{2})\.(\d{2})\([월화수목금토일]\)',
        ).allMatches(text).toList();
        if (title.isEmpty || dates.isEmpty || dates.length > 2) {
          throw const FormatException('Invalid Hansung event');
        }
        DateTime date(RegExpMatch m) {
          final y = int.parse(m[1]!);
          final mm = int.parse(m[2]!);
          final d = int.parse(m[3]!);
          final result = DateTime(y, mm, d);
          if (result.year != y || result.month != mm || result.day != d) {
            throw const FormatException('Invalid Hansung date');
          }
          return result;
        }

        final start = date(dates.first);
        final last = date(dates.last);
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected Hansung period');
        }
        final identity =
            '${start.toIso8601String()}:${last.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: end,
          url: 'https://www.hansung.ac.kr/hansung/6096/subview.do',
        );
      }
    }
    if (months.length != 12 || events.isEmpty || decemberDates.isNotEmpty) {
      throw const FormatException('Incomplete Hansung calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
