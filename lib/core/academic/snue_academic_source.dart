import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Annual public calendar used by SNUE's official undergraduate website.
class SnueAcademicSource implements AcademicSource {
  SnueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  String get id => 'snue';
  @override
  String get name => '서울교육대학교';
  @override
  Uri get website => Uri.https(
    'www.snue.ac.kr',
    '/snue/sm/schdul/schdulList.do',
    {'mi': '1281', 'schdulId': '1000'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.snue.ac.kr', '/snue/sm/schdul/selectSchdulInfo.do'),
            body: {
              'schdulId': '1000',
              'sysId': 'snue',
              'yearFirst': 'Y',
              'year': '$selected',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('SNUE calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          final previous = events[event.sourceId];
          if (previous != null &&
              jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
            throw const FormatException('Conflicting SNUE calendar article');
          }
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published SNUE calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final data = jsonDecode(body);
    if (data is! List || data.isEmpty) {
      throw const FormatException('Missing SNUE annual calendar');
    }
    final events = <String, AcademicEvent>{};
    final articles = <String, String>{};
    final months = <int>{};
    for (final row in data) {
      if (row is! Map ||
          row['sysId'] != 'snue' ||
          row['schdulId'].toString() != '1000') {
        throw const FormatException('Unexpected SNUE calendar scope');
      }
      DateTime date(Object? value) {
        final match = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$').firstMatch('$value');
        if (match == null) throw const FormatException('Invalid SNUE date');
        final y = int.parse(match[1]!);
        final m = int.parse(match[2]!);
        final d = int.parse(match[3]!);
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid SNUE date');
        }
        return result;
      }

      final start = date(row['bgnde']);
      final last = date(row['endde']);
      final title = row['schdulCn'] is String
          ? (row['schdulCn'] as String).replaceAll(RegExp(r'\s+'), ' ').trim()
          : '';
      final article = '${row['schdulSeq']}';
      if (start.year != year ||
          last.isBefore(start) ||
          last.isAfter(DateTime(year + 1, 12, 31)) ||
          title.isEmpty ||
          !RegExp(r'^[1-9]\d*$').hasMatch(article)) {
        throw const FormatException('Unexpected SNUE annual event');
      }
      months.add(start.month);
      final identity = '$start:$last:$title';
      if (articles.containsKey(article) && articles[article] != identity) {
        throw const FormatException('Conflicting SNUE article');
      }
      articles[article] = identity;
      final scope = RegExp(r'^\[([^\]]+)\]').firstMatch(title)?[1];
      if (const {'대학원', '대학원/도서관', '부설초', '평생교육원'}.contains(scope)) continue;
      events[article] = AcademicEvent(
        sourceId: article,
        title: title,
        start: start,
        end: DateTime(last.year, last.month, last.day + 1),
        url:
            'https://www.snue.ac.kr/snue/sm/schdul/schdulList.do?mi=1281&schdulId=1000',
      );
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete SNUE annual calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
