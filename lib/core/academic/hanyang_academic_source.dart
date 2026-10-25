import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// The official Seoul and ERICA calendars publish distinct academic-year feeds.
class HanyangAcademicSource implements AcademicSource {
  HanyangAcademicSource({this.erica = false, http.Client? client})
    : _client = client ?? http.Client();
  HanyangAcademicSource.erica({http.Client? client})
    : this(erica: true, client: client);
  final bool erica;
  final http.Client _client;
  static const _namespace =
      '_kr_ac_hanyang_calendar_web_portlet_CalendarViewPortlet_';
  @override
  String get id => erica ? 'hanyang-erica' : 'hanyang';
  @override
  String get name => erica ? '한양대학교 ERICA' : '한양대학교 서울';
  @override
  Uri get website => Uri.https('www.hanyang.ac.kr', erica ? '/-93' : '/-33');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            website.replace(
              queryParameters: {
                'p_p_id':
                    'kr_ac_hanyang_calendar_web_portlet_CalendarViewPortlet',
                'p_p_lifecycle': '2',
                'p_p_state': 'normal',
                'p_p_mode': 'view',
                'p_p_cacheability': 'cacheLevelPage',
                '${_namespace}cmd': 'get_term_events',
              },
            ),
            body: {'${_namespace}sYear': '$selected'},
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selected,
        url: website.toString(),
      )) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Hanyang calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int year, {
    required String url,
  }) {
    final root = jsonDecode(body);
    if (root is! Map || root['status'] != true || root['data'] is! String) {
      throw const FormatException('Unexpected Hanyang response');
    }
    final data = jsonDecode(root['data'] as String);
    if (data is! List || data.length != 12) {
      throw const FormatException('Incomplete Hanyang academic year');
    }
    final months = <int>{};
    final result = <AcademicEvent>[];
    DateTime date(Object? raw, String time) {
      if (raw is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2} ').hasMatch(raw) ||
          raw.length != 16 ||
          raw.substring(11) != time) {
        throw const FormatException('Invalid Hanyang date');
      }
      final parts = raw.substring(0, 10).split('-').map(int.parse).toList();
      final value = DateTime(parts[0], parts[1], parts[2]);
      if (value.year != parts[0] ||
          value.month != parts[1] ||
          value.day != parts[2]) {
        throw const FormatException('Invalid Hanyang date');
      }
      return value;
    }

    for (final section in data) {
      if (section is! Map ||
          section['month'] is! int ||
          section['events'] is! List) {
        throw const FormatException('Unexpected Hanyang month');
      }
      final month = section['month'] as int;
      if (month < 0 || month > 11 || !months.add(month)) {
        throw const FormatException('Invalid Hanyang month');
      }
      final expectedYear = month < 2 ? year + 1 : year;
      for (final row in section['events'] as List) {
        if (row is! Map ||
            row['allDay'] != 'true' ||
            row['subject'] is! String) {
          throw const FormatException('Unexpected Hanyang event');
        }
        final title = (row['subject'] as String)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final start = date(row['startDateTime'], '00:00');
        final last = date(row['endDateTime'], '23:59');
        if (title.isEmpty ||
            start.year != expectedYear ||
            start.month != month + 1 ||
            last.isBefore(start) ||
            last.isAfter(DateTime(year + 1, 3, 31))) {
          throw const FormatException('Unexpected Hanyang period');
        }
        result.add(
          AcademicEvent(
            sourceId:
                '${start.toIso8601String()}:${last.toIso8601String()}:$title',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url: url,
          ),
        );
      }
    }
    if (result.isEmpty) {
      throw const FormatException('Empty Hanyang academic year');
    }
    return result;
  }

  @override
  void close() => _client.close();
}
