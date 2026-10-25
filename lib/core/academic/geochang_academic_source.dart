import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

/// Changwon's Geochang campus publishes its own academic administration dates.
class GeochangAcademicSource implements AcademicSource {
  GeochangAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'changwon-geochang';
  @override
  String get name => '국립창원대학교 거창캠퍼스';
  @override
  Uri get website =>
      Uri.https('www.gc.ac.kr', '/CW0301/101014.asp', {'mi': '101014'});
  @override
  void close() => _client.close();

  static final _home = Uri.https('www.gc.ac.kr', '/');
  static final _board = Uri.https('www.gc.ac.kr', '/CW0401/101001.asp');

  Future<String> _read(Uri uri, {Map<String, String>? form}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final headers = {'User-Agent': 'Mozilla/5.0', 'Referer': _home.toString()};
    final response =
        await (form == null
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: form))
            .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
      throw const FormatException('Geochang academic source unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = parseAnnual(await _read(website), year, website.toString());
    final home = await _read(_home);
    for (final (month, link) in selectHomeMonths(home, year).indexed) {
      events.addAll(
        parseHomeMonth(await _read(link), year, month + 1, link.toString()),
      );
    }
    final search = await _read(
      _board,
      form: {'select1': 'title', 's_text': '계절'},
    );
    final notice = selectPreviousWinter(search, year - 1);
    events.add(
      parsePreviousWinter(await _read(notice), year - 1, notice.toString()),
    );
    final unique = <String, AcademicEvent>{};
    for (final event in events) {
      if (event.start.isBefore(DateTime(year + 1)) &&
          event.end.isAfter(DateTime(year))) {
        unique[event.sourceId] = event;
      }
    }
    if (unique.isEmpty) throw const FormatException('Empty Geochang calendar');
    return unique.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
  static DateTime _date(int year, int month, int day) {
    final value = DateTime(year, month, day);
    if (year < 1900 ||
        year > 9999 ||
        value.year != year ||
        value.month != month ||
        value.day != day) {
      throw const FormatException('Invalid Geochang date');
    }
    return value;
  }

  static AcademicEvent _event(
    DateTime start,
    DateTime last,
    String title,
    String url,
  ) {
    title = _clean(title);
    if (title.isEmpty || last.isBefore(start)) {
      throw const FormatException('Invalid Geochang event');
    }
    return AcademicEvent(
      sourceId: '${start.toIso8601String()}/${last.toIso8601String()}/$title',
      title: title,
      start: start,
      end: DateTime(last.year, last.month, last.day + 1),
      url: url,
    );
  }

  static (DateTime, DateTime) _period(String value, int year) {
    final match = RegExp(
      r'^(\d{2})[.-](\d{2})(?:\s*~\s*(\d{2})[.-](\d{2}))?$',
    ).firstMatch(_clean(value));
    if (match == null) {
      throw const FormatException('Unrecognized Geochang period');
    }
    final firstMonth = int.parse(match[1]!);
    final start = _date(year, firstMonth, int.parse(match[2]!));
    if (match[3] == null) return (start, start);
    final lastMonth = int.parse(match[3]!);
    final last = _date(
      lastMonth < firstMonth ? year + 1 : year,
      lastMonth,
      int.parse(match[4]!),
    );
    if (last.isBefore(start)) {
      throw const FormatException('Reversed Geochang period');
    }
    return (start, last);
  }

  static List<AcademicEvent> parseAnnual(String body, int year, String url) {
    final doc = html.parse(body);
    if (!doc
        .querySelectorAll('h3.content_h3')
        .any((e) => _clean(e.text) == '$year년')) {
      throw const FormatException('Wrong Geochang academic year');
    }
    final tables = doc.querySelectorAll('table.tbl_st');
    if (tables.length != 1) {
      throw const FormatException('Missing Geochang annual table');
    }
    final result = <AcademicEvent>[];
    final months = <String>{};
    for (final row in tables.single.querySelectorAll('tbody > tr')) {
      final cells = row.querySelectorAll('td');
      if (cells.length != 2) {
        throw const FormatException('Invalid Geochang month row');
      }
      final ym = RegExp(
        r'^(\d{4})\s*(\d{1,2})$',
      ).firstMatch(_clean(cells[0].text));
      if (ym == null) {
        throw const FormatException('Missing Geochang year/month');
      }
      final rowYear = int.parse(ym[1]!), month = int.parse(ym[2]!);
      if ((rowYear == year && (month < 3 || month > 12)) ||
          (rowYear == year + 1 && (month < 1 || month > 2)) ||
          (rowYear != year && rowYear != year + 1) ||
          !months.add('$rowYear/$month')) {
        throw const FormatException('Invalid Geochang academic month');
      }
      final spans = cells[1].children
          .where(
            (element) =>
                element.localName == 'span' &&
                RegExp(
                  r'^\d{2}-\d{2}(?:\s*~\s*\d{2}-\d{2})?$',
                ).hasMatch(_clean(element.text)),
          )
          .toList();
      if (spans.isEmpty) throw const FormatException('Empty Geochang month');
      for (final span in spans) {
        final (start, last) = _period(span.text, rowYear);
        if (start.month != month) {
          throw const FormatException('Wrong Geochang date month');
        }
        var title = '';
        final nodes = cells[1].nodes;
        for (
          var index = nodes.indexOf(span) + 1;
          index < nodes.length;
          index++
        ) {
          final node = nodes[index];
          if (node is dom.Element && node.localName == 'br') break;
          if (node is dom.Element &&
              node.localName == 'span' &&
              RegExp(
                r'^\d{2}-\d{2}(?:\s*~\s*\d{2}-\d{2})?$',
              ).hasMatch(_clean(node.text))) {
            throw const FormatException('Missing Geochang row delimiter');
          }
          title += node is dom.Text
              ? node.data
              : node is dom.Element
              ? node.text
              : '';
        }
        result.add(_event(start, last, title, url));
      }
    }
    if (months.length != 12) {
      throw const FormatException('Incomplete Geochang academic year');
    }
    return result;
  }

  static List<Uri> selectHomeMonths(String body, int year) {
    final links = <int, Uri>{};
    for (final anchor in html.parse(body).querySelectorAll('a[href]')) {
      final link = _home.resolve(anchor.attributes['href']!);
      final month = int.tryParse(link.queryParameters['hday'] ?? '');
      if (link.scheme == 'https' &&
          link.host == _home.host &&
          link.path == '/${year}A.asp' &&
          (month == 1 || month == 2)) {
        links[month!] = link.replace(fragment: '');
      }
    }
    if (links.length != 2) {
      throw const FormatException(
        'Missing published Geochang January/February links',
      );
    }
    return [links[1]!, links[2]!];
  }

  /// The homepage lists a fixed number of events from the start of [month];
  /// one listed after that month proves the month itself was not cut off.
  static List<AcademicEvent> parseHomeMonth(
    String body,
    int year,
    int month,
    String url,
  ) {
    final result = <AcademicEvent>[];
    var complete = false;
    for (final box in html.parse(body).querySelectorAll('div.result-content')) {
      final rows = box.querySelectorAll('p');
      if (rows.length != 2) {
        throw const FormatException('Invalid Geochang homepage event');
      }
      final (start, last) = _period(rows[0].text, year);
      if (start.month > month) complete = true;
      if (start.month <= 2) result.add(_event(start, last, rows[1].text, url));
    }
    if (!complete) {
      throw const FormatException('Truncated Geochang homepage month');
    }
    if (result.isEmpty) {
      throw const FormatException('Empty Geochang January/February supplement');
    }
    return result;
  }

  static Uri selectPreviousWinter(String body, int previousYear) {
    final candidates = html
        .parse(body)
        .querySelectorAll('a[href]')
        .where(
          (a) =>
              _clean(a.text).replaceAll(' ', '') ==
              '$previousYear학년도동계계절학기개설안내',
        )
        .toList();
    if (candidates.length != 1) {
      throw const FormatException('Missing previous Geochang winter notice');
    }
    final uri = _board.resolve(candidates.single.attributes['href']!);
    if (uri.scheme != 'https' ||
        uri.host != _board.host ||
        uri.path != _board.path ||
        !RegExp(r'^\d+$').hasMatch(uri.queryParameters['bno'] ?? '')) {
      throw const FormatException('Invalid Geochang notice link');
    }
    return uri;
  }

  static AcademicEvent parsePreviousWinter(
    String body,
    int previousYear,
    String url,
  ) {
    final text = _clean(html.parse(body).body!.text);
    if (!text.replaceAll(' ', '').contains('$previousYear학년도동계계절학기개설안내')) {
      throw const FormatException('Wrong Geochang winter notice year');
    }
    final matches = RegExp(
      r'개설기간\s*:\s*(\d{4})\.\s*(\d{1,2})\.\s*(\d{1,2})\.\s*~\s*(\d{4})\.\s*(\d{1,2})\.\s*(\d{1,2})\.',
    ).allMatches(text).toList();
    if (matches.length != 1) {
      throw const FormatException('Missing exact Geochang winter dates');
    }
    final m = matches.single;
    final start = _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    final last = _date(int.parse(m[4]!), int.parse(m[5]!), int.parse(m[6]!));
    if (start.year != previousYear ||
        start.month != 12 ||
        last.year != previousYear + 1 ||
        last.month != 1) {
      throw const FormatException('Wrong Geochang winter period');
    }
    return _event(start, last, '$previousYear학년도 동계 계절학기', url);
  }
}
