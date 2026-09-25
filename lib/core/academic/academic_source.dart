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

/// Public undergraduate calendar shared by Dankook's Jukjeon/Cheonan campuses.
/// The university page itself requests this endpoint without authentication.
class DankookAcademicSource implements AcademicSource {
  DankookAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'dku';
  @override
  String get name => '단국대학교';
  @override
  Uri get website => Uri.https('www.dankook.ac.kr', '/web/kor/-2014-');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    // Source timestamps describe Korean calendar dates, regardless of the
    // device's current timezone. Its query includes overlapping events.
    final start = DateTime.utc(year).subtract(const Duration(hours: 9));
    final end = DateTime.utc(year + 1).subtract(const Duration(hours: 9));
    final response = await _client
        .get(
          Uri.https(
            'www.dankook.ac.kr',
            '/o/dku_calendar-rest/calendar/events/0/'
                '${start.millisecondsSinceEpoch}/${end.millisecondsSinceEpoch - 1}',
          ),
        )
        .timeout(const Duration(seconds: 20));
    _checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['status'] != true ||
        decoded['data'] is! List) {
      throw const FormatException('Invalid Dankook academic response');
    }
    final records = <_CalendarRecord>[];
    for (final raw in decoded['data'] as List) {
      if (raw is! Map || raw['title'] is! String) {
        throw const FormatException('Incomplete Dankook academic record');
      }
      final title = (raw['title'] as String).trim();
      if (title.isEmpty) throw const FormatException('Empty academic title');
      final start = _koreanTimestampDate(raw['startTime']);
      final last = _koreanTimestampDate(raw['endTime']);
      records.add((title: title, start: start, last: last));
    }
    return _calendarEvents(
      records,
      year,
      'https://www.dankook.ac.kr/web/kor/-2014-',
    );
  }

  static DateTime _koreanTimestampDate(Object? value) {
    final milliseconds = int.tryParse(value.toString());
    if (milliseconds == null) {
      throw const FormatException('Invalid academic timestamp');
    }
    final DateTime korean;
    try {
      korean = DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).add(const Duration(hours: 9));
    } on ArgumentError {
      throw const FormatException('Invalid academic timestamp');
    }
    if (korean.year < 1900 || korean.year > 9999) {
      throw const FormatException('Invalid academic timestamp');
    }
    return DateTime(korean.year, korean.month, korean.day);
  }

  @override
  void close() => _client.close();
}

/// Public undergraduate calendar for Chonnam's Gwangju/Yeosu campuses.
class ChonnamAcademicSource implements AcademicSource {
  ChonnamAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'jnu';
  @override
  String get name => '전남대학교';
  @override
  Uri get website =>
      Uri.https('events.jnu.ac.kr', '/Schedule.aspx', {'mode': '1'});

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(website.replace(queryParameters: {'mode': '1', 'YY': '$year'}))
        .timeout(const Duration(seconds: 20));
    _checkAcademicResponse(response);
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final table = RegExp(
      r'<table\b[^>]*\bid=["\x27]ContentPlaceHolder1_SubContentPlaceHolder1_gvList["\x27][^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body)?.group(1);
    if (table == null) {
      throw const FormatException('Missing Chonnam academic table');
    }
    final records = <_CalendarRecord>[];
    for (final row in RegExp(
      r'<tr\b[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(table)) {
      final cells =
          RegExp(r'<td\b[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true)
              .allMatches(row.group(1)!)
              .map((match) => _academicHtmlText(match.group(1)!))
              .toList();
      if (cells.isEmpty) continue; // Column headings use th.
      if (cells.length != 2 || cells[1].isEmpty) {
        throw const FormatException('Incomplete Chonnam academic record');
      }
      final dates = RegExp(
        r'(\d{4})[.-](\d{2})[.-](\d{2})',
      ).allMatches(cells[0]).toList();
      if (dates.length != 2) {
        throw const FormatException('Invalid academic date range');
      }
      DateTime date(RegExpMatch match) {
        final y = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final d = int.parse(match.group(3)!);
        final result = DateTime(y, m, d);
        if (y < 1900 ||
            result.year != y ||
            result.month != m ||
            result.day != d) {
          throw const FormatException('Invalid academic date');
        }
        return result;
      }

      records.add((
        title: cells[1],
        start: date(dates[0]),
        last: date(dates[1]),
      ));
    }
    return _calendarEvents(
      records,
      year,
      Uri.https('events.jnu.ac.kr', '/Schedule.aspx', {
        'mode': '1',
        'YY': '$year',
      }).toString(),
    );
  }

  @override
  void close() => _client.close();
}

typedef _CalendarRecord = ({String title, DateTime start, DateTime last});

void _checkAcademicResponse(http.Response response) {
  if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
    throw const FormatException('Academic source unavailable');
  }
}

List<AcademicEvent> _calendarEvents(
  List<_CalendarRecord> records,
  int year,
  String url,
) {
  records.sort((a, b) {
    final order = a.start.compareTo(b.start);
    return order != 0 ? order : a.title.compareTo(b.title);
  });
  final identities = <String, int>{};
  final seen = <String>{};
  final result = <AcademicEvent>[];
  for (final record in records) {
    if (record.last.isBefore(record.start)) {
      throw const FormatException('Invalid academic period');
    }
    final end = DateTime(
      record.last.year,
      record.last.month,
      record.last.day + 1,
    );
    if (!record.start.isBefore(DateTime(year + 1)) ||
        !end.isAfter(DateTime(year))) {
      continue;
    }
    final signature =
        '${record.title}:${record.start.toIso8601String()}:${record.last.toIso8601String()}';
    if (!seen.add(signature)) {
      continue; // Official JNU feed repeats the entrance ceremony.
    }
    // Neither public source supplies stable event IDs. Titles, start-year and
    // occurrence order keep date-only corrections on an existing imported event.
    final titleHash = sha256.convert(utf8.encode(record.title)).toString();
    final identity = '${record.start.year}:$titleHash';
    final occurrence = identities.update(
      identity,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    result.add(
      AcademicEvent(
        sourceId: '$identity:$occurrence',
        title: record.title,
        start: record.start,
        end: end,
        url: url,
      ),
    );
  }
  if (result.isEmpty) {
    throw const FormatException('No published academic calendar');
  }
  return result;
}

String _academicHtmlText(String value) => value
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAllMapped(RegExp(r'&#([xX][0-9a-fA-F]+|\d+);'), (match) {
      final encoded = match.group(1)!;
      final code = encoded.toLowerCase().startsWith('x')
          ? int.parse(encoded.substring(1), radix: 16)
          : int.parse(encoded);
      if (code <= 0 || code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff)) {
        throw const FormatException('Invalid HTML character');
      }
      return String.fromCharCode(code);
    })
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .trim();
