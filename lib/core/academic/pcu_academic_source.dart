import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class PcuAcademicSource implements AcademicSource {
  PcuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'pcu';
  @override
  String get name => '배재대학교';
  @override
  Uri get website => Uri.https('www.pcu.ac.kr', '/kor/30/schedules/CAT072');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    // Each page lists January to the next February; the previous year's page
    // alone carries December rows that continue into [year].
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(
            website.replace(queryParameters: {'year': '$selected'}),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
          )
          .timeout(const Duration(seconds: 30));
      // The page pads each month with whitespace: 2025 is about 7 MB.
      if (response.statusCode != 200 || response.bodyBytes.length > 20000000) {
        throw const FormatException('PCU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.year == selected &&
            event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events.add(event);
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published PCU calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Every published row of the [year] page, January to the next February.
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
    final url = Uri.https('www.pcu.ac.kr', '/kor/30/schedules/CAT072', {
      'year': '$year',
    }).toString();
    final events = <String, AcademicEvent>{};
    for (var index = 0; index < months.length; index++) {
      final month = index % 12 + 1;
      final label = months[index].querySelector('.month_tt')?.nodes.first.text;
      if (label?.trim() != '$month월') {
        throw const FormatException('Unexpected PCU month');
      }
      final monthYear = index >= 12 ? year + 1 : year;
      for (final row in months[index].querySelectorAll('.txts > ol > li')) {
        final text = row.querySelector('strong')?.text.trim() ?? '';
        final range = RegExp(
          r'^(\d{2})-(\d{2})(?:~(\d{2})-(\d{2}))?일$',
        ).firstMatch(text);
        if (range == null) {
          throw const FormatException('Invalid PCU date');
        }
        final start = _date(
          monthYear,
          int.parse(range[1]!),
          int.parse(range[2]!),
        );
        if (start.month != month) {
          throw const FormatException('Unexpected PCU period');
        }
        final lastMonth = int.parse(range[3] ?? range[1]!);
        final last = _date(
          monthYear + (lastMonth < month ? 1 : 0),
          lastMonth,
          int.parse(range[4] ?? range[2]!),
        );
        final titles = row.querySelectorAll('ul > li');
        if (titles.isEmpty || last.isBefore(start)) {
          throw const FormatException('Invalid PCU event');
        }
        for (final item in titles) {
          final title = item.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.isEmpty) {
            throw const FormatException('Invalid PCU event');
          }
          // Same identity as the previous release keeps exclusions attached.
          final event = AcademicEvent(
            sourceId: '${start.toIso8601String()}:$title',
            title: title,
            start: start,
            end: DateTime(last.year, last.month, last.day + 1),
            url: url,
          );
          final old = events[event.sourceId];
          if (old != null &&
              jsonEncode(old.toJson()) != jsonEncode(event.toJson())) {
            throw const FormatException('Conflicting PCU events');
          }
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Incomplete PCU calendar');
    }
    return events.values.toList();
  }

  static DateTime _date(int year, int month, int day) {
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      throw const FormatException('Invalid PCU date');
    }
    return value;
  }

  @override
  void close() => _client.close();
}
