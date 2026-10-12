import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// Both official sites use the same public ScheduleView JSON date fields.
class SvAcademicSource implements AcademicSource {
  SvAcademicSource.sunchon({http.Client? client})
    : sunchon = true,
      _client = client ?? http.Client();
  SvAcademicSource.changwon({http.Client? client})
    : sunchon = false,
      _client = client ?? http.Client();
  final bool sunchon;
  final http.Client _client;
  @override
  String get id => sunchon ? 'sunchon' : 'changwon';
  @override
  String get name => sunchon ? '국립순천대학교' : '국립창원대학교';
  String get _host => sunchon ? 'www.scnu.ac.kr' : 'www.changwon.ac.kr';
  String get _menu => sunchon ? '1416' : '10980';
  @override
  Uri get website => Uri.https(
    _host,
    '/haksa/sv/schdulView/schdulCalendarView.do',
    {'mi': _menu},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (var month = 1; month <= (sunchon ? 1 : 12); month++) {
      if (month > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https(_host, '/haksa/sv/schdulView/selectSvList.do'),
            body: {
              'sysId': sunchon ? 'SCNU' : 'haksa',
              if (!sunchon) ...{
                'dateFirst': '$year/${month.toString().padLeft(2, '0')}/01',
                'dateEnmt':
                    '$year/${month.toString().padLeft(2, '0')}/${DateTime(year, month + 1, 0).day}',
              },
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('ScheduleView calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        year,
        sunchon: sunchon,
      )) {
        final previous = events[event.sourceId];
        if (previous != null &&
            jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting ScheduleView identity');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published ScheduleView calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int year, {
    required bool sunchon,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('Invalid ScheduleView calendar');
    }
    DateTime date(Object? value) {
      if (value is! String) {
        throw const FormatException('Invalid ScheduleView date');
      }
      final match = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$').firstMatch(value);
      if (match == null) {
        throw const FormatException('Invalid ScheduleView date');
      }
      final y = int.parse(match[1]!);
      final m = int.parse(match[2]!);
      final d = int.parse(match[3]!);
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        throw const FormatException('Invalid ScheduleView date');
      }
      return result;
    }

    final events = <AcademicEvent>[];
    for (final row in decoded) {
      if (row is! Map) throw const FormatException('Invalid ScheduleView row');
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
        throw const FormatException('Invalid ScheduleView academic period');
      }
      if (title.contains('대학원')) continue;
      final seq = row['schdulSeq'];
      if (sunchon
          ? (seq != 'holiday' && (seq is! int || row['sysId'] != 'SCNU'))
          : !['holiday', 'portal'].contains(seq)) {
        throw const FormatException('Unexpected ScheduleView source identity');
      }
      // Changwon uses the constant ID "portal" for unrelated academic events.
      final sourceId = sunchon && seq != 'holiday'
          ? '$seq'
          : '${title.trim()}:${row['bgnde']}';
      events.add(
        AcademicEvent(
          sourceId: sourceId,
          title: title.trim(),
          start: start,
          end: end,
          url:
              'https://${sunchon ? 'www.scnu.ac.kr' : 'www.changwon.ac.kr'}/haksa/sv/schdulView/schdulCalendarView.do?mi=${sunchon ? '1416' : '10980'}',
        ),
      );
    }
    final unique = <String, AcademicEvent>{};
    for (final event in events) {
      final key = '${event.title}:${event.start}:${event.end}';
      unique.putIfAbsent(key, () => event);
    }
    return unique.values.toList();
  }

  @override
  void close() => _client.close();
}
