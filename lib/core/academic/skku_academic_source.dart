import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// Official SKKU calendar embeds its dated records as JSON in the view page.
class SkkuAcademicSource implements AcademicSource {
  SkkuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'skku';
  @override
  String get name => '성균관대학교';
  @override
  Uri get website =>
      Uri.https('www.skku.edu', '/skku/edu/bachelor/ca_de_schedule.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    for (final academicYear in [year - 1, year]) {
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'mode': 'view',
                'srBachelorYear': '$academicYear',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)) &&
              (academicYear == year || e.start.isBefore(DateTime(year, 3))),
        ),
      );
    }
    if (events.isEmpty) throw const FormatException('Empty SKKU calendar');
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document
            .querySelector('input[name=bachelor_year]')
            ?.attributes['value'] !=
        '$academicYear') {
      throw const FormatException('Unexpected SKKU academic year');
    }
    final text = document.querySelector('textarea[name=articleText]')?.text;
    final decoded = text == null ? null : jsonDecode(text);
    if (decoded is! Map || decoded.length != 10) {
      throw const FormatException('Incomplete SKKU annual calendar');
    }
    final events = <AcademicEvent>[];
    final occurrences = <String, int>{};
    for (var month = 3; month <= 12; month++) {
      final group = decoded['bachelor_$month'];
      if (group is! List || group.length != 1 || group.single is! Map) {
        throw const FormatException('Invalid SKKU month');
      }
      final row = group.single as Map;
      final count = row['size'];
      if (count is! int || count < 0 || row.length != count * 3 + 1) {
        throw const FormatException('Incomplete SKKU month records');
      }
      for (var index = 0; index < count; index++) {
        final title = row['con_${month}_$index'];
        if (title is! String || title.trim().isEmpty) {
          throw const FormatException('Invalid SKKU title');
        }
        final start = _date(row['sd_${month}_$index']);
        final rawEnd = row['ed_${month}_$index'];
        final last = rawEnd == '' ? start : _date(rawEnd);
        if (last.isBefore(start) ||
            start.isBefore(DateTime(academicYear, 3)) ||
            last.isAfter(DateTime(academicYear + 1, 3, 31))) {
          throw const FormatException('Invalid SKKU event period');
        }
        final identity = '$academicYear:${title.trim()}';
        final occurrence = occurrences.update(
          identity,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        events.add(
          AcademicEvent(
            sourceId: '$identity:$occurrence',
            title: title.trim(),
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://www.skku.edu/skku/edu/bachelor/ca_de_schedule.do?mode=view&srBachelorYear=$academicYear',
          ),
        );
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty SKKU annual calendar');
    }
    return events;
  }

  static DateTime _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Invalid SKKU date');
    }
    final date = DateTime.parse(value);
    if (date.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('Invalid SKKU calendar day');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
