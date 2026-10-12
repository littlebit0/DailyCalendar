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
  Uri get website => Uri.https(
    'www.donga.ac.kr',
    '/kor/CMS/Contents/Contents.do',
    {'mCode': 'MN173'},
  );
  Future<String> _get(Uri uri) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Donga calendar unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    void add(Iterable<AcademicEvent> data) {
      for (final e in data) {
        if (e.start.isBefore(DateTime(year + 1)) &&
            e.end.isAfter(DateTime(year))) {
          events[e.sourceId] = e;
        }
      }
    }

    add(parseAnnual(await _get(website), year));
    for (final selected in [year - 1, year]) {
      final url =
          Uri.https('www.donga.ac.kr', '/kor/CMS/ScheduleMgr/YearList.do', {
            'calendar_month': '12',
            'calendar_year': '$selected',
            'mCode': 'MN173',
            'part': 'false',
          });
      final entries = parseLegacy(await _get(url), selected);
      final relevant = entries.where(
        (e) => selected < year
            ? e.end.isAfter(DateTime(year))
            : e.start.month <= 2,
      );
      for (final entry in relevant) {
        final detailUrl =
            Uri.https('www.donga.ac.kr', '/kor/CMS/ScheduleMgr/Detail.do', {
              'year': '${entry.start.year}',
              'month': '${entry.start.month}',
              'day': '${entry.start.day}',
              'searchItem1': '',
            });
        final details = parseDetail(
          await _get(detailUrl),
          detailUrl.toString(),
        );
        final matches = details
            .where((e) => e.sourceId == entry.sourceId)
            .toList();
        if (matches.length != 1) {
          throw const FormatException('Donga annual/detail date mismatch');
        }
        add(matches);
      }
    }
    for (final (selected, winter, requiredNotice) in [
      (year - 1, true, true),
      (year, false, true),
      (year, true, false),
    ]) {
      final searchUrl =
          Uri.https('www.donga.ac.kr', '/kor/CMS/Board/Board.do', {
            'mCode': 'MN171',
            'mgr_seq': '63',
            'mode': 'list',
            'searchID': 'sch001',
            'searchKeyword': '$selected학년도 ${winter ? '동계' : '하계'}계절학기',
          });
      final notice = selectSeasonalNotice(
        await _get(searchUrl),
        selected,
        winter,
      );
      if (notice == null) {
        if (requiredNotice) {
          throw const FormatException('Missing Donga seasonal source');
        }
        continue; // Future winter course may not yet be published.
      }
      add([
        parseSeasonal(await _get(notice), selected, winter, notice.toString()),
      ]);
    }
    if (events.isEmpty) throw const FormatException('Empty Donga calendar');
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

  static List<AcademicEvent> parseAnnual(String body, int year) {
    final doc = html.parse(body);
    final root = doc.querySelector('.contents_view_wrap');
    if (root?.querySelector('h3')?.text.trim() != '$year학년도 학사일정') {
      throw const FormatException('Unexpected Donga annual year');
    }
    final tables = root!.querySelectorAll('table.tbl-type01');
    if (tables.length != 2) {
      throw const FormatException('Incomplete Donga annual tables');
    }
    final events = <AcademicEvent>[];
    const url =
        'https://www.donga.ac.kr/kor/CMS/Contents/Contents.do?mCode=MN173';
    final rows = tables.first.querySelectorAll('tbody > tr');
    if (rows.length != 2) {
      throw const FormatException('Incomplete Donga semesters');
    }
    for (final (i, row) in rows.indexed) {
      if (row.children.length != 3 ||
          row.children.first.text.trim() != '${i + 1}학기') {
        throw const FormatException('Invalid Donga semester scope');
      }
      final dates = row.children[1].querySelectorAll('ul.c-list01 > li'),
          titles = row.children[2].querySelectorAll('ul.c-list01 > li');
      if (dates.isEmpty || dates.length != titles.length) {
        throw const FormatException('Incomplete Donga date/title pairs');
      }
      for (var j = 0; j < dates.length; j++) {
        final raw = _clean(dates[j].text), title = _clean(titles[j].text);
        if (raw.isEmpty && title.isEmpty) continue;
        // January/February graduation is explicitly published for the following year.
        final y = RegExp(r'^(\d{4})').firstMatch(raw);
        if (y == null) {
          throw const FormatException('Missing Donga annual numeric year');
        }
        final (start, last) = _range(raw, int.parse(y[1]!));
        if (start.year < year || start.year > year + 1) {
          throw const FormatException('Invalid Donga annual scope');
        }
        events.add(_event(title, start, last, url));
      }
    }
    final milestoneGroups = root
        .querySelectorAll('ul.c-list01')
        .where((e) => e.parent == root && e.querySelector('.tit') != null)
        .toList();
    if (milestoneGroups.length != 1) {
      throw const FormatException('Missing Donga academic milestones');
    }
    for (final group in milestoneGroups.single.children) {
      final semester = group.querySelector('.tit')?.text.trim();
      if (semester != '제1학기' && semester != '제2학기') {
        throw const FormatException('Invalid Donga milestone semester');
      }
      final items = group.querySelectorAll('ul > li');
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
    final opening = root.querySelector('p.info-ex01')?.text ?? '';
    for (final m in RegExp(
      r'([12])학기 개시일:\s*(\d{1,2}\.\s*\d{1,2}\.?)',
    ).allMatches(opening)) {
      final (start, last) = _range(m[2]!, year);
      events.add(_event('제${m[1]}학기 개시일', start, last, url));
    }
    // Expand actual rowspans so the second Chuseok day keeps its shared label.
    final pending = <int, (Element, int)>{};
    for (final row in tables[1].querySelectorAll('tbody > tr')) {
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
    if (doc.body == null || events.isEmpty) {
      throw const FormatException('Empty Donga annual document');
    }
    return events;
  }

  static List<AcademicEvent> parseLegacy(String body, int year) {
    final doc = html.parse(body);
    final sections = doc.querySelectorAll('.sch-monlist-wr.yearly');
    if (doc.querySelector('.sch-date .year')?.text.trim() != '$year' ||
        sections.length != 12) {
      throw const FormatException('Incomplete Donga legacy year');
    }
    final result = <AcademicEvent>[];
    for (final (i, s) in sections.indexed) {
      if (s.attributes['data-month'] != '${i + 1}'.padLeft(2, '0')) {
        throw const FormatException('Invalid Donga legacy month');
      }
      for (final item in s.querySelectorAll('.daily-li:not(.hasNoData)')) {
        final (start, last) = _range(
          item.querySelector('.date-core')?.text ?? '',
          year,
        );
        if (start.month != i + 1) {
          throw const FormatException('Invalid Donga legacy scope');
        }
        result.add(
          _event(
            _clean(item.querySelector('.body-core')?.text ?? ''),
            start,
            last,
            'https://www.donga.ac.kr/kor/CMS/ScheduleMgr/YearList.do?calendar_year=$year&mCode=MN173&part=false',
          ),
        );
      }
    }
    return result;
  }

  static List<AcademicEvent> parseDetail(String body, String url) {
    final doc = html.parse(body), result = <AcademicEvent>[];
    for (final row in doc.querySelectorAll('.data-in-wrap')) {
      final dates = row.querySelectorAll('.pdate-box');
      if (dates.isEmpty || dates.length > 2) {
        throw const FormatException('Invalid Donga explicit dates');
      }
      DateTime date(Element e) {
        final ym = RegExp(
          r'^(\d{4})\.(\d{2})$',
        ).firstMatch(e.querySelector('.mtxt')?.text.trim() ?? '');
        final day = int.tryParse(e.querySelector('.dtxt')?.text.trim() ?? '');
        if (ym == null || day == null) {
          throw const FormatException('Invalid Donga full date');
        }
        return _date(int.parse(ym[1]!), int.parse(ym[2]!), day);
      }

      result.add(
        _event(
          _clean(row.querySelector('strong.ptit')?.text ?? ''),
          date(dates.first),
          date(dates.last),
          url,
        ),
      );
    }
    if (result.isEmpty) throw const FormatException('No Donga daily detail');
    return result;
  }

  static Uri? selectSeasonalNotice(String body, int year, bool winter) {
    final doc = html.parse(body);
    if (doc.querySelector('.bdListPaging') == null) {
      throw const FormatException('Invalid Donga seasonal search');
    }
    final prefix = '$year학년도 ${winter ? '동계' : '하계'}계절학기';
    final candidates = doc
        .querySelectorAll('.subject .stitle a')
        .where(
          (e) =>
              _clean(e.text).startsWith(prefix) &&
              RegExp('실시 안내|개강 안내').hasMatch(_clean(e.text)),
        )
        .toList();
    if (candidates.isEmpty) return null;
    final url = Uri.https(
      'www.donga.ac.kr',
      '/kor/CMS/Board/Board.do',
    ).resolve(candidates.first.attributes['href'] ?? '');
    if (url.host != 'www.donga.ac.kr' ||
        url.scheme != 'https' ||
        url.path != '/kor/CMS/Board/Board.do' ||
        !RegExp(r'^\d+$').hasMatch(url.queryParameters['board_seq'] ?? '')) {
      throw const FormatException('Invalid Donga seasonal link');
    }
    return url;
  }

  static AcademicEvent parseSeasonal(
    String body,
    int year,
    bool winter,
    String url,
  ) {
    final doc = html.parse(body);
    final title = _clean(doc.querySelector('.viewTit')?.text ?? '');
    if (!title.startsWith('$year학년도 ${winter ? '동계' : '하계'}계절학기')) {
      throw const FormatException('Wrong Donga seasonal notice');
    }
    final text = _clean(
      doc.querySelector('.bdViewCont')?.text ?? '',
    ).replaceAll(RegExp(r'\([월화수목금토일]\)'), '').replaceAll(RegExp(r'\s+'), '');
    final m = RegExp(
      r'수업기간(?:및방법)?:((?:\d{4}\.)?\d{1,2}\.\d{1,2}\.?~(?:\d{4}\.)?\d{1,2}\.\d{1,2}\.?)',
    ).firstMatch(text);
    if (m == null) {
      throw const FormatException('Missing actual Donga seasonal period');
    }
    final (start, last) = _range(m[1]!, year);
    if (winter && start.month != 12 || !winter && start.month != 6) {
      throw const FormatException('Unexpected Donga seasonal scope');
    }
    return _event(winter ? '동계계절학기' : '하계계절학기', start, last, url);
  }

  @override
  void close() => _client.close();
}
