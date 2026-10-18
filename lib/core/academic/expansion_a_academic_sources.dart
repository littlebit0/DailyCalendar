import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';
import 'eulji_calendar_transport_stub.dart'
    if (dart.library.io) 'eulji_calendar_transport_io.dart'
    as eulji_transport;

DateTime _date(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw const FormatException('Invalid published academic date');
  }
  return date;
}

List<AcademicEvent> _finish(List<AcademicEvent> rows, int year) {
  final events = <String, AcademicEvent>{};
  for (final event in rows) {
    if (!event.end.isAfter(event.start)) {
      throw const FormatException('Invalid published academic range');
    }
    if (!event.start.isBefore(DateTime(year + 1)) ||
        !event.end.isAfter(DateTime(year))) {
      continue;
    }
    final prior = events[event.sourceId];
    if (prior != null &&
        jsonEncode(prior.toJson()) != jsonEncode(event.toJson())) {
      throw const FormatException('Conflicting published academic event');
    }
    events[event.sourceId] = event;
  }
  if (events.isEmpty) {
    throw const FormatException('No published academic calendar');
  }
  return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}

AcademicEvent _event(String title, DateTime start, DateTime last, Uri url) {
  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) throw const FormatException('Empty academic title');
  return AcademicEvent(
    sourceId:
        '${start.toIso8601String().substring(0, 10)}/${last.toIso8601String().substring(0, 10)}/$title',
    title: title,
    start: start,
    end: DateTime(last.year, last.month, last.day + 1),
    url: url.toString(),
  );
}

abstract class _PublicSource implements AcademicSource {
  _PublicSource({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  Future<String> get(Uri uri) async {
    final response = await client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Academic source unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  @override
  void close() => client.close();
}

class InjeAcademicSource extends _PublicSource {
  InjeAcademicSource({super.client});
  @override
  String get id => 'inje';
  @override
  String get name => '인제대학교';
  @override
  Uri get website => Uri.https('www.inje.ac.kr', '/kor/setRoute/B_Page.asp', {
    'pCode': 'IF010010000',
    'viewType': 'vy',
  });
  @override
  Future<List<AcademicEvent>> fetch(int year) async => parse(
    await get(
      website.replace(
        queryParameters: {
          ...website.queryParameters,
          'setYear': '$year',
          'setMonth': '1',
        },
      ),
    ),
    year,
  );
  static List<AcademicEvent> parse(String body, int year) {
    final doc = html.parse(body);
    if (doc.querySelector('.yearPart h4')?.text.trim() != '$year년') {
      throw const FormatException('Unexpected INJE calendar year');
    }
    final events = <AcademicEvent>[];
    for (final row in doc.querySelectorAll('.eventList li')) {
      final title = row.querySelector('.titleTxt')?.text;
      final dates = RegExp(
        r'(\d{2})\.\s*(\d{2})\.',
      ).allMatches(row.querySelector('.dateTxt')?.text ?? '').toList();
      if (title == null || dates.isEmpty || dates.length > 2) {
        throw const FormatException('Invalid INJE event');
      }
      final start = _date(
        year,
        int.parse(dates.first[1]!),
        int.parse(dates.first[2]!),
      );
      final last = _date(
        year,
        int.parse(dates.last[1]!),
        int.parse(dates.last[2]!),
      );
      events.add(
        _event(
          title,
          start,
          last,
          Uri.https('www.inje.ac.kr', '/kor/setRoute/B_Page.asp', {
            'pCode': 'IF010010000',
            'viewType': 'vy',
            'setYear': '$year',
          }),
        ),
      );
    }
    return _finish(events, year);
  }
}

class HongikAcademicSource extends _PublicSource {
  HongikAcademicSource({super.client});
  @override
  String get id => 'hongik';
  @override
  String get name => '홍익대학교';
  @override
  Uri get website =>
      Uri.https('www.hongik.ac.kr', '/kr/education/academic-schedule.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await client
        .post(
          Uri.https('www.hongik.ac.kr', '/sso/APICipher.jsp'),
          body: {
            'data': jsonEncode({
              'url': '/schedule/get_schedule.php',
              'url2': '&GUBUN=',
              'url3': '0',
              'url4': '&YEAR=',
              'url5': '$year',
            }),
          },
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Hongik calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final data = jsonDecode(body);
    if (data is! Map || data['result'] != 'Y' || data['data'] is! List) {
      throw const FormatException('Invalid Hongik calendar');
    }
    final rows = <AcademicEvent>[];
    for (final row in data['data'] as List) {
      if (row is! Map ||
          row['YEAR'] != '$year' ||
          row['TITLE'] is! String ||
          row['START'] is! String ||
          row['END'] is! String) {
        throw const FormatException('Invalid Hongik record');
      }
      final start = row['START'] as String, end = row['END'] as String;
      // Month-only notices do not specify dates; do not manufacture day 1.
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(start) ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(end)) {
        continue;
      }
      DateTime date(String value) {
        final p = value.split('-').map(int.parse).toList();
        return _date(p[0], p[1], p[2]);
      }

      rows.add(
        _event(
          Uri.decodeComponent((row['TITLE'] as String).replaceAll('+', ' ')),
          date(start),
          date(end),
          Uri.https('www.hongik.ac.kr', '/kr/education/academic-schedule.do'),
        ),
      );
    }
    return _finish(rows, year);
  }
}

class WoosongAcademicSource extends _PublicSource {
  WoosongAcademicSource({super.client});
  @override
  String get id => 'wsu';
  @override
  String get name => '우송대학교';
  @override
  Uri get website => Uri.https('www.wsu.ac.kr', '/page/haksa_list.jsp');
  @override
  Future<List<AcademicEvent>> fetch(int year) async =>
      parse(await get(website), year);
  static List<AcademicEvent> parse(String body, int year) {
    final doc = html.parse(body), events = <AcademicEvent>[];
    for (final row in doc.querySelectorAll('tr')) {
      final cells = row.children
          .where((cell) => cell.localName == 'td' || cell.localName == 'th')
          .toList();
      if (cells.length < 2) continue;
      final month = RegExp(
        r'^(\d{4})\.\s*(\d{1,2})$',
      ).firstMatch(cells.first.text.trim());
      if (month == null || int.parse(month[1]!) != year) continue;
      final m = int.parse(month[2]!);
      // Column 2 is undergraduate; graduate events are deliberately excluded.
      for (final li in cells[1].querySelectorAll('li')) {
        final text = li.text.trim();
        final record = RegExp(
          r'^\s*((?:\d{1,2}/)?\d{1,2})\s*(?:[~∼]\s*((?:\d{1,2}/)?\d{1,2}))?\s*:\s*(.+)$',
        ).firstMatch(text);
        if (record == null) throw const FormatException('Invalid WSU event');
        DateTime date(String value, int defaultMonth) {
          final parts = value.split('/');
          return _date(
            year,
            parts.length == 2 ? int.parse(parts[0]) : defaultMonth,
            int.parse(parts.last),
          );
        }

        final start = date(record[1]!, m);
        var last = date(
          record[2] ?? record[1]!,
          record[2] == null ? start.month : m,
        );
        if (last.isBefore(start) && !(record[2] ?? '').contains('/')) {
          final next = DateTime(year, start.month + 1);
          last = _date(next.year, next.month, last.day);
        }
        events.add(
          _event(
            record[3]!,
            start,
            last,
            Uri.https('www.wsu.ac.kr', '/page/haksa_list.jsp'),
          ),
        );
      }
    }
    return _finish(events, year);
  }
}

class EwhaAcademicSource extends _PublicSource {
  EwhaAcademicSource({super.client});
  @override
  String get id => 'ewha';
  @override
  String get name => '이화여자대학교';
  @override
  Uri get website =>
      Uri.https('www.ewha.ac.kr', '/ewha/bachelor/calendar2026.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async => parse(
    await get(
      website.replace(queryParameters: {'mode': 'user_list', 'year': '$year'}),
    ),
    year,
  );
  static List<AcademicEvent> parse(String body, int year) {
    final doc = html.parse(body), events = <AcademicEvent>[];
    // Month titles carry no year, so the page's own year banner is the only proof
    // that the response is the requested year; never relabel another year's page.
    final shownYears = {
      for (final span in doc.querySelectorAll('.b-cal-day-box span'))
        if (RegExp(r'^\d{4}$').hasMatch(span.text.trim())) span.text.trim(),
    };
    if (shownYears.length != 1 || shownYears.single != '$year') {
      throw const FormatException('Unexpected EWHA year');
    }
    for (final p in doc.querySelectorAll('p')) {
      final heading = RegExp(
        r'^(?:(\d{4})년\s*)?(\d{1,2})월$',
      ).firstMatch(p.text.trim());
      if (heading == null) continue;
      final y = heading[1] == null ? year : int.parse(heading[1]!);
      final m = int.parse(heading[2]!);
      final container = p.parent;
      if (container == null) continue;
      for (final li in container.querySelectorAll('li')) {
        final record = li.parent?.parent;
        final dates = record?.querySelector('p')?.text ?? '';
        final matches = RegExp(
          r'(?:(\d{1,2})\.)?(\d{1,2})\([월화수목금토일]\)',
        ).allMatches(dates).toList();
        if (matches.isEmpty || matches.length > 2) {
          throw const FormatException('Invalid EWHA event');
        }
        DateTime date(RegExpMatch v) =>
            _date(y, v[1] == null ? m : int.parse(v[1]!), int.parse(v[2]!));
        events.add(
          _event(
            li.text,
            date(matches.first),
            date(matches.last),
            Uri.https('www.ewha.ac.kr', '/ewha/bachelor/calendar2026.do', {
              'mode': 'user_list',
              'year': '$year',
            }),
          ),
        );
      }
    }
    return _finish(events, year);
  }
}

class IccuAcademicSource extends _PublicSource {
  IccuAcademicSource({super.client});
  @override
  String get id => 'iccu';
  @override
  String get name => '인천가톨릭대학교';
  @override
  Uri get website => Uri.https('www.iccu.ac.kr', '/hq/php/schedule_a.php');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final songdo = parse(await get(website), year);
    final ganghwa = parseGanghwa(
      await get(Uri.https('shin.iccu.ac.kr', '/menu_03/menu03_02.php')),
      year,
    );
    return _finish([...songdo, ...ganghwa], year);
  }

  static List<AcademicEvent> parseGanghwa(String body, int year) {
    final doc = html.parse(body);
    if (!doc.body!.text.contains('$year학년도 학사일정표')) {
      throw const FormatException('Unexpected ICCU Ganghwa year');
    }
    final events = <AcademicEvent>[];
    var month = 0;
    for (final row in doc.querySelectorAll('tr')) {
      final m = row.querySelector('td.month');
      if (m != null) month = int.parse(m.text.replaceAll('월', '').trim());
      final dates = row.querySelector('td.date');
      if (dates == null) continue;
      final matches = RegExp(
        r'(?:(\d{1,2})[/.])?(\d{1,2})\(',
      ).allMatches(dates.text).toList();
      if (matches.isEmpty) {
        if (dates.text.trim() == '미정') continue;
        throw const FormatException('Invalid ICCU Ganghwa record');
      }
      final title = row.children.last.text;
      DateTime date(RegExpMatch v) {
        final mm = v[1] == null ? month : int.parse(v[1]!);
        final yy = month == 1 && mm == 12 ? year - 1 : year;
        return _date(yy, mm, int.parse(v[2]!));
      }

      events.add(
        _event(
          '[강화] $title',
          date(matches.first),
          date(matches.last),
          Uri.https('shin.iccu.ac.kr', '/menu_03/menu03_02.php'),
        ),
      );
    }
    return _finish(events, year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final events = <AcademicEvent>[];
    // Published markup contains unclosed list/span tags. Split at the native
    // month and row boundaries before HTML parsing so later rows cannot become
    // part of an earlier event title.
    for (final block
        in body.split(RegExp(r'<div class="calendar_cont[^"]*">')).skip(1)) {
      final heading = RegExp(
        r'<span class="mm">(\d{4})\.(\d{2})</span>',
      ).firstMatch(block);
      if (heading == null) throw const FormatException('Invalid ICCU month');
      final y = int.parse(heading[1]!), m = int.parse(heading[2]!);
      if (y != year) continue;
      final list = block.split('</ul>').first;
      for (final row in list.split('<li>').skip(1)) {
        final raw = RegExp(
          r'<span class="dd">(.*?)</span>',
          dotAll: true,
        ).firstMatch(row)?[1];
        final titlePart = row.split('<span class="dd_desc">');
        if (raw == null || titlePart.length != 2) {
          throw const FormatException('Invalid ICCU row');
        }
        final title =
            html.parseFragment(titlePart[1].split('</span>').first).text ?? '';
        final dates = RegExp(
          r'(?:(\d{1,2})[/.])?(\d{1,2})\(',
        ).allMatches(raw).toList();
        if (dates.isEmpty || dates.length > 2) {
          throw const FormatException('Invalid ICCU event');
        }
        DateTime date(RegExpMatch v) =>
            _date(y, v[1] == null ? m : int.parse(v[1]!), int.parse(v[2]!));
        events.add(
          _event(
            '[송도국제] $title',
            date(dates.first),
            date(dates.last),
            Uri.https('www.iccu.ac.kr', '/hq/php/schedule_a.php'),
          ),
        );
      }
    }
    return _finish(events, year);
  }
}

class EuljiAcademicSource extends _PublicSource {
  EuljiAcademicSource({super.client});
  @override
  String get id => 'eulji';
  @override
  String get name => '을지대학교';
  @override
  Uri get website => Uri.https('eulji.ac.kr', '/renewal/index.html', {
    'menuno': '8069',
    'calendar_no': '105',
  });
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    var compatibilityRequired = false;
    for (var month = 0; month < 12; month++) {
      if (month > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final uri = website.replace(
        queryParameters: {
          ...website.queryParameters,
          'year': '$year',
          'month': '$month',
        },
      );
      // The school sends one malformed metadata header ("Referrer Policy").
      // Retry only that known defect, once per fetch; other failures propagate.
      http.Response response;
      if (compatibilityRequired) {
        response = await eulji_transport.fetchEuljiCalendar(uri);
      } else {
        final clock = Stopwatch()..start();
        try {
          response = await client
              .get(
                uri,
                headers: {'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html'},
              )
              .timeout(const Duration(seconds: 25));
        } on http.ClientException catch (error) {
          if (!error.message.contains('Invalid header field name, with 32')) {
            rethrow;
          }
          final remaining = 25000 - clock.elapsedMilliseconds;
          if (remaining <= 0) {
            throw TimeoutException('Eulji calendar request timed out');
          }
          compatibilityRequired = true;
          response = await eulji_transport.fetchEuljiCalendar(
            uri,
            timeout: Duration(milliseconds: remaining),
          );
        }
      }
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Eulji calendar unavailable');
      }
      events.addAll(parse(utf8.decode(response.bodyBytes), year, month + 1));
    }
    return _finish(events, year);
  }

  static List<AcademicEvent> parse(String body, int year, int month) {
    final doc = html.parse(body);
    final heading = doc.querySelector('.years-month form');
    if (heading?.querySelector('strong')?.text.trim() != '$year년' ||
        heading?.querySelector('span')?.text.trim() != '$month월') {
      throw const FormatException('Unexpected Eulji calendar month');
    }
    final rows = <AcademicEvent>[];
    for (final row in doc.querySelectorAll('table.board-data tbody tr')) {
      final dateCell = row.querySelector('td.first');
      final title = row.querySelector('td.subject strong')?.text;
      if (dateCell == null) continue;
      final matches = RegExp(
        r'(\d{4})\.(\d{2})\.(\d{2})',
      ).allMatches(dateCell.text).toList();
      if (title == null || matches.isEmpty || matches.length > 2) {
        throw const FormatException('Invalid Eulji calendar event');
      }
      DateTime date(RegExpMatch m) =>
          _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      final start = date(matches.first);
      rows.add(
        _event(
          title,
          start,
          date(matches.last),
          Uri.https('eulji.ac.kr', '/renewal/index.html', {
            'menuno': '8069',
            'calendar_no': '105',
            'year': '${start.year}',
            'month': '${start.month - 1}',
          }),
        ),
      );
    }
    return rows;
  }
}
