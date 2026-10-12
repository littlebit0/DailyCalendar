import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

DateTime _date(int year, int month, int day) {
  final value = DateTime(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    throw const FormatException('Invalid published academic date');
  }
  return value;
}

AcademicEvent _event(String title, DateTime start, DateTime last, Uri website) {
  if (title.isEmpty || last.isBefore(start)) {
    throw const FormatException('Invalid published academic event');
  }
  return AcademicEvent(
    sourceId: '${start.toIso8601String()}:$title',
    title: title,
    start: start,
    end: DateTime(last.year, last.month, last.day + 1),
    url: website.toString(),
  );
}

List<AcademicEvent> _finish(List<AcademicEvent> values, int year) {
  final events = <String, AcademicEvent>{};
  for (final event in values) {
    if (!event.start.isBefore(DateTime(year + 1)) ||
        !event.end.isAfter(DateTime(year))) {
      continue;
    }
    final old = events[event.sourceId];
    if (old != null && jsonEncode(old.toJson()) != jsonEncode(event.toJson())) {
      throw const FormatException('Conflicting published academic events');
    }
    events[event.sourceId] = event;
  }
  if (events.isEmpty) {
    throw const FormatException(
      'No published academic calendar for requested year',
    );
  }
  return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}

abstract class _AnnualHtmlSource implements AcademicSource {
  _AnnualHtmlSource(http.Client? client) : client = client ?? http.Client();
  final http.Client client;
  Future<String> get(Uri uri) async {
    final response = await client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Academic calendar unavailable');
    }
    return utf8.decode(response.bodyBytes);
  }

  @override
  void close() => client.close();
}

class NambuAcademicSource extends _AnnualHtmlSource {
  NambuAcademicSource({http.Client? client}) : super(client);
  @override
  String get id => 'nambu';
  @override
  String get name => '남부대학교';
  @override
  Uri get website => Uri.https('www.nambu.ac.kr', '/custom/scheduleView.do', {
    'menuCd': 'KR005002002',
  });
  @override
  Future<List<AcademicEvent>> fetch(int year) async =>
      parse(await get(website), year);
  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    final events = <AcademicEvent>[];
    final website = Uri.https('www.nambu.ac.kr', '/custom/scheduleView.do', {
      'menuCd': 'KR005002002',
    });
    for (final table in document.querySelectorAll('table')) {
      if (table.querySelector('caption')?.text.trim() != '학사 일정표') continue;
      for (final row in table.querySelectorAll('tbody tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) throw const FormatException('Invalid Nambu row');
        final dates = RegExp(
          r'(\d{4})\.(\d{2})\.(\d{2})\([월화수목금토일]\)',
        ).allMatches(cells[0].text).toList();
        if (dates.isEmpty || dates.length > 2) {
          throw const FormatException('Invalid Nambu range');
        }
        DateTime read(RegExpMatch m) =>
            _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
        events.add(
          _event(
            cells[1].text.trim(),
            read(dates.first),
            read(dates.last),
            website,
          ),
        );
      }
    }
    return _finish(events, year);
  }
}

class PcuAcademicSource extends _AnnualHtmlSource {
  PcuAcademicSource({http.Client? client}) : super(client);
  @override
  String get id => 'pcu';
  @override
  String get name => '배재대학교';
  @override
  Uri get website => Uri.https('www.pcu.ac.kr', '/kor/30/schedules/CAT072');
  @override
  Future<List<AcademicEvent>> fetch(int year) async => parse(
    await get(website.replace(queryParameters: {'year': '$year'})),
    year,
  );
  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document
            .querySelector('#years_sel option[selected]')
            ?.attributes['value'] !=
        '$year') {
      throw const FormatException('Unexpected PCU calendar year');
    }
    final months = document.querySelectorAll('#school_cal > ol > li');
    if (months.length != 14) {
      throw const FormatException('Incomplete PCU calendar');
    }
    final events = <AcademicEvent>[];
    final url = Uri.https('www.pcu.ac.kr', '/kor/30/schedules/CAT072', {
      'year': '$year',
    });
    for (var index = 0; index < months.length; index++) {
      final currentYear = index >= 12 ? year + 1 : year;
      for (final row in months[index].querySelectorAll('.txts > ol > li')) {
        final text = row.querySelector('strong')?.text.trim() ?? '';
        final dates = RegExp(r'(\d{2})-(\d{2})').allMatches(text).toList();
        if (dates.isEmpty || dates.length > 2) {
          throw const FormatException('Invalid PCU date');
        }
        final start = _date(
          currentYear,
          int.parse(dates.first[1]!),
          int.parse(dates.first[2]!),
        );
        final last = _date(
          currentYear + (int.parse(dates.last[1]!) < start.month ? 1 : 0),
          int.parse(dates.last[1]!),
          int.parse(dates.last[2]!),
        );
        for (final title in row.querySelectorAll('ul > li')) {
          events.add(_event(title.text.trim(), start, last, url));
        }
      }
    }
    return _finish(events, year);
  }
}

class KonyangAcademicSource extends _AnnualHtmlSource {
  KonyangAcademicSource({http.Client? client}) : super(client);
  @override
  String get id => 'konyang';
  @override
  String get name => '건양대학교';
  @override
  Uri get website => Uri.https(
    'www.konyang.ac.kr',
    '/prog/schedule/kor/sub06_01_01_01/3/haksa.do',
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final all = <AcademicEvent>[];
    for (final selected in [year - 1, year]) {
      if (all.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      all.addAll(
        parse(
          await get(
            website.replace(queryParameters: {'rdate': '$selected-03-01'}),
          ),
          selected,
        ),
      );
    }
    return _finish(all, year);
  }

  static List<AcademicEvent> parse(String body, int selected) {
    final document = html.parse(body);
    if (document
            .querySelector('#prev_schdule option[selected]')
            ?.attributes['value'] !=
        '$selected-03-01') {
      throw const FormatException('Unexpected Konyang year');
    }
    final events = <AcademicEvent>[];
    final months = <int>{};
    var month = 0;
    final tables = document
        .querySelectorAll('table')
        .where((table) => table.querySelector('th[scope="row"]') != null)
        .toList();
    if (tables.length != 1) {
      throw const FormatException('Ambiguous Konyang calendar');
    }
    for (final row in tables.single.querySelectorAll('tbody tr')) {
      final heading = row.querySelector('th[scope="row"]');
      if (heading != null) {
        final match = RegExp(r'^(\d{1,2})월$').firstMatch(heading.text.trim());
        if (match == null) continue;
        month = int.parse(match[1]!);
        months.add(month);
      }
      final cells = row.querySelectorAll('td');
      if (month == 0 || cells.length != 2) continue;
      final current = selected + (month < 3 ? 1 : 0);
      final parts = cells.first.text.trim().split('~');
      DateTime read(String text) {
        final match = RegExp(
          r'^(?:(\d{1,2})\.)?(\d{1,2})$',
        ).firstMatch(text.trim());
        if (match == null) throw const FormatException('Invalid Konyang date');
        final m = match[1] == null ? month : int.parse(match[1]!);
        return _date(current + (m < month ? 1 : 0), m, int.parse(match[2]!));
      }

      if (parts.length > 2) {
        throw const FormatException('Invalid Konyang range');
      }
      events.add(
        _event(
          cells.last.text.trim(),
          read(parts.first),
          read(parts.last),
          Uri.https(
            'www.konyang.ac.kr',
            '/prog/schedule/kor/sub06_01_01_01/3/haksa.do',
            {'rdate': '$selected-03-01'},
          ),
        ),
      );
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Konyang calendar');
    }
    return events;
  }
}

class DjuAcademicSource extends _AnnualHtmlSource {
  DjuAcademicSource({http.Client? client}) : super(client);
  @override
  String get id => 'dju';
  @override
  String get name => '대전대학교';
  @override
  Uri get website => Uri.https(
    'www.dju.ac.kr',
    '/dju/sv/schdulView/schdulCalendarView.do',
    {'mi': '1166'},
  );
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final all = <AcademicEvent>[];
    for (final selected in [year - 1, year]) {
      if (all.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await client
          .post(
            Uri.https('www.dju.ac.kr', '/dju/sv/schdulView/calendar.do'),
            body: {
              'mi': '1166',
              'sysId': 'dju',
              'year': '$selected',
              'srchYear': '$selected',
              'firstDay': '${selected}0301',
              'endDay': '${selected + 1}0228',
              'section': '3',
            },
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('DJU calendar unavailable');
      }
      all.addAll(parse(utf8.decode(response.bodyBytes), selected));
    }
    return _finish(all, year);
  }

  static List<AcademicEvent> parse(String body, int selected) {
    final document = html.parse(body);
    if (document.querySelector('h4[in-data]')?.attributes['in-data'] !=
        '$selected') {
      throw const FormatException('Unexpected DJU year');
    }
    final events = <AcademicEvent>[];
    final months = <String>{};
    for (final table in document.querySelectorAll(
      '.schedule_calendar > table',
    )) {
      final heading = RegExp(
        r'^(\d{4})년 (\d{1,2})월 학사일정을',
      ).firstMatch(table.querySelector('caption')?.text ?? '');
      if (heading == null) continue;
      final y = int.parse(heading[1]!);
      final month = int.parse(heading[2]!);
      months.add('$y-$month');
      for (final row in table.querySelectorAll('tbody tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) {
          throw const FormatException('Invalid DJU event row');
        }
        final dates = RegExp(
          r'(\d{2})-(\d{2})',
        ).allMatches(cells.first.text).toList();
        if (dates.isEmpty || dates.length > 2) {
          throw const FormatException('Invalid DJU date');
        }
        final startMonth = int.parse(dates.first[1]!);
        final startYear = y - (startMonth > month ? 1 : 0);
        final start = _date(startYear, startMonth, int.parse(dates.first[2]!));
        final endMonth = int.parse(dates.last[1]!);
        final last = _date(
          startYear + (endMonth < startMonth ? 1 : 0),
          endMonth,
          int.parse(dates.last[2]!),
        );
        events.add(
          _event(
            cells.last.text.trim(),
            start,
            last,
            Uri.https(
              'www.dju.ac.kr',
              '/dju/sv/schdulView/schdulCalendarView.do',
              {'mi': '1166'},
            ),
          ),
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete DJU calendar');
    }
    return events;
  }
}
