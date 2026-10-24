import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KhuAcademicSource implements AcademicSource {
  KhuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'khu';
  @override
  String get name => '경희대학교';
  @override
  Uri get website => Uri.parse(
    'https://haksa.khu.ac.kr/nhaksa/user/contents/view.do?menuNo=21200042',
  );
  // The official 2025 annual page misprints 2026.1.2 as 2025.1.2, so only
  // academic years from 2026 are imported (user decision, 2026-10-24).
  static const firstAcademicYear = 2026;

  Future<String> _get(Uri url) async {
    final response = await _client
        .get(url)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('KHU calendar unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  static Uri _link(String body, Uri base, String label) {
    final links = html
        .parse(body)
        .querySelectorAll('a[href]')
        .where(
          (e) =>
              clean(e.text) == label && !e.attributes['href']!.startsWith('#'),
        );

    final urls = links.map((e) => base.resolve(e.attributes['href']!)).toSet();
    if (urls.length != 1 ||
        urls.single.host != base.host ||
        urls.single.path != base.path ||
        urls.single.queryParameters['menuNo'] == null) {
      throw const FormatException('Missing KHU published year/semester link');
    }
    return urls.single.replace(scheme: 'https');
  }

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    if (year < firstAcademicYear) {
      throw const FormatException('Unsupported KHU academic year');
    }
    final index = await _get(website);
    final events = <String, AcademicEvent>{};
    // January and February belong to the previous academic year's official
    // annual page; the calendar year itself starts in this year's page.
    for (final academicYear in [
      year,
      if (year - 1 >= firstAcademicYear) year - 1,
    ]) {
      final url = _link(index, website, '$academicYear학년도 학사일정');
      String body = index;
      if (url != website) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        body = await _get(url);
      }
      for (final event in parseAnnual(body, academicYear, url)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published KHU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static String clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static AcademicEvent _event(
    String dates,
    String title,
    int anchorYear,
    Uri url,
  ) {
    final found = RegExp(
      r'(?:(\d{4})\s*\.\s*)?(\d{1,2})(?:\s*\.\s*|\s+)(\d{1,2})\s*\.?\s*\([^)]*\)',
    ).allMatches(dates).toList();
    if (found.isEmpty || found.length > 2 || clean(title).isEmpty) {
      throw const FormatException('Invalid KHU calendar event');
    }
    final remainder = dates;
    var remaining = remainder;
    for (final match in found.reversed) {
      remaining = remaining.replaceRange(match.start, match.end, '');
    }
    if (remaining.replaceAll(RegExp(r'[\s\-~–]'), '').isNotEmpty) {
      throw const FormatException('Unrecognized KHU date text');
    }
    DateTime date(RegExpMatch match, int defaultYear) {
      final y = match[1] == null ? defaultYear : int.parse(match[1]!);
      final m = int.parse(match[2]!);
      final d = int.parse(match[3]!);
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        throw const FormatException('Invalid KHU date');
      }
      return result;
    }

    final first = date(found.first, anchorYear);
    final last = date(
      found.last,
      int.parse(found.last[2]!) < first.month ? first.year + 1 : first.year,
    );
    if (last.isBefore(first) ||
        first.year < anchorYear - 1 ||
        first.year > anchorYear ||
        last.difference(first).inDays > 366) {
      throw const FormatException('Unexpected KHU period');
    }
    final text = clean(title);
    return AcademicEvent(
      sourceId: '$first:$last:$text',
      title: text,
      start: first,
      end: DateTime(last.year, last.month, last.day + 1),
      url: url.toString(),
    );
  }

  static List<AcademicEvent> parseAnnual(
    String body,
    int year,
    Uri url, {
    Set<int>? expectedMonths,
  }) {
    final expected = expectedMonths ?? {for (var m = 1; m <= 12; m++) m};
    final document = html.parse(body);
    final events = <AcademicEvent>[];
    final months = <int>{};
    var selectedYear = year;
    for (final block in document.querySelectorAll('.month')) {
      final label = clean(block.text);
      final heading = RegExp(r'^(?:(\d{4})\s*)?(\d{1,2})월$').firstMatch(label);
      if (heading == null) {
        throw const FormatException('Invalid KHU month heading');
      }
      if (heading[1] != null) selectedYear = int.parse(heading[1]!);
      final month = int.parse(heading[2]!);
      if (!expected.contains(month) ||
          !months.add(month) ||
          selectedYear != (month < 3 ? year + 1 : year)) {
        throw const FormatException('Unexpected KHU annual month');
      }
      final cells = block.parent!.parent!.children
          .where((e) => e.localName == 'td')
          .toList();
      if (cells.length != 4) {
        throw const FormatException('Invalid KHU monthly row');
      }
      List<Element> items(Element cell) => cell
          .querySelectorAll('li')
          .where((e) => clean(e.text).isNotEmpty)
          .toList();
      final dates = items(cells[2]);
      final titles = items(cells[3]);
      if (dates.isEmpty || dates.length != titles.length) {
        throw const FormatException('Incomplete KHU month');
      }
      for (var i = 0; i < dates.length; i++) {
        final event = _event(
          clean(dates[i].text),
          titles[i].text,
          selectedYear,
          url,
        );
        if (event.start.month != month) {
          throw const FormatException('Wrong KHU monthly event');
        }
        events.add(event);
      }
    }
    if (months.length != expected.length) {
      throw const FormatException('Incomplete KHU academic year');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
