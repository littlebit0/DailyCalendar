import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KongjuAcademicSource implements AcademicSource {
  KongjuAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kongju';
  @override
  String get name => '국립공주대학교';
  @override
  Uri get website => Uri.https('www.kongju.ac.kr', '/KNU/16834/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final entry = await _client
        .get(website)
        .timeout(const Duration(seconds: 20));
    if (entry.statusCode != 200 || entry.bodyBytes.length > 8000000) {
      throw const FormatException('Kongju calendar unavailable');
    }
    final csrf = RegExp(
      r'var csrfToken = "([A-Za-z0-9-]+)";',
    ).firstMatch(utf8.decode(entry.bodyBytes))?[1];
    final setCookie = entry.headers['set-cookie'];
    if (csrf == null || setCookie == null) {
      throw const FormatException(
        'Kongju anonymous calendar session unavailable',
      );
    }
    final cookies = RegExp(
      r'(?:^|,)\s*([^=;,\s]+)=([^;,]*)',
    ).allMatches(setCookie).map((m) => '${m[1]}=${m[2]}').join('; ');
    if (cookies.isEmpty) {
      throw const FormatException('Kongju anonymous cookie unavailable');
    }
    final events = <String, AcademicEvent>{};
    for (final selectedYear in [year - 1, year]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = await _client
          .post(
            Uri.https('www.kongju.ac.kr', '/schdulmanage/KNU/80/yearSchdul.do'),
            headers: {
              'X-CSRF-TOKEN': csrf,
              'Cookie': cookies,
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': website.toString(),
            },
            body: {'kind': '', 'year': '$selectedYear'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Kongju annual calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
      )) {
        if (!event.start.isBefore(DateTime(year + 1)) ||
            !event.end.isAfter(DateTime(year))) {
          continue;
        }
        final previous = events[event.sourceId];
        if (previous != null &&
            jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting Kongju event');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Kongju calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('input[name="year"]')?.attributes['value'] !=
        '$year') {
      throw const FormatException('Unexpected Kongju calendar year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in document.querySelectorAll(
      '#timeTableList.yearSchdul > ul > li',
    )) {
      final month = int.tryParse(
        (section.querySelector('.num h3')?.text ?? '')
            .replaceAll('월', '')
            .trim(),
      );
      if (month == null || month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid Kongju month coverage');
      }
      for (final row in section.querySelectorAll('.desc > dl')) {
        final link = row.querySelector('dd > a.onDate');
        final title = link?.text.trim() ?? '';
        final identity = RegExp(
          r"^javascript:set_layer\('(\d+)', 'KNU', '80'\);$",
        ).firstMatch(link?.attributes['onclick'] ?? '');
        final rawDate = (row.querySelector('dt')?.text ?? '')
            .replaceAll(RegExp(r'\((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\)'), '')
            .replaceAll(RegExp(r'\s+'), '');
        final match = RegExp(
          r'^(\d{2})-(\d{2})(?:~(\d{2})-(\d{2}))?$',
        ).firstMatch(rawDate);
        if (title.isEmpty || identity == null || match == null) {
          throw const FormatException('Invalid Kongju event');
        }
        DateTime date(int y, int m, int d) {
          final result = DateTime(y, m, d);
          if (result.year != y || result.month != m || result.day != d) {
            throw const FormatException('Invalid Kongju date');
          }
          return result;
        }

        final startMonth = int.parse(match[1]!);
        final start = date(year, startMonth, int.parse(match[2]!));
        final endMonth = match[3] == null ? startMonth : int.parse(match[3]!);
        final last = match[3] == null
            ? start
            : date(
                endMonth < startMonth ? year + 1 : year,
                endMonth,
                int.parse(match[4]!),
              );
        if (startMonth != month ||
            last.isBefore(start) ||
            events.containsKey(identity[1]!)) {
          throw const FormatException(
            'Invalid Kongju event period or duplicate',
          );
        }
        events[identity[1]!] = AcademicEvent(
          sourceId: identity[1]!,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: 'https://www.kongju.ac.kr/KNU/16834/subview.do',
        );
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Kongju calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
