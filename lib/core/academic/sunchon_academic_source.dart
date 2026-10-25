import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// Sunchon publishes every year in one public ScheduleView JSON list.
class SunchonAcademicSource implements AcademicSource {
  SunchonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const _url =
      'https://www.scnu.ac.kr/haksa/sv/schdulView/schdulCalendarView.do?mi=1416';
  @override
  String get id => 'sunchon';
  @override
  String get name => '국립순천대학교';
  @override
  Uri get website => Uri.parse(_url);
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          Uri.https('www.scnu.ac.kr', '/haksa/sv/schdulView/selectSvList.do'),
          body: {'sysId': 'SCNU'},
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    final events = parse(utf8.decode(response.bodyBytes), year);
    if (events.isEmpty) {
      throw const FormatException('No published Sunchon calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('Invalid Sunchon calendar');
    }
    DateTime date(Object? value) {
      if (value is! String) {
        throw const FormatException('Invalid Sunchon date');
      }
      final match = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$').firstMatch(value);
      if (match == null) {
        throw const FormatException('Invalid Sunchon date');
      }
      final y = int.parse(match[1]!);
      final m = int.parse(match[2]!);
      final d = int.parse(match[3]!);
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        throw const FormatException('Invalid Sunchon date');
      }
      return result;
    }

    final ids = <String>{};
    final unique = <String, AcademicEvent>{};
    for (final row in decoded) {
      if (row is! Map) throw const FormatException('Invalid Sunchon row');
      // The list holds every year: skip rows whose year span cannot touch the
      // requested year before strict validation, so old typos stay isolated.
      int? yearOf(Object? value) => value is String
          ? int.tryParse(RegExp(r'^(\d{4})/').firstMatch(value)?[1] ?? '')
          : null;
      final fromYear = yearOf(row['bgnde']);
      final toYear = yearOf(row['endde']);
      if (fromYear != null &&
          toYear != null &&
          (fromYear > year || toYear < year)) {
        continue;
      }
      final start = date(row['bgnde']);
      final last = date(row['endde']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      final title = row['schdulTitle'];
      if (last.isBefore(start) ||
          title is! String ||
          title.trim().isEmpty ||
          row['alldayAt'] != 'Y') {
        throw const FormatException('Invalid Sunchon academic period');
      }
      if (title.contains('대학원')) continue;
      final seq = row['schdulSeq'];
      final holiday = seq == 'holiday';
      if (!holiday && (seq is! int || row['sysId'] != 'SCNU')) {
        throw const FormatException('Unexpected Sunchon source identity');
      }
      // Public holiday rows share the constant ID "holiday".
      final sourceId = holiday ? '${title.trim()}:${row['bgnde']}' : '$seq';
      if (!ids.add(sourceId)) {
        throw const FormatException('Conflicting Sunchon identity');
      }
      final event = AcademicEvent(
        sourceId: sourceId,
        title: title.trim(),
        start: start,
        end: end,
        url: _url,
      );
      // A holiday the school also lists itself keeps the school's record.
      final key = '${event.title}:${event.start}:${event.end}';
      final previous = unique[key];
      if (previous == null || (!holiday && previous.sourceId.contains(':'))) {
        unique[key] = event;
      }
    }
    return unique.values.toList();
  }

  @override
  void close() => _client.close();
}
