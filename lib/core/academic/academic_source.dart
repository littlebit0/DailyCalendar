import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AcademicEvent {
  const AcademicEvent({
    required this.sourceId,
    required this.title,
    required this.start,
    required this.end,
    required this.url,
  });

  final String sourceId;
  final String title;
  final DateTime start;
  final DateTime end; // Exclusive, date-only end, as in CalendarEvent.
  final String url;

  String dailyId(String universityId) {
    final hash = sha256
        .convert(utf8.encode('daily-academic-v1:$universityId:$sourceId'))
        .toString();
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-'
        '${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}';
  }

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'url': url,
  };

  factory AcademicEvent.fromJson(Map<String, dynamic> json) => AcademicEvent(
    sourceId: json['sourceId'] as String,
    title: json['title'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    url: json['url'] as String,
  );
}

abstract interface class AcademicSource {
  String get id;
  String get name;
  Uri get website;
  Future<List<AcademicEvent>> fetch(int year);
  void close();
}

/// The public JSON request made by SMU's official undergraduate calendar.
class SangmyungAcademicSource implements AcademicSource {
  SangmyungAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'smu';
  @override
  String get name => '상명대학교';
  @override
  Uri get website => Uri.https('www.smu.ac.kr', '/ko/life/academicCalendar.do');

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
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Academic source unavailable');
    }
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
        url: Uri.https('www.smu.ac.kr', '/ko/life/academicCalendar.do', {
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
