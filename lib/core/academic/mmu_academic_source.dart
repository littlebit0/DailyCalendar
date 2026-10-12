import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class MmuAcademicSource implements AcademicSource {
  MmuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'mmu';
  @override
  String get name => '목포해양대학교';
  @override
  Uri get website => Uri.https('www.mmu.ac.kr', '/main/acschedule');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            Uri.https('www.mmu.ac.kr', '/main/scheduleList', {
              'libType': 'D',
              'searchDt': '',
              'hakgi': '0',
              'recordCnt': '999',
              'year': '$selected',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('MMU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published MMU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['list'] is! List ||
        decoded['scheduleVO'] is! Map) {
      throw const FormatException('Invalid MMU calendar response');
    }
    final scope = decoded['scheduleVO'] as Map;
    final lastDay = DateTime(academicYear + 1, 3, 0).day;
    if (scope['sitecode'] != 'main' ||
        scope['libtype'] != 'D' ||
        scope['first_DT'] != '$academicYear-03-01' ||
        scope['last_DT'] != '${academicYear + 1}-02-$lastDay') {
      throw const FormatException('Unexpected MMU calendar year');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid MMU date');
      }
      final parts = value.split('-').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid MMU date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in decoded['list'] as List) {
      if (row is! Map ||
          row['id'] is! int ||
          row['sitecode'] != 'main' ||
          row['libtype'] != 'D' ||
          row['useyn'] != 'Y' ||
          row['title'] is! String ||
          (row['title'] as String).trim().isEmpty) {
        throw const FormatException('Invalid MMU calendar event');
      }
      final start = date(row['frdt']);
      final last = date(row['todt']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(academicYear + 1, 3)) ||
          !end.isAfter(DateTime(academicYear, 3))) {
        throw const FormatException('Unexpected MMU period');
      }
      final identity = row['id'].toString();
      if (events.containsKey(identity)) {
        throw const FormatException('Duplicate MMU event');
      }
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: (row['title'] as String).trim(),
        start: start,
        end: end,
        url: 'https://www.mmu.ac.kr/main/acschedule',
      );
    }
    if (events.isEmpty || events.length >= 999) {
      throw const FormatException('Empty or truncated MMU calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
