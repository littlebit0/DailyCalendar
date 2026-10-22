import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Kangwon National University Chuncheon/Samcheok calendar (`chuncheon_calender`).
class KangwonAcademicSource implements AcademicSource {
  KangwonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const _page = 'https://www.kangwon.ac.kr/ko/bbs/714/list.do';
  @override
  String get id => 'kangwon';
  @override
  String get name => '강원대학교';
  @override
  Uri get website => Uri.parse(_page);
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (var month = 1; month <= 12; month++) {
      if (month > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            Uri.https(
              'www.kangwon.ac.kr',
              '/neibis-api/v1/core/bbs/plan/calendar',
              {
                'bbsId': 'chuncheon_calender',
                'searchYear': '$year',
                'searchMonth': '$month',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      // Multi-month events repeat in every month they overlap.
      for (final event in parse(utf8.decode(response.bodyBytes), year, month)) {
        if (events.containsKey(event.sourceId) &&
            jsonEncode(events[event.sourceId]!.toJson()) !=
                jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting Kangwon calendar identity');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Kangwon calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    if (month < 1 || month > 12) {
      throw const FormatException('Invalid Kangwon request month');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['icon'] != 'success' ||
        decoded['data'] is! List) {
      throw const FormatException('Invalid Kangwon calendar');
    }
    DateTime date(Object? value) {
      if (value is! String ||
          !RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid Kangwon date');
      }
      final parts = value.split('.').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid Kangwon date');
      }
      return result;
    }

    final events = <AcademicEvent>[];
    for (final row in decoded['data'] as List) {
      if (row is! Map ||
          row['pstSn'] is! int ||
          row['bbsId'] != 'chuncheon_calender' ||
          row['dataSttsCd'] != 'A' ||
          !const [1, 2, 3, 4, 5].contains(row['cd1Vl']) ||
          row['ttl'] is! String ||
          (row['ttl'] as String).trim().isEmpty) {
        throw const FormatException('Invalid Kangwon event');
      }
      final start = date(row['etc1Cn']);
      final last = date(row['etc3Cn'] == '' ? row['etc1Cn'] : row['etc3Cn']);
      final end = DateTime(last.year, last.month, last.day + 1);
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected Kangwon period');
      }
      final title = (row['ttl'] as String).trim();
      // The page shows a campus badge; 5 is the shared (공통) category.
      final campus = switch (row['cd1Vl']) {
        1 => '춘천',
        2 => '삼척',
        3 => '강릉',
        4 => '원주',
        _ => null,
      };
      events.add(
        AcademicEvent(
          sourceId: row['pstSn'].toString(),
          title: campus == null || title.endsWith('($campus)')
              ? title
              : '$title ($campus)',
          start: start,
          end: end,
          url: _page,
        ),
      );
    }
    return events;
  }

  @override
  void close() => _client.close();
}
