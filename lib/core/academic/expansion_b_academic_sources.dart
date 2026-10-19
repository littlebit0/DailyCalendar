import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';
import 'month_structure.dart';

DateTime _date(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match == null) throw const FormatException('Invalid academic date');
  final y = int.parse(match[1]!);
  final m = int.parse(match[2]!);
  final d = int.parse(match[3]!);
  final date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) {
    throw const FormatException('Invalid academic date');
  }
  return date;
}

List<AcademicEvent> _within(List<AcademicEvent> events, int year) {
  final unique = <String, AcademicEvent>{};
  for (final event in events) {
    if (event.start.isBefore(DateTime(year + 1)) &&
        event.end.isAfter(DateTime(year))) {
      final previous = unique[event.sourceId];
      if (previous != null &&
          jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
        throw const FormatException('Conflicting academic identity');
      }
      unique[event.sourceId] = event;
    }
  }
  if (unique.isEmpty) throw const FormatException('No published academic year');
  return unique.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}

abstract class _Source implements AcademicSource {
  _Source({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  Future<String> read(
    Uri url, {
    Map<String, String>? body,
    Map<String, String>? headers,
  }) async {
    final response =
        await (body == null
                ? client.get(url, headers: headers)
                : client.post(url, body: body, headers: headers))
            .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Academic source unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  @override
  void close() => client.close();
}

/// The two institutions publish the same K2Web dt/dd annual date format.
abstract class _K2Annual extends _Source {
  _K2Annual({super.client});
  String get host;
  String get site;
  String get number;
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final all = <AcademicEvent>[];
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final body = await read(
        Uri.https(host, '/schdulmanage/$site/$number/yearSchdul.do', {
          'year': '$selected',
        }),
      );
      all.addAll(parse(body, selected));
    }
    return _within(all, year);
  }

  List<AcademicEvent> parse(String body, int year) {
    final doc = html.parse(body);
    if (doc.querySelector('#year')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected K2Web calendar year');
    }
    // Observed 2019-2027 on both schools: all twelve month headings are sent
    // even when a month has no events, so a missing or repeated month means a
    // damaged response.
    requireTwelveMonths(
      doc.querySelectorAll('#timeTableList h3').map((node) => node.text),
      'K2Web',
    );
    final events = <AcademicEvent>[];
    for (final row in doc.querySelectorAll('#timeTableList dt')) {
      final title = row.nextElementSibling;
      if (title?.localName != 'dd') {
        throw const FormatException('Missing K2Web title');
      }
      final dates = RegExp(r'(\d{2})-(\d{2})').allMatches(row.text).toList();
      if (dates.isEmpty || dates.length > 2) {
        throw const FormatException('Invalid K2Web date range');
      }
      final start = _date('$year-${dates.first[1]}-${dates.first[2]}');
      final endMonth = int.parse(dates.last[1]!);
      final last = _date(
        '${endMonth < start.month ? year + 1 : year}'
        '-${dates.last[1]}-${dates.last[2]}',
      );
      final label = title!.text
          .replaceAll(RegExp(r'<br\s*/?>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final onclick = title.querySelector('a')?.attributes['onclick'] ?? '';
      final seq = RegExp(r"set_layer\('(\d+)'").firstMatch(onclick)?[1];
      if (seq == null || label.isEmpty || last.isBefore(start)) {
        throw const FormatException('Invalid K2Web academic event');
      }
      events.add(
        AcademicEvent(
          sourceId: seq,
          title: label,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: website.toString(),
        ),
      );
    }
    return _within(events, year);
  }
}

class HyupsungAcademicSource extends _K2Annual {
  HyupsungAcademicSource({super.client});
  @override
  String get id => 'hyupsung';
  @override
  String get name => '협성대학교';
  @override
  String get host => 'www.uhs.ac.kr';
  @override
  String get site => 'uhs';
  @override
  String get number => '1';
  @override
  Uri get website => Uri.https(host, '/uhs/121/subview.do');
}

class SungkyulAcademicSource extends _K2Annual {
  SungkyulAcademicSource({super.client});
  @override
  String get id => 'sungkyul';
  @override
  String get name => '성결대학교';
  @override
  String get host => 'www.sungkyul.ac.kr';
  @override
  String get site => 'skukr';
  @override
  String get number => '3';
  @override
  Uri get website => Uri.https(host, '/skukr/313/subview.do');
}

class KentechAcademicSource extends _Source {
  KentechAcademicSource({super.client});
  @override
  String get id => 'kentech';
  @override
  String get name => '한국에너지공과대학교';
  @override
  Uri get website => Uri.https('www.kentech.ac.kr', '/CalendarList.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async => parse(
    await read(
      Uri.https('www.kentech.ac.kr', '/TotalScheduleData.do'),
      body: {'DEPT_CD': '', 'SCH_TYPE': ''},
    ),
    year,
  );
  static List<AcademicEvent> parse(String body, int year) {
    final rows = jsonDecode(body);
    if (rows is! List) throw const FormatException('Invalid KENTECH calendar');
    final events = <AcademicEvent>[];
    for (final row in rows) {
      if (row is! Map) throw const FormatException('Invalid KENTECH row');
      // Academic and holiday records only. Graduate-specific records excluded.
      if (!['R0205', 'R0203'].contains(row['SCH_TYPE']) ||
          row['DEPT_CD'] != 'MAIN') {
        continue;
      }
      if (row['REPEAT_YN'] != 'N') {
        throw const FormatException(
          'Unresolved annually repeated KENTECH event',
        );
      }
      final start = _date(row['START_DAY'] as String);
      final last = _date(row['END_DAY'] as String);
      final label = (row['SUBJECT'] as String).trim();
      if (last.isBefore(start) ||
          label.isEmpty ||
          row['SCHEDULE_SEQ'] is! int) {
        throw const FormatException('Invalid KENTECH event');
      }
      if (label.contains('대학원') ||
          label.contains('석사') ||
          label.contains('박사') ||
          label.contains('논문')) {
        continue;
      }
      events.add(
        AcademicEvent(
          sourceId: '${row['SCHEDULE_SEQ']}',
          title: label,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: 'https://www.kentech.ac.kr/CalendarList.do',
        ),
      );
    }
    return _within(events, year);
  }
}

class HanseiAcademicSource extends _Source {
  HanseiAcademicSource({super.client});
  @override
  String get id => 'hansei';
  @override
  String get name => '한세대학교';
  @override
  Uri get website => Uri.https('hansei.ac.kr', '/view.do', {'no': '10302'});
  @override
  Future<List<AcademicEvent>> fetch(int year) async => parse(
    await read(
      website.replace(
        queryParameters: {
          'no': '10302',
          'dateY': '$year',
          'dateM': '0',
          'tab': 'lst',
        },
      ),
    ),
    year,
  );
  static List<AcademicEvent> parse(String body, int year) {
    final doc = html.parse(body);
    final selectedYears = doc.querySelectorAll('.schd_top .year_box .year');
    if (selectedYears.isEmpty ||
        selectedYears.any((element) => element.text.trim() != '$year')) {
      throw const FormatException('Unexpected Hansei year');
    }
    final events = <AcademicEvent>[];
    // Each list is one month and also shows events that started the month
    // before or end the month after, so a row's year follows its section.
    for (final section in doc.querySelectorAll('.schd_list')) {
      final sectionMonth = int.tryParse(
        RegExp(
              r'(\d{1,2})',
            ).firstMatch(section.querySelector('.mont .ko')?.text ?? '')?[1] ??
            '',
      );
      if (sectionMonth == null || sectionMonth < 1 || sectionMonth > 12) {
        throw const FormatException('Invalid Hansei month section');
      }
      int yearOf(int month) {
        final distance = month - sectionMonth;
        return distance > 6
            ? year - 1
            : distance < -6
            ? year + 1
            : year;
      }

      for (final row in section.querySelectorAll('.cont')) {
        final dates = RegExp(
          r'(\d{2})\.(\d{2})',
        ).allMatches(row.querySelector('.date')?.text ?? '').toList();
        final label = row.querySelector('.txt')?.text.trim() ?? '';
        if (dates.isEmpty || dates.length > 2 || label.isEmpty) {
          throw const FormatException('Invalid Hansei academic row');
        }
        final startMonth = int.parse(dates.first[1]!);
        final start = _date(
          '${yearOf(startMonth)}-${dates.first[1]}-${dates.first[2]}',
        );
        final endMonth = int.parse(dates.last[1]!);
        final last = _date(
          '${yearOf(endMonth)}-${dates.last[1]}-${dates.last[2]}',
        );
        events.add(
          AcademicEvent(
            sourceId: '${start.toIso8601String()}:$label',
            title: label,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url: 'https://hansei.ac.kr/view.do?no=10302&dateY=$year&dateM=0&tab=lst',
          ),
        );
      }
    }
    return _within(events, year);
  }
}

class SangjiAcademicSource extends _Source {
  SangjiAcademicSource({super.client});
  @override
  String get id => 'sangji';
  @override
  String get name => '상지대학교';
  @override
  Uri get website => Uri.https(
    'sangji.ac.kr',
    '/prog/schafsSchdul/kor/sub06_01_01/A/scheduleList.do',
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await client
        .get(website, headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw const FormatException('Sangji calendar unavailable');
    }
    final cookies = response.headers['set-cookie']
        ?.split(',')
        .map((part) => part.split(';').first.trim())
        .join('; ');
    final all = <AcademicEvent>[];
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final rows = _rows(
        await read(
          Uri.https(
            'sangji.ac.kr',
            '/prog/schafsSchdul/kor/sub06_01_01/A/getScheduleList.do',
          ),
          body: {'searchKeywordFrom': '$selected', 'searchCondition2': 'A'},
          headers: {
            'Referer': website.toString(),
            'User-Agent': 'Mozilla/5.0',
            'X-Requested-With': 'XMLHttpRequest',
            'Cookie': ?cookies,
          },
        ),
      );
      // The previous academic-year response may legitimately have nothing in
      // the requested year, but the requested year's own response must: an
      // empty or stale one is a failed refresh, not a partial success.
      if (selected == year) _within(rows, year);
      all.addAll(rows);
    }
    return _within(all, year);
  }

  static List<AcademicEvent> parse(String body, int year) =>
      _within(_rows(body), year);

  static List<AcademicEvent> _rows(String body) {
    final groups = jsonDecode(body);
    if (groups is! List) throw const FormatException('Invalid Sangji calendar');
    final events = <AcademicEvent>[];
    for (final group in groups) {
      if (group is! Map || group['list'] is! List) {
        throw const FormatException('Invalid Sangji month');
      }
      for (final row in group['list'] as List) {
        if (row is! Map ||
            row['code'] != 'A' ||
            row['siteCode'] != 'kor' ||
            row['cntNo'] is! int ||
            row['subject'] is! String) {
          throw const FormatException('Invalid Sangji academic identity');
        }
        final start = _date(row['bgnde'] as String);
        final last = row['endde'] == '' ? start : _date(row['endde'] as String);
        final label = (row['subject'] as String).trim();
        if (last.isBefore(start) || label.isEmpty) {
          throw const FormatException('Invalid Sangji period');
        }
        events.add(
          AcademicEvent(
            sourceId: '${row['cntNo']}',
            title: label,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url:
                'https://sangji.ac.kr/prog/schafsSchdul/kor/sub06_01_01/A/scheduleList.do',
          ),
        );
      }
    }
    return events;
  }
}

class SunmoonAcademicSource extends _Source {
  SunmoonAcademicSource({super.client});
  @override
  String get id => 'sunmoon';
  @override
  String get name => '선문대학교';
  @override
  Uri get website => Uri.https(
    'communication.sunmoon.ac.kr',
    '/communication/sv/schdulView/schdulCalendarView.do',
    {'mi': '40193'},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final all = <AcademicEvent>[];
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      all.addAll(
        parse(
          await read(
            Uri.https(
              'communication.sunmoon.ac.kr',
              '/communication/sv/schdulView/calendar.do',
            ),
            body: {
              'year': '$selected',
              'monthFirst': '${selected}0301',
              'monthEnmt':
                  '${selected + 1}02${DateTime(selected + 1, 3, 0).day}',
              'sysId': 'communication',
              'section': '',
            },
          ),
          selected,
        ),
      );
    }
    return _within(all, year);
  }

  static List<AcademicEvent> parse(String body, int academicYear) {
    final doc = html.parse(body);
    if (doc.querySelector('h4[in-data]')?.attributes['in-data'] !=
        '$academicYear') {
      throw const FormatException('Unexpected Sunmoon academic year');
    }
    final events = <AcademicEvent>[];
    for (final table in doc.querySelectorAll('table')) {
      if (!(table.querySelector('caption')?.text.contains('내용') ?? false)) {
        continue;
      }
      for (final row in table.querySelectorAll('tbody tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) {
          throw const FormatException('Invalid Sunmoon row');
        }
        final dates = RegExp(
          r'(\d{2})-(\d{2})',
        ).allMatches(cells[0].text).toList();
        if (dates.isEmpty || dates.length > 2) {
          throw const FormatException('Invalid Sunmoon dates');
        }
        DateTime date(RegExpMatch m) => _date(
          '${int.parse(m[1]!) < 3 ? academicYear + 1 : academicYear}-${m[1]}-${m[2]}',
        );
        final start = date(dates.first);
        final last = date(dates.last);
        if (last.isBefore(start)) {
          throw const FormatException('Invalid Sunmoon range');
        }
        for (final item in cells[1].querySelectorAll('li')) {
          final label = item.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (label.isEmpty) throw const FormatException('Empty Sunmoon title');
          // The responsive calendar renders a broken duplicate table with
          // literal null labels; the second official table has actual titles.
          if (label == 'null') {
            continue;
          }
          events.add(
            AcademicEvent(
              sourceId: '${start.toIso8601String()}:$label',
              title: label,
              start: start,
              end: DateTime(last.year, last.month, last.day + 1),
              url:
                  'https://communication.sunmoon.ac.kr/communication/sv/schdulView/schdulCalendarView.do?mi=40193',
            ),
          );
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No Sunmoon academic events');
    }
    return events;
  }
}
