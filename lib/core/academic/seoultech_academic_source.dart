import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class SeoultechAcademicSource implements AcademicSource {
  SeoultechAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'seoultech';
  @override
  String get name => '서울과학기술대학교';
  @override
  Uri get website => Uri.https('aai.seoultech.ac.kr', '/bachelor/bachelor');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final (academicYear, semester) in [
      (year - 1, 2),
      (year, 1),
      (year, 2),
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'year': '$academicYear',
                'typ': '${semester + 1}',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Seoultech calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear, semester).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Seoultech calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int academicYear,
    int semester,
  ) {
    final table = html
        .parse(body)
        .querySelector('.wrap_plugin_schedule table.schedule');
    if (table?.querySelector('caption')?.text.trim() != '$semester학기 일정' ||
        !RegExp('var year = $academicYear;').hasMatch(body) ||
        (semester != 1 && semester != 2)) {
      throw const FormatException('Unexpected Seoultech semester');
    }
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final row in table!.querySelectorAll('tbody tr')) {
      final text = row.querySelector('.date')?.text.trim() ?? '';
      final content = row.querySelector('.al');
      for (final link in content?.querySelectorAll('.link') ?? []) {
        link.remove(); // Calendar export control is not part of the event title.
      }
      final title = content?.text.trim() ?? '';
      final range = RegExp(
        r'^(\d{4})\.(\d{2})\.(\d{2})\s*~\s*(?:(\d{4})\.)?(\d{2})\.(\d{2})$',
      ).firstMatch(text);
      if (range == null || title.isEmpty) {
        throw const FormatException('Invalid Seoultech event');
      }
      DateTime date(int y, int m, int d) {
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid Seoultech date');
        }
        return result;
      }

      final start = date(
        int.parse(range[1]!),
        int.parse(range[2]!),
        int.parse(range[3]!),
      );
      final lastMonth = int.parse(range[5]!);
      final last = date(
        int.tryParse(range[4] ?? '') ??
            (start.year + (lastMonth < start.month ? 1 : 0)),
        lastMonth,
        int.parse(range[6]!),
      );
      // The finance office published one reversed range ("2026.01.29 ~ 01.19");
      // it has no date to show, while academic rows must never be malformed.
      if (last.isBefore(start) && title.contains('회계연도')) continue;
      if (start.year != academicYear + (start.month <= 2 ? 1 : 0) ||
          last.isBefore(start)) {
        throw const FormatException('Unexpected Seoultech period');
      }
      // The page marks graduate-school-only rows with `(대학원)`.
      if (title.contains('(대학원)')) continue;
      final key = '$academicYear:$semester:$title';
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
          url:
              'https://aai.seoultech.ac.kr/bachelor/bachelor?year=$academicYear&typ=${semester + 1}',
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('No published Seoultech semester');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
