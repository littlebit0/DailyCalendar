import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';
import 'dnue_academic_source.dart';

class CueAcademicSource implements AcademicSource {
  CueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'cue';
  @override
  String get name => '진주교육대학교';
  @override
  Uri get website => Uri.https(
    'www.cue.ac.kr',
    '/kor/CMS/ScheduleMgr/YearList.do',
    {'mCode': 'MN052'},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                ...website.queryParameters,
                'calendar_year': '$selected',
              },
            ),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('CUE calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published CUE calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    // Both universities publish the same CMS ScheduleMgr annual DOM. Reuse the
    // validated date/range parser and retain this university's source URL.
    return DnueAcademicSource.parse(body, year)
        .map(
          (e) => AcademicEvent(
            sourceId: e.sourceId,
            title: e.title,
            start: e.start,
            end: e.end,
            url:
                'https://www.cue.ac.kr/kor/CMS/ScheduleMgr/YearList.do?mCode=MN052',
          ),
        )
        .toList();
  }

  @override
  void close() => _client.close();
}
