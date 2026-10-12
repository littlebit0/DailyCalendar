import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KumohAcademicSource implements AcademicSource {
  KumohAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kumoh';
  @override
  String get name => '국립금오공과대학교';
  @override
  Uri get website => Uri.https('www.kumoh.ac.kr', '/ko/schedule_reg.do');

  Future<String> _get(Uri url) async {
    final response = await _client
        .get(
          url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Kumoh calendar unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  static int _count(String body) {
    final text = html.parse(body).querySelector('p.total strong')?.text.trim();
    final count = int.tryParse(text ?? '');
    if (count == null || count < 1 || count > 10000) {
      throw const FormatException('Missing Kumoh published article count');
    }
    return count;
  }

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final first = await _get(website);
    final count = _count(first);
    // The public list exposes articleLimit. Fetch its declared population in
    // one batch: date-only ordering can repeat/omit tied articles at page edges.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final body = await _get(
      website.replace(
        queryParameters: {
          'mode': 'list',
          'articleLimit': '$count',
          'article.offset': '0',
        },
      ),
    );
    final rows = parse(body);
    if (_count(body) != count ||
        rows.length != count ||
        rows.map((e) => e.sourceId).toSet().length != count) {
      throw const FormatException('Incomplete Kumoh calendar population');
    }
    final events = rows
        .where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        )
        .toList();
    if (events.isEmpty) {
      throw const FormatException('No published Kumoh calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body) {
    final document = html.parse(body);
    final table = document.querySelector('table.board-table');
    if (table == null ||
        !table.text.contains('시작일') ||
        !table.text.contains('종료일')) {
      throw const FormatException('Missing Kumoh calendar table');
    }
    final events = <AcademicEvent>[];
    DateTime date(String value) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid Kumoh date');
      }
      final p = value.split('-').map(int.parse).toList();
      final result = DateTime(p[0], p[1], p[2]);
      if (result.year != p[0] || result.month != p[1] || result.day != p[2]) {
        throw const FormatException('Invalid Kumoh date');
      }
      return result;
    }

    for (final row in table.querySelectorAll('tbody tr')) {
      final cells = row.querySelectorAll('td');
      final link = row.querySelector('td.title a[href]');
      if (cells.length != 6 || link == null) {
        throw const FormatException('Invalid Kumoh calendar row');
      }
      final article = Uri.parse(
        link.attributes['href']!,
      ).queryParameters['articleNo'];
      final title = link.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final start = date(cells[2].text.trim());
      final last = date(cells[3].text.trim());
      if (article == null ||
          !RegExp(r'^[1-9]\d*$').hasMatch(article) ||
          title.isEmpty ||
          last.isBefore(start) ||
          last.difference(start).inDays > 366) {
        throw const FormatException('Invalid Kumoh calendar event');
      }
      events.add(
        AcademicEvent(
          sourceId: article,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: 'https://www.kumoh.ac.kr/ko/schedule_reg.do',
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Kumoh calendar page');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
