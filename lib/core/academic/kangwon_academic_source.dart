import 'dart:convert';

import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Kangwon National University calendar for every campus: the
/// Chuncheon/Samcheok board (`chuncheon_calender`) merged with the
/// Gangneung/Wonju board (`gwnucalender`).
class KangwonAcademicSource implements AcademicSource {
  KangwonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const _page = 'https://www.kangwon.ac.kr/ko/bbs/714/list.do';
  static const _pages = {
    'chuncheon_calender': _page,
    'gwnucalender': 'https://www.kangwon.ac.kr/ko/bbs/873/list.do',
  };
  @override
  String get id => 'kangwon';
  @override
  String get name => '강원대학교';
  @override
  Uri get website => Uri.parse(_page);
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    // A failure on either board fails the whole fetch, never a partial year.
    final boards = <Map<String, AcademicEvent>>[];
    for (final bbsId in _pages.keys) {
      final events = <String, AcademicEvent>{};
      for (var month = 1; month <= 12; month++) {
        if (boards.isNotEmpty || month > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        // robots.txt disallows /neibis-api/; the allowed list page embeds
        // the same monthly posts.
        final response = await _client
            .get(
              Uri.parse(_pages[bbsId]!).replace(
                queryParameters: {
                  'searchYear': '$year',
                  'searchMonth': '$month',
                },
              ),
            )
            .timeout(const Duration(seconds: 20));
        checkAcademicResponse(response);
        // Multi-month events repeat in every month they overlap.
        for (final event in parse(
          utf8.decode(response.bodyBytes),
          year,
          month,
          bbsId: bbsId,
        )) {
          if (events.containsKey(event.sourceId) &&
              jsonEncode(events[event.sourceId]!.toJson()) !=
                  jsonEncode(event.toJson())) {
            throw const FormatException(
              'Conflicting Kangwon calendar identity',
            );
          }
          events[event.sourceId] = event;
        }
      }
      boards.add(events);
    }
    // Rows both boards publish identically keep the Chuncheon/Samcheok post.
    String same(AcademicEvent e) => '${e.title}\n${e.start}\n${e.end}';
    final shared = {for (final e in boards.first.values) same(e)};
    final events = [
      ...boards.first.values,
      ...boards.last.values.where((e) => !shared.contains(same(e))),
    ];
    if (events.isEmpty) {
      throw const FormatException('No published Kangwon calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int year,
    int month, {
    String bbsId = 'chuncheon_calender',
  }) {
    final page = _pages[bbsId];
    if (page == null || month < 1 || month > 12) {
      throw const FormatException('Invalid Kangwon request month');
    }
    // The list page must be this board's requested month.
    final shown = RegExp(
      r"var toDetailParam = '[^']*searchYear=(\d+)&(?:amp;)*searchMonth=(\d+)&",
    ).firstMatch(body);
    if (!body.contains("var bbsId = '$bbsId';") ||
        !body.contains('var scheduleData = [];') ||
        shown == null ||
        shown.group(1) != '$year' ||
        shown.group(2) != '$month') {
      throw const FormatException('Invalid Kangwon calendar');
    }
    // Each post is one `scheduleData.push({...})`; a title the page escapes
    // other than with HTML entities (quote, backslash) fails the count check.
    final rows = RegExp(
      r'scheduleData\.push\(\{\s*pstSn: (\d+),\s*'
      r'ttl: "([^"\\\n]*)"\.replace\([^\n]*\),\s*cd1Vl: (\d+),\s*'
      r'etc1Cn: "([^"]*)",\s*etc2Cn: "[^"]*",\s*'
      r'etc3Cn: "([^"]*)",\s*etc4Cn: "[^"]*",\s*etc5Cn: "[^"]*",\s*'
      r'dataSttsCd: "([^"]*)"\s*\}\);',
    ).allMatches(body).toList();
    if (rows.length != 'scheduleData.push('.allMatches(body).length) {
      throw const FormatException('Invalid Kangwon event');
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
    for (final match in rows) {
      final row = {
        'pstSn': int.parse(match[1]!),
        'ttl': academicHtmlText(match[2]!),
        'cd1Vl': int.parse(match[3]!),
        'etc1Cn': match[4],
        'etc3Cn': match[5],
        'dataSttsCd': match[6],
      };
      if (row['dataSttsCd'] != 'A' ||
          !const [0, 1, 2, 3, 4, 5].contains(row['cd1Vl']) ||
          (row['ttl'] as String).isEmpty) {
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
      // Graduate-only thesis rows are left out (undergraduate calendar).
      if (RegExp('학위(청구)?논문').hasMatch(title)) {
        continue;
      }
      // The page shows a campus badge; 5 is the shared (공통) category and the
      // Gangneung/Wonju board uses 0 (no badge).
      final campus = switch (row['cd1Vl']) {
        1 => '춘천',
        2 => '삼척',
        3 => '강릉',
        4 => '원주',
        _ => null,
      };
      events.add(
        AcademicEvent(
          // Post numbers restart per board; the original board keeps bare IDs.
          sourceId: bbsId == 'chuncheon_calender'
              ? '${row['pstSn']}'
              : '$bbsId:${row['pstSn']}',
          title: campus == null || title.endsWith('($campus)')
              ? title
              : '$title ($campus)',
          start: start,
          end: end,
          url: page,
        ),
      );
    }
    return events;
  }

  @override
  void close() => _client.close();
}
