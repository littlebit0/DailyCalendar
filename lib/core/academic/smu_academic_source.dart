import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// The public JSON request made by SMU's official undergraduate calendar.
/// Seoul and Cheonan campuses publish one shared calendar (board 85).
class SangmyungAcademicSource implements AcademicSource {
  SangmyungAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'smu';
  @override
  String get name => '상명대학교';
  @override
  Uri get website =>
      Uri.https('www.smu.ac.kr', '/kor/life/academicCalendar.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          Uri.https('www.smu.ac.kr', '/app/common/selectDataList.do'),
          body: {
            'sqlId': 'jw.Article.selectCalendarArticle',
            'modelNm': 'list',
            'jsonStr': jsonEncode({
              'year': '$year',
              'month': '1',
              'bachelorBoardNoList': ['85'],
            }),
          },
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['success'] != true || json['list'] is! List) {
      throw const FormatException('Invalid academic response');
    }
    final events = <String, AcademicEvent>{};
    for (final raw in json['list'] as List) {
      final row = raw as Map<String, dynamic>;
      if (row['boardNo'].toString() != '85' ||
          row['deleteYn'] == 'Y' ||
          row['secretYn'] == 'Y') {
        continue;
      }
      final id = row['articleNo']?.toString();
      final title = (row['articleTitle'] as String?)?.trim();
      if (id == null ||
          int.tryParse(id) == null ||
          title == null ||
          title.isEmpty) {
        throw const FormatException('Incomplete academic record');
      }
      final start = _date(row['etcChar6']);
      final last = _date(row['etcChar7'] ?? row['etcChar6']);
      if (last.isBefore(start)) {
        throw const FormatException('Invalid academic period');
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      final event = AcademicEvent(
        sourceId: id,
        title: title,
        start: start,
        end: end,
        url: Uri.https('www.smu.ac.kr', '/kor/life/academicCalendar.do', {
          'mode': 'view',
          'articleNo': id,
          'boardNo': '85',
        }).toString(),
      );
      if (events.containsKey(id) &&
          jsonEncode(events[id]!.toJson()) != jsonEncode(event.toJson())) {
        throw const FormatException('Conflicting academic record');
      }
      events[id] = event;
    }
    if (events.isEmpty) {
      throw const FormatException('No published academic calendar');
    }
    return events.values.toList()..sort((a, b) {
      final order = a.start.compareTo(b.start);
      return order == 0 ? a.sourceId.compareTo(b.sourceId) : order;
    });
  }

  static DateTime _date(dynamic raw) {
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw const FormatException('Invalid academic date');
    }
    final parts = raw.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    if (date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2]) {
      throw const FormatException('Invalid academic date');
    }
    return date;
  }

  @override
  void close() => _client.close();
}
