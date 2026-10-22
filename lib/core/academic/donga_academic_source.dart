import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class DongaAcademicSource implements AcademicSource {
  DongaAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'donga';
  @override
  String get name => '동아대학교';
  @override
  Uri get website =>
      Uri.https('www.donga.ac.kr', '/community/academic-calendar');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website,
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
        )
        .timeout(const Duration(seconds: 20));
    checkAcademicResponse(response);
    final events = <String, AcademicEvent>{};
    // The page publishes one academic year (March to the next February).
    for (final e in parseAnnual(utf8.decode(response.bodyBytes))) {
      if (e.start.isBefore(DateTime(year + 1)) &&
          e.end.isAfter(DateTime(year))) {
        events[e.sourceId] = e;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Donga calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
  static DateTime _date(int y, int m, int d) {
    final v = DateTime(y, m, d);
    if (v.year != y || v.month != m || v.day != d) {
      throw const FormatException('Invalid Donga date');
    }
    return v;
  }

  static AcademicEvent _event(
    String title,
    DateTime start,
    DateTime last,
    String url,
  ) {
    if (title.isEmpty || last.isBefore(start)) {
      throw const FormatException('Invalid Donga event');
    }
    // Same ID format as earlier releases, so imported events stay linked.
    return AcademicEvent(
      sourceId:
          '${start.toIso8601String()}:${last.toIso8601String()}:${title.replaceAll(RegExp(r'\s+'), '')}',
      title: title,
      start: start,
      end: DateTime(last.year, last.month, last.day + 1),
      url: url,
    );
  }

  static (DateTime, DateTime) _range(String raw, int year) {
    raw = raw
        .replaceAll(RegExp(r'\([월화수목금토일A-Z]+\)'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('∼', '~');
    final m = RegExp(
      r'^(?:(\d{4})\.)?(\d{1,2})\.(\d{1,2})\.?(?:~(?:(\d{4})\.)?(\d{1,2})\.(\d{1,2})\.?)?$',
    ).firstMatch(raw);
    if (m == null) throw const FormatException('Invalid Donga numeric period');
    final sy = int.tryParse(m[1] ?? '') ?? year,
        sm = int.parse(m[2]!),
        em = int.tryParse(m[5] ?? '') ?? sm;
    final start = _date(sy, sm, int.parse(m[3]!));
    final last = m[5] == null
        ? start
        : _date(
            int.tryParse(m[4] ?? '') ?? sy + (em < sm ? 1 : 0),
            em,
            int.parse(m[6]!),
          );
    if (sy != year || last.isBefore(start)) {
      throw const FormatException('Unexpected Donga year');
    }
    return (start, last);
  }

  static Element _table(Document doc, String heading) {
    final headings = doc
        .querySelectorAll('h3.dau-cd-h')
        .where((e) => _clean(e.text) == heading)
        .toList();
    final table = headings.length == 1
        ? headings.single.nextElementSibling?.querySelector('table.dau-cd-tbl')
        : null;
    if (table == null) throw FormatException('Missing Donga $heading');
    return table;
  }

  /// Every row of the published academic-year page: schedule table, academic
  /// milestones, semester opening days and designated make-up days.
  static List<AcademicEvent> parseAnnual(String body) {
    final doc = html.parse(body);
    final years = doc
        .querySelectorAll('h3.dau-cd-h')
        .map((e) => RegExp(r'^(\d{4})학년도 학사일정$').firstMatch(_clean(e.text)))
        .whereType<RegExpMatch>()
        .toList();
    if (years.length != 1) {
      throw const FormatException('Unexpected Donga annual year');
    }
    final year = int.parse(years.single[1]!);
    final events = <AcademicEvent>[];
    const url = 'https://www.donga.ac.kr/community/academic-calendar';
    final rows = _table(doc, '$year학년도 학사일정').querySelectorAll('tbody > tr');
    final semesters = <String>[];
    for (final row in rows) {
      final semester = row.querySelector('th');
      if (semester != null) semesters.add(_clean(semester.text));
      final cells = row.querySelectorAll('td');
      if (cells.length != 2) {
        throw const FormatException('Incomplete Donga schedule row');
      }
      final raw = _clean(cells[1].text);
      // January/February rows of the academic year carry the following year.
      final y = RegExp(r'^(\d{4})\.').firstMatch(raw);
      if (y == null) {
        throw const FormatException('Missing Donga annual numeric year');
      }
      final (start, last) = _range(raw, int.parse(y[1]!));
      if (start.isBefore(DateTime(year)) ||
          !start.isBefore(DateTime(year + 1, 3))) {
        throw const FormatException('Invalid Donga annual scope');
      }
      events.add(_event(_clean(cells[0].text), start, last, url));
    }
    if (semesters.join(',') != '1학기,2학기') {
      throw const FormatException('Invalid Donga semester scope');
    }
    final guide = doc.querySelector('.dau-cal-guide');
    final groups = guide?.querySelectorAll('ul.dau-cal-glist') ?? [];
    if (groups.length != 2) {
      throw const FormatException('Missing Donga academic milestones');
    }
    for (final group in groups) {
      final semester = _clean(group.previousElementSibling?.text ?? '');
      if (semester != '제${groups.indexOf(group) + 1}학기') {
        throw const FormatException('Invalid Donga milestone semester');
      }
      final items = group.querySelectorAll('li');
      if (items.length != 6) {
        throw const FormatException('Incomplete Donga milestones');
      }
      for (final item in items) {
        final m = RegExp(
          r'^(.+?):\s*(\d{4}\.\s*\d{1,2}\.\s*\d{1,2}\.?)',
        ).firstMatch(_clean(item.text));
        if (m == null) throw const FormatException('Invalid Donga milestone');
        final (start, last) = _range(m[2]!, year);
        events.add(_event('$semester ${m[1]}', start, last, url));
      }
    }
    final openings = RegExp(
      r'([12])학기 개시일:\s*(\d{1,2}\.\s*\d{1,2}\.?)',
    ).allMatches(guide!.text).toList();
    if (openings.map((m) => m[1]).join() != '12') {
      throw const FormatException('Missing Donga semester opening days');
    }
    for (final m in openings) {
      final (start, last) = _range(m[2]!, year);
      events.add(_event('제${m[1]}학기 개시일', start, last, url));
    }
    // Expand actual rowspans so the second Chuseok day keeps its shared label.
    final pending = <int, (Element, int)>{};
    for (final row in _table(
      doc,
      '$year학년도 지정보강일',
    ).querySelectorAll('tbody > tr')) {
      final cells = <int, Element>{};
      for (final e in pending.entries.toList()) {
        cells[e.key] = e.value.$1;
        if (e.value.$2 == 1) {
          pending.remove(e.key);
        } else {
          pending[e.key] = (e.value.$1, e.value.$2 - 1);
        }
      }
      var column = 0;
      for (final cell in row.children) {
        while (cells.containsKey(column)) {
          column++;
        }
        cells[column] = cell;
        final span = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 0;
        if (span < 1 || span > 8) {
          throw const FormatException('Invalid Donga makeup rowspan');
        }
        if (span > 1) pending[column] = (cell, span - 1);
        column++;
      }
      if (cells.length != 4 || !cells.containsKey(3)) {
        throw const FormatException('Incomplete Donga makeup day');
      }
      final semester = _clean(cells[0]!.text), title = _clean(cells[2]!.text);
      final (holiday, holidayEnd) = _range(cells[1]!.text, year);
      final (makeup, makeupEnd) = _range(cells[3]!.text, year);
      events.add(_event(title, holiday, holidayEnd, url));
      events.add(_event('제$semester 지정보강일($title)', makeup, makeupEnd, url));
    }
    return events;
  }

  @override
  void close() => _client.close();
}
