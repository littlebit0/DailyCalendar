import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KauAcademicSource implements AcademicSource {
  KauAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kau';
  @override
  String get name => '한국항공대학교';
  @override
  Uri get website => Uri.https('www.kau.ac.kr', '/kaulife/schedule.php');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website,
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  /// The page shows one academic year (January to the next February), so
  /// [year] also receives the next-year rows of the previous academic year.
  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    final tables = document.querySelectorAll('#sub_article table.table_02');
    if (tables.length != 2 ||
        tables[0].querySelector('caption')?.text.trim() != '1학기 학사일정' ||
        tables[1].querySelector('caption')?.text.trim() != '2학기 학사일정') {
      throw const FormatException('Missing KAU semester tables');
    }
    DateTime date(String text, {int? fallbackYear, int? fallbackMonth}) {
      final m = RegExp(
        r'^\s*(?:(\d{4})\s*\.\s*)?(?:(\d{1,2})\s*\.\s*)?(\d{1,2})\s*\([월화수목금토일]\)\s*$',
      ).firstMatch(text);
      if (m == null ||
          (m[1] == null && fallbackYear == null) ||
          (m[2] == null && fallbackMonth == null)) {
        throw const FormatException('Invalid KAU date');
      }
      final y = int.parse(m[1] ?? '$fallbackYear');
      final mm = int.parse(m[2] ?? '$fallbackMonth');
      final dd = int.parse(m[3]!);
      final result = DateTime(y, mm, dd);
      if (result.year != y || result.month != mm || result.day != dd) {
        throw const FormatException('Invalid KAU date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    int? academicYear;
    for (final table in tables) {
      for (final row in table.querySelectorAll('tbody > tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) throw const FormatException('Invalid KAU event');
        final range = cells.first.text.trim().split('~');
        final title = cells.last.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (range.length > 2 || title.isEmpty) {
          throw const FormatException('Invalid KAU event');
        }
        final start = date(range.first);
        // The first row opens the academic year the page publishes.
        final pageYear = academicYear ??= start.year;
        var last = date(
          range.last,
          fallbackYear: start.year,
          fallbackMonth: start.month,
        );
        if (last.month < start.month &&
            !RegExp(r'\d{4}\s*\.').hasMatch(range.last)) {
          last = date(
            range.last,
            fallbackYear: start.year + 1,
            fallbackMonth: start.month,
          );
        }
        // Both ends must lie in the page window (January of the page year to
        // next February), so a typo such as `2026. 1. 2 ~ 2028. 1. 8` fails.
        bool outside(DateTime d) =>
            d.year < pageYear ||
            d.year > pageYear + 1 ||
            (d.year == pageYear + 1 && d.month > 2);
        if (last.isBefore(start) || outside(start) || outside(last)) {
          throw const FormatException('Unexpected KAU calendar period');
        }
        final end = DateTime(last.year, last.month, last.day + 1);
        if (!start.isBefore(DateTime(year + 1)) ||
            !end.isAfter(DateTime(year))) {
          continue;
        }
        final identity = '${start.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: end,
          url: 'https://www.kau.ac.kr/kaulife/schedule.php',
        );
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published KAU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
