import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KonkukAcademicSource implements AcademicSource {
  KonkukAcademicSource({this.glocal = false, http.Client? client})
    : _client = client ?? http.Client();
  final bool glocal;
  final http.Client _client;
  @override
  String get id => glocal ? 'konkuk-glocal' : 'konkuk';
  @override
  String get name => glocal ? '건국대학교 GLOCAL' : '건국대학교';
  @override
  Uri get website => glocal
      ? Uri.https('www.kku.ac.kr', '/cms/FR_CON/index.do', {'MENU_ID': '1350'})
      : Uri.https('www.konkuk.ac.kr', '/konkuk/2161/subview.do');

  Future<String> _post(Uri url, Map<String, String> body) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _client
        .post(
          url,
          body: body,
          headers: {
            'User-Agent': 'Mozilla/5.0 DailyCalendar-source-validation',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Konkuk calendar unavailable');
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

    for (final selected in [year - 1, year]) {
      final body = await _post(
        glocal
            ? Uri.https('www.kku.ac.kr', '/ajax/FR_SCH_SVC/ScheduleListData.do')
            : Uri.https(
                'www.konkuk.ac.kr',
                '/schdulmanage/konkuk/23/yearSchdul.do',
              ),
        glocal
            ? {'SCH_YEAR': '$selected', 'SCH_SITE_NO': '2'}
            : {'year': '$selected', 'kind': ''},
      );
      add(glocal ? parseGlocal(body, selected) : parseSeoul(body, selected));
    }
    if (glocal) {
      Future<String> search({bool archive = false, required String keyword}) =>
          _post(
            Uri.https(
              archive ? 'formativeart.kku.ac.kr' : 'www.kku.ac.kr',
              '/ajax/FR_SVC/BBSViewList2.do',
            ),
            {
              'MENU_ID': archive ? '160' : '1740',
              'SITE_NO': archive ? '38' : '2',
              'BOARD_SEQ': archive ? '3' : '18',
              'BOARD_TYPE': 'C0301',
              'pageNo': '1',
              'pagePerCnt': '50',
              'SEARCH_FLD': 'SUBJECT',
              'SEARCH': keyword,
              'S_CATE_SEQ': '',
              'BOARD_CATEGORY_NO': '',
              'P_TAB_NO': '',
              'TAB_NO': '',
            },
          );
      final winter = await search(keyword: '동계');
      bool hasWinter(String body, int selected) {
        final data = jsonDecode(body);
        if (data is! Map ||
            data['data'] is! Map ||
            data['data']['list'] is! List) {
          throw const FormatException('Invalid GLOCAL winter notice list');
        }
        return (data['data']['list'] as List).whereType<Map>().any(
          (r) => _clean(
            r['SUBJECT']?.toString() ?? '',
          ).contains('$selected학년도 동계 계절학기 안내'),
        );
      }

      final archived = !hasWinter(winter, year - 1);
      final previous = archived
          ? await search(archive: true, keyword: '동계')
          : winter;
      add(
        parseSupplement(
          previous,
          year - 1,
          winter: true,
          host: archived ? 'formativeart.kku.ac.kr' : 'www.kku.ac.kr',
          menu: archived ? '160' : '1740',
          site: archived ? '38' : '2',
          board: archived ? '3' : '18',
        ),
      );
      // A future course period is added as soon as its official notice appears;
      // an empty current-winter result is not a licence to invent the dates.
      if (hasWinter(winter, year)) {
        add(
          parseSupplement(
            winter,
            year,
            winter: true,
            host: 'www.kku.ac.kr',
            menu: '1740',
            site: '2',
            board: '18',
          ),
        );
      }
      add(
        parseSupplement(
          await search(keyword: '하계방학'),
          year,
          winter: false,
          host: 'www.kku.ac.kr',
          menu: '1740',
          site: '2',
          board: '18',
        ),
      );
    }

    if (events.isEmpty) {
      throw const FormatException('No published Konkuk calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static DateTime _date(int y, int m, int d) {
    final v = DateTime(y, m, d);
    if (v.year != y || v.month != m || v.day != d) {
      throw const FormatException('Invalid Konkuk date');
    }
    return v;
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
  static AcademicEvent _event(
    String title,
    DateTime start,
    DateTime last,
    String url,
  ) {
    if (last.isBefore(start) || title.isEmpty) {
      throw const FormatException('Invalid Konkuk interval');
    }
    return AcademicEvent(
      sourceId: '${start.toIso8601String()}:${last.toIso8601String()}:$title',
      title: title,
      start: start,
      end: DateTime(last.year, last.month, last.day + 1),
      url: url,
    );
  }

  static List<AcademicEvent> parseSeoul(String body, int year) {
    final doc = html.parse(body);
    final sections = doc.querySelectorAll('.yearSchdul > ul > li');
    if (doc.querySelector('#year')?.attributes['value'] != '$year' ||
        sections.length != 12) {
      throw const FormatException('Unexpected Konkuk year');
    }
    final result = <AcademicEvent>[];
    for (var i = 0; i < 12; i++) {
      final s = sections[i];
      if (_clean(s.querySelector('.box-month')?.text ?? '') != '${i + 1}월') {
        throw const FormatException('Incomplete Konkuk months');
      }
      final dates = s.querySelectorAll('.list-date'),
          titles = s.querySelectorAll('.list-content');
      if (dates.length != titles.length) {
        throw const FormatException('Incomplete Konkuk rows');
      }
      for (var j = 0; j < dates.length; j++) {
        final m = RegExp(
          r'^(\d{2})\.(\d{2})(?:~(\d{2})\.(\d{2}))?$',
        ).firstMatch(dates[j].text.replaceAll(RegExp(r'\s+'), ''));
        if (m == null) throw const FormatException('Invalid Konkuk period');
        final sm = int.parse(m[1]!), em = int.tryParse(m[3] ?? '') ?? sm;
        final start = _date(year, sm, int.parse(m[2]!));
        final last = m[3] == null
            ? start
            : _date(year + (em < sm ? 1 : 0), em, int.parse(m[4]!));
        if (sm != i + 1) throw const FormatException('Unexpected Konkuk month');
        result.add(
          _event(
            _clean(titles[j].text),
            start,
            last,
            'https://www.konkuk.ac.kr/konkuk/2161/subview.do',
          ),
        );
      }
    }
    if (result.isEmpty) {
      throw const FormatException('Empty Konkuk annual calendar');
    }
    return result;
  }

  static List<AcademicEvent> parseGlocal(String body, int year) {
    final data = jsonDecode(body);
    if (data is! Map || data['data'] is! List || (data['data'] as List).isEmpty) {
      throw const FormatException('Invalid GLOCAL calendar');
    }
    final result = <AcademicEvent>[];
    for (final row in data['data'] as List) {
      if (row is! Map || row['REPEAT_YN'] != 'N' || row['SCH_TYPE'] != 'C1001') {
        throw const FormatException('Unsupported GLOCAL record');
      }
      DateTime date(String key) {
        final m = RegExp(
          r'^(\d{4})-(\d{2})-(\d{2})$',
        ).firstMatch(row[key]?.toString() ?? '');
        if (m == null) {
          throw const FormatException('Missing GLOCAL numeric date');
        }
        return _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      }

      final start = date('START_DAY'), last = date('END_DAY');
      if (!start.isBefore(DateTime(year + 1)) ||
          !last.isAfter(
            DateTime(year, 1, 1).subtract(const Duration(days: 1)),
          ) ||
          start.year < year - 1 ||
          last.isAfter(DateTime(year + 1, 3, 31))) {
        throw const FormatException('Unexpected GLOCAL year');
      }
      result.add(
        _event(
          _clean(row['SUBJECT']?.toString() ?? ''),
          start,
          last,
          'https://www.kku.ac.kr/cms/FR_CON/index.do?MENU_ID=1350&SCH_YEAR=$year',
        ),
      );
    }
    return result;
  }

  static List<AcademicEvent> parseSupplement(
    String body,
    int year, {
    required bool winter,
    required String host,
    required String menu,
    required String site,
    required String board,
  }) {
    final data = jsonDecode(body);
    if (data is! Map || data['data'] is! Map || data['data']['list'] is! List) {
      throw const FormatException('Invalid GLOCAL notice search');
    }
    final notices =
        (data['data']['list'] as List).whereType<Map>().where((r) {
          final title = _clean(r['SUBJECT']?.toString() ?? '');
          return title.contains('$year학년도') &&
              (winter
                  ? title.contains('동계 계절학기 안내')
                  : title.contains('하계방학 주요 학사일정'));
        }).toList()..sort(
          (a, b) => (b['BBS_SEQ'] as int).compareTo(a['BBS_SEQ'] as int),
        );
    if (notices.isEmpty) {
      throw const FormatException('Missing published GLOCAL seasonal notice');
    }
    final row = notices.first;
    if (row['SITE_NO'].toString() != site ||
        row['BOARD_SEQ'].toString() != board ||
        row['CONTENTS'] is! String) {
      throw const FormatException('Wrong GLOCAL notice scope');
    }
    final doc = html.parse(row['CONTENTS'] as String);
    String raw;
    if (winter) {
      raw = _clean(
        doc.body?.text ?? '',
      ).replaceAll(RegExp(r'\([월화수목금토일]\)'), '').replaceAll(RegExp(r'\s+'), '');
      final m = RegExp(r'기간\(개강~기말고사\):([0-9.]+)~([0-9.]+),').firstMatch(raw);
      if (m == null) {
        throw const FormatException(
          'Missing GLOCAL winter actual course period',
        );
      }
      raw = '${m[1]}~${m[2]}';
    } else {
      final rows = doc
          .querySelectorAll('tr')
          .where(
            (r) =>
                r.children.length == 3 &&
                _clean(r.children[1].text) == '하계 계절학기',
          )
          .toList();
      if (rows.length != 1) {
        throw const FormatException(
          'Missing GLOCAL summer actual course period',
        );
      }
      raw = rows.single.children.first.text
          .replaceAll(RegExp(r'\([월화수목금토일]\)'), '')
          .replaceAll(RegExp(r'\s+'), '');
    }
    final m = RegExp(
      r'^(?:(\d{4})\.)?(\d{1,2})\.(\d{1,2})\.?~(?:(\d{4})\.)?(\d{1,2})\.(\d{1,2})\.?$',
    ).firstMatch(raw);
    if (m == null) throw const FormatException('Invalid GLOCAL seasonal dates');
    final sy = int.tryParse(m[1] ?? '') ?? year,
        sm = int.parse(m[2]!),
        em = int.parse(m[5]!);
    final ey = int.tryParse(m[4] ?? '') ?? sy + (em < sm ? 1 : 0);
    if (sy != year ||
        (winter && (sm != 12 || ey != year + 1)) ||
        (!winter && sm != 6)) {
      throw const FormatException('Unexpected GLOCAL seasonal year');
    }
    return [
      _event(
        winter ? '동계 계절학기' : '하계 계절학기',
        _date(sy, sm, int.parse(m[3]!)),
        _date(ey, em, int.parse(m[6]!)),
        Uri.https(host, '/cms/FR_CON/BoardView.do', {
          'BBS_SEQ': row['BBS_SEQ'].toString(),
          'BOARD_SEQ': board,
          'MENU_ID': menu,
          'SITE_NO': site,
        }).toString(),
      ),
    ];
  }

  @override
  void close() => _client.close();
}
