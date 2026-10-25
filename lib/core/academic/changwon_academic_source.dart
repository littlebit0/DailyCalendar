import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// Changwon campus: the public ScheduleView calendar, one month per request.
class ChangwonAcademicSource implements AcademicSource {
  ChangwonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'changwon';
  @override
  String get name => '국립창원대학교';
  @override
  Uri get website => Uri.https(
    'www.changwon.ac.kr',
    '/haksa/sv/schdulView/schdulCalendarView.do',
    {'mi': '10980'},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (var month = 1; month <= 12; month++) {
      if (month > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final mm = month.toString().padLeft(2, '0');
      final response = await _client
          .post(
            Uri.https(
              'www.changwon.ac.kr',
              '/haksa/sv/schdulView/selectSvList.do',
            ),
            body: {
              'sysId': 'haksa',
              'dateFirst': '$year/$mm/01',
              'dateEnmt': '$year/$mm/${DateTime(year, month + 1, 0).day}',
            },
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      for (final event in parse(utf8.decode(response.bodyBytes), year)) {
        final previous = events[event.sourceId];
        if (previous != null &&
            jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting Changwon record');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Changwon calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('Invalid Changwon calendar');
    }
    DateTime date(Object? value) {
      final match = RegExp(
        r'^(\d{4})/(\d{2})/(\d{2})$',
      ).firstMatch(value is String ? value : '');
      if (match == null) throw const FormatException('Invalid Changwon date');
      final y = int.parse(match[1]!), m = int.parse(match[2]!);
      final d = int.parse(match[3]!);
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        throw const FormatException('Invalid Changwon date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in decoded) {
      if (row is! Map) throw const FormatException('Invalid Changwon row');
      // "holiday" rows are a fixed current-year public-holiday overlay, not
      // the published academic calendar, which lists its own closures.
      if (row['schdulSeq'] == 'holiday') continue;
      final seq = row['scheno'];
      if (row['schdulSeq'] != 'portal' ||
          seq is! int ||
          row['calno'] != 1 ||
          row['calname'] != '학사일정') {
        throw const FormatException('Unexpected Changwon source identity');
      }
      final start = date(row['bgnde']);
      final last = date(row['endde']);
      final title = row['schdulTitle'];
      if (last.isBefore(start) ||
          title is! String ||
          title.trim().isEmpty ||
          row['alldayAt'] != 'Y') {
        throw const FormatException('Invalid Changwon academic period');
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      if (title.contains('대학원')) continue;
      if (events.containsKey('$seq')) {
        throw const FormatException('Duplicate Changwon record');
      }
      events['$seq'] = AcademicEvent(
        sourceId: '$seq',
        title: title.trim(),
        start: start,
        end: end,
        url:
            'https://www.changwon.ac.kr/haksa/sv/schdulView/schdulCalendarView.do?mi=10980',
      );
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
