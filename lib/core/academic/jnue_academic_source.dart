import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Reads the latest university-published annual document through its public viewer.
/// The document includes January through the following February. Undated source
/// entries stay undated: a neighbouring row's date must never be inherited.
class JnueAcademicSource implements AcademicSource {
  JnueAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'jnue';
  @override
  String get name => '전주교육대학교';
  @override
  Uri get website =>
      Uri.https('www.jnue.kr', '/portal/bbs/external_article_list.ajax');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          website,
          body: {
            'pageIndex': '1',
            'pageSize': '10',
            'searchCondition': '1',
            'searchKeyword': '$year학년도 학사력',
            'boardId': 'BBS00000000000000105',
            'menuId': 'M0004000100010000',
            'date': '',
            'category': '',
          },
        )
        .timeout(const Duration(seconds: 20));
    final mask = selectDocument(_body(response), year);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final request = http.Request(
      'GET',
      Uri.https('www.jnue.kr', '/synap/viewer.do', {'fileMask': mask}),
    )..followRedirects = false;
    final redirect = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    await redirect.stream.drain<void>();
    final location = Uri.tryParse(redirect.headers['location'] ?? '');
    final directory = location?.queryParameters['rs'];
    if (redirect.statusCode != 302 ||
        location?.scheme != 'https' ||
        location?.host != 'portal.jnue.kr' ||
        location?.path != '/synap/skin/doc.html' ||
        location?.queryParameters['fn'] != mask ||
        directory == null ||
        !RegExp(r'^/synap/conv/\d{6}/$').hasMatch(directory)) {
      throw const FormatException('Unexpected JNUE public viewer');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _body(
      await _client
          .get(Uri.https('portal.jnue.kr', '$directory$mask.xml'))
          .timeout(const Duration(seconds: 20)),
    );
    if (!RegExp(r'<file_type>hwp2k</file_type>').hasMatch(index) ||
        !RegExp(r'<filespage_cnt>1</filespage_cnt>').hasMatch(index)) {
      throw const FormatException('Unsupported JNUE published document layout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final body = _body(
      await _client
          .get(Uri.https('portal.jnue.kr', '$directory$mask.files/1.html'))
          .timeout(const Duration(seconds: 20)),
    );
    return parse(
      body,
      year,
      Uri.https('www.jnue.kr', '/synap/viewer.do', {
        'fileMask': mask,
      }).toString(),
    );
  }

  static String _body(http.Response response) {
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('JNUE published calendar unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  static String selectDocument(String body, int year) {
    final data = jsonDecode(body);
    if (data is! Map || data['list'] is! List) {
      throw const FormatException('Invalid JNUE annual notice list');
    }
    final notices =
        (data['list'] as List)
            .whereType<Map>()
            .where(
              (row) =>
                  row['useYn'] == 'Y' &&
                  RegExp(
                    '^$year학년도 학사력 안내',
                  ).hasMatch(row['title']?.toString() ?? ''),
            )
            .toList()
          ..sort(
            (a, b) => (b['boardSeq'] as int).compareTo(a['boardSeq'] as int),
          );
    if (notices.isEmpty) {
      throw const FormatException('No published JNUE annual calendar');
    }
    final files = notices.first['files'];
    if (files is! List) {
      throw const FormatException('Missing JNUE calendar attachment');
    }
    final candidates = files
        .whereType<Map>()
        .where(
          (f) =>
              (f['fileExt'] == 'hwp' || f['fileExt'] == 'hwpx') &&
              (f['orginlNm']?.toString() ?? '').contains('$year학년도 학사력'),
        )
        .toList();
    if (candidates.length != 1 ||
        !RegExp(
          r'^\d{8}[a-zA-Z0-9]+$',
        ).hasMatch(candidates.single['fileMask']?.toString() ?? '')) {
      throw const FormatException('Unsupported JNUE annual attachment');
    }
    return candidates.single['fileMask'] as String;
  }

  static List<AcademicEvent> parse(String body, int year, String url) {
    final doc = html.parse(body);
    if (doc.querySelector('.custom-textbox')?.text.trim() != '$year') {
      throw const FormatException('Unexpected JNUE annual year');
    }
    final headers = doc
        .querySelectorAll('#table_1 > tbody > tr')
        .where(
          (row) =>
              row.children.length == 8 &&
                  RegExp(
                    r'^1 January$',
                  ).hasMatch(row.children.first.text.trim()) ||
              row.children.length == 8 &&
                  RegExp(
                    r'^[2-7] (February|March|April|May|June|July)$',
                  ).hasMatch(row.children.first.text.trim()),
        )
        .toList();
    if (headers.length != 7) {
      throw const FormatException('Incomplete JNUE calendar months');
    }
    final events = <AcademicEvent>[];
    DateTime date(int y, int m, int d) {
      final value = DateTime(y, m, d);
      if (value.year != y || value.month != m || value.day != d) {
        throw const FormatException('Invalid JNUE numeric date');
      }
      return value;
    }

    for (var i = 0; i < 7; i++) {
      final cells = headers[i].children;
      for (final offset in [0, 4]) {
        final month = i + 1 + (offset == 4 ? 7 : 0);
        final calendarYear = year + (month > 12 ? 1 : 0);
        final calendarMonth = (month - 1) % 12 + 1;
        final heading = cells[offset].text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (!RegExp('(?:^| )$calendarMonth [A-Za-z]+\$').hasMatch(heading) ||
            (month > 12 && !heading.startsWith('${year + 1} '))) {
          throw const FormatException('Invalid JNUE month ordering');
        }
        final dates = cells[offset + 2].children
            .where((e) => e.localName == 'p')
            .toList();
        final titles = cells[offset + 3].children
            .where((e) => e.localName == 'p')
            .toList();
        if (dates.isEmpty || dates.length != titles.length) {
          throw const FormatException('Incomplete JNUE date/title pairing');
        }
        for (var j = 0; j < dates.length; j++) {
          final raw = dates[j].text.replaceAll(RegExp(r'\s+'), '');
          final title = titles[j].text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.isEmpty) {
            throw const FormatException('Missing JNUE event title');
          }
          if (raw.isEmpty) {
            continue; // Explicitly blank in the university document.
          }
          final match = RegExp(
            r'^(\d{1,2})(?:~(?:(\d{1,2})\.)?(\d{1,2}))?$',
          ).firstMatch(raw);
          if (match == null) {
            throw const FormatException('Invalid JNUE event date');
          }
          final start = date(calendarYear, calendarMonth, int.parse(match[1]!));
          final endMonth = int.tryParse(match[2] ?? '') ?? calendarMonth;
          final last = match[3] == null
              ? start
              : date(
                  calendarYear + (endMonth < calendarMonth ? 1 : 0),
                  endMonth,
                  int.parse(match[3]!),
                );
          if (last.isBefore(start)) {
            throw const FormatException('Invalid JNUE event period');
          }
          if (start.year == year) {
            events.add(
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
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty JNUE annual document');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
