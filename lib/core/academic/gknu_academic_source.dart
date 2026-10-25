import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class GknuAcademicSource implements AcademicSource {
  GknuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'gknu';
  @override
  String get name => '국립경국대학교';
  @override
  Uri get website => Uri.https(
    'www.gknu.ac.kr',
    '/main/module/schedule/index.do',
    {'menu_idx': '300', 'category1': '101'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (var index = 0; index <= 12; index++) {
      if (index > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final selectedYear = index == 0 ? year - 1 : year;
      final month = index == 0 ? 12 : index;
      final response = await _client
          .get(
            Uri.https('www.gknu.ac.kr', '/main/module/schedule/view.do', {
              'category1': '101',
              'notice_start_date':
                  '$selectedYear-${month.toString().padLeft(2, '0')}',
            }),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
        month,
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published GKNU undergraduate calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    if (month < 1 || month > 12) {
      throw const FormatException('Invalid GKNU month');
    }
    final rows = jsonDecode(body);
    if (rows is! List) throw const FormatException('Invalid GKNU calendar');
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid GKNU date');
      }
      final p = value.split('-').map(int.parse).toList();
      final result = DateTime(p[0], p[1], p[2]);
      if (result.year != p[0] || result.month != p[1] || result.day != p[2]) {
        throw const FormatException('Invalid GKNU date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in rows) {
      if (row is! Map ||
          row['title'] is! String ||
          (row['title'] as String).trim().isEmpty) {
        throw const FormatException('Invalid GKNU event');
      }
      final start = date(row['notice_start_date']);
      // The website displays no range when the published end field is blank.
      final last =
          row['notice_end_date'] == null ||
              '${row['notice_end_date']}'.trim().isEmpty
          ? start
          : date(row['notice_end_date']);
      if (last.isBefore(start) || start.year != year || start.month != month) {
        throw const FormatException('Unexpected GKNU monthly period');
      }
      final title = (row['title'] as String)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final identity = '$start:$last:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: DateTime(last.year, last.month, last.day + 1),
        url:
            'https://www.gknu.ac.kr/main/module/schedule/index.do?menu_idx=300&category1=101',
      );
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
