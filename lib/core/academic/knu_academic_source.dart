import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KnuAcademicSource implements AcademicSource {
  KnuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'knu';
  @override
  String get name => '경북대학교';
  @override
  Uri get website =>
      Uri.https('www.knu.ac.kr', '/wbbs/wbbs/user/yearSchedule/index.action');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website.replace(
            queryParameters: {'menu_idx': '43', 'vo.search_year': '$year'},
          ),
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final calendar = html.parse(body).querySelector('#calendar');
    if (calendar == null) {
      throw const FormatException('Missing KNU calendar');
    }
    final months = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final section in calendar.querySelectorAll('dl')) {
      final label =
          section.querySelector('dt')?.text.replaceAll(RegExp(r'\s+'), '') ??
          '';
      final monthMatch = RegExp(r'^(\d{4})년(\d{2})월$').firstMatch(label);
      if (monthMatch == null || monthMatch[1] != '$year') {
        throw const FormatException('Unexpected KNU calendar year');
      }
      final month = int.parse(monthMatch[2]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid KNU month coverage');
      }
      for (final row in section.querySelectorAll('li')) {
        final dayElement = row.querySelector('.day');
        final dayText = dayElement?.text.trim() ?? '';
        final day = RegExp(
          r'^(\d{2})\.(\d{2})\([월화수목금토일]\)$',
        ).firstMatch(dayText);
        if (day == null || int.parse(day[1]!) != month) {
          throw const FormatException('Invalid KNU day');
        }
        final text = row.text
            .substring(row.text.indexOf(dayText) + dayText.length)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (text.startsWith('[대학원]')) {
          continue;
        }
        if (text.isEmpty) {
          throw const FormatException('Missing KNU title');
        }
        final start = _date(year, month, int.parse(day[2]!));
        // The visible date column is only the first day. The official title
        // publishes the complete period, which must not become a one-day event.
        final ranges = RegExp(
          r'(?:(\d{4})\.)?(\d{1,2})\.(\d{1,2})\.?\s*~\s*(?:(\d{4})\.)?(\d{1,2})\.(\d{1,2})\.?',
        ).allMatches(text).toList();
        if (ranges.length > 1 || (text.contains('~') && ranges.isEmpty)) {
          throw const FormatException('Ambiguous KNU date range');
        }
        var last = start;
        var title = text;
        if (ranges.isNotEmpty) {
          final range = ranges.single;
          final first = _date(
            int.tryParse(range[1] ?? '') ?? year,
            int.parse(range[2]!),
            int.parse(range[3]!),
          );
          final lastMonth = int.parse(range[5]!);
          last = _date(
            int.tryParse(range[4] ?? '') ??
                (lastMonth < month ? year + 1 : year),
            lastMonth,
            int.parse(range[6]!),
          );
          if (first != start || last.isBefore(start)) {
            throw const FormatException('Conflicting KNU date range');
          }
          title = text
              .replaceRange(range.start, range.end, '')
              .replaceAll(RegExp(r'\(\s*\)'), '')
              .trim();
        } else {
          title = text
              .replaceFirst(RegExp(r'\s*\(\d{1,2}\.\d{1,2}\.?\)\s*$'), '')
              .trim();
        }
        final identity = '$year:$title';
        final occurrence = occurrences.update(
          identity,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        events.add(
          AcademicEvent(
            sourceId: '$identity:$occurrence',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.knu.ac.kr/wbbs/wbbs/user/yearSchedule/index.action?menu_idx=43&vo.search_year=$year',
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete KNU annual calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static DateTime _date(int year, int month, int day) {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Invalid KNU calendar date');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
