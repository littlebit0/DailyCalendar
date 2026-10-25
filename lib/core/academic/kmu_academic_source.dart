import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class KmuAcademicSource implements AcademicSource {
  KmuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kmu';
  @override
  String get name => '계명대학교';
  @override
  Uri get website =>
      Uri.https('www.kmu.ac.kr', '/uni/main/page.jsp', {'mnu_uid': '3373'});

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final selectedYear in [year - 1, year]) {
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'mnu_uid': '3373',
                'parm_doc_year': '$selectedYear',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      events.addAll(
        parse(utf8.decode(response.bodyBytes), selectedYear).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty KMU calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document
            .querySelector('select[name=parm_doc_year] option[selected]')
            ?.attributes['value'] !=
        '$academicYear') {
      throw const FormatException('Unexpected KMU year');
    }
    final months = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    // The annual view repeats the same records. Read the monthly view once.
    for (final section in document.querySelectorAll('#schedule_month > li')) {
      final month = int.tryParse(
        section
                .querySelector('.calendar > b')
                ?.text
                .replaceAll('월', '')
                .trim() ??
            '',
      );
      if (month == null || month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid KMU month coverage');
      }
      for (final row in section.querySelectorAll('tbody[class^=ul_] > tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) {
          throw const FormatException('Invalid KMU event');
        }
        final range = cells.first.text.trim().split('~');
        if (range.length > 2) {
          throw const FormatException('Invalid KMU date range');
        }
        DateTime date(String value, int year) {
          final match = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(value.trim());
          if (match == null) {
            throw const FormatException('Invalid KMU date');
          }
          final m = int.parse(match[1]!);
          final d = int.parse(match[2]!);
          final result = DateTime(year, m, d);
          if (result.year != year || result.month != m || result.day != d) {
            throw const FormatException('Invalid KMU date');
          }
          return result;
        }

        final year = month < 3 ? academicYear + 1 : academicYear;
        final start = date(range.first, year);
        var last = date(range.last, year);
        if (last.month < start.month) last = date(range.last, year + 1);
        if (start.month != month || last.isBefore(start)) {
          throw const FormatException('Invalid KMU period');
        }
        for (final item in cells.last.querySelectorAll('li')) {
          final title = item.text.trim();
          if (title.isEmpty) {
            throw const FormatException('Empty KMU title');
          }
          // Graduate-school ceremonies are excluded, as in earlier releases.
          if (title.contains('대학원')) {
            continue;
          }
          final occurrence = occurrences.update(
            title,
            (n) => n + 1,
            ifAbsent: () => 0,
          );
          events.add(
            AcademicEvent(
              sourceId: '$academicYear:$title:$occurrence',
              title: title,
              start: start,
              end: DateTime(last.year, last.month, last.day + 1),
              url:
                  'https://www.kmu.ac.kr/uni/main/page.jsp?mnu_uid=3373&parm_doc_year=$academicYear',
            ),
          );
        }
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete KMU calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
