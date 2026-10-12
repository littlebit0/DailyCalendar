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
        .get(website)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('KAU calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

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
    var firstYear = true;
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
        if (firstYear && start.year != year) {
          throw const FormatException('Unpublished KAU calendar year');
        }
        firstYear = false;
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
        if (last.isBefore(start) ||
            start.year < year ||
            start.year > year + 1 ||
            (start.year == year + 1 && start.month > 2)) {
          throw const FormatException('Unexpected KAU calendar period');
        }
        if (start.year != year) continue;
        final identity = '${start.toIso8601String()}:$title';
        events[identity] = AcademicEvent(
          sourceId: identity,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
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
