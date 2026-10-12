import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class MokpoAcademicSource implements AcademicSource {
  MokpoAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'mokpo';
  @override
  String get name => '국립목포대학교';
  @override
  Uri get website => Uri.https('www.mokpo.ac.kr', '/www/148/subview.do');

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final (selectedYear, semester) in [
      (year - 1, 2),
      (year, 1),
      (year, 2),
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = await _client
          .post(
            Uri.https(
              'www.mokpo.ac.kr',
              '/schdulmanage/www/1/mokpoMainSchdul.do',
            ),
            // The public server rejects generic CLI user agents; identify Daily
            // with the same browser-compatible request accepted by its public UI.
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            },
            body: {
              'kind': semester == 1 ? 'preHalf' : 'nextHalf',
              'year': '$selectedYear',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Mokpo calendar unavailable');
      }
      for (final event in parse(
        utf8.decode(response.bodyBytes),
        selectedYear,
        semester,
      )) {
        if (!event.start.isBefore(DateTime(year + 1)) ||
            !event.end.isAfter(DateTime(year))) {
          continue;
        }
        final previous = events[event.sourceId];
        if (previous != null &&
            jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting Mokpo event');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Mokpo calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int academicYear,
    int semester,
  ) {
    final document = html.parse(body);
    if (![1, 2].contains(semester) ||
        document.querySelector('input[name="year"]')?.attributes['value'] !=
            '$academicYear') {
      throw const FormatException('Unexpected Mokpo academic year');
    }
    final expectedMonths = semester == 1
        ? [3, 4, 5, 6, 7, 8]
        : [9, 10, 11, 12, 1, 2];
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final section in document.querySelectorAll('.yearSchdulWrap')) {
      final identity = RegExp(
        r'^monthArea(\d{4})(\d{1,2})$',
      ).firstMatch(section.attributes['id'] ?? '');
      if (identity == null) {
        throw const FormatException('Invalid Mokpo month');
      }
      final year = int.parse(identity[1]!);
      final month = int.parse(identity[2]!);
      if (!expectedMonths.contains(month) ||
          !months.add(month) ||
          year != academicYear + (month < 3 ? 1 : 0)) {
        throw const FormatException('Unexpected Mokpo month coverage');
      }
      for (final row in section.querySelectorAll('.scheList > ul > li > dl')) {
        final title = (row.querySelector('dd')?.text ?? '').trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        final rawDate = (row.querySelector('dt')?.text ?? '')
            .replaceAll(RegExp(r'\([월화수목금토일]\)'), '')
            .replaceAll(RegExp(r'\s+'), '');
        final match = RegExp(
          r'^(\d{2})\.(\d{2})\.(?:~(\d{2})\.(\d{2})\.)?$',
        ).firstMatch(rawDate);
        if (title.isEmpty || match == null) {
          throw const FormatException('Invalid Mokpo event');
        }
        DateTime date(int y, int m, int d) {
          final result = DateTime(y, m, d);
          if (result.year != y || result.month != m || result.day != d) {
            throw const FormatException('Invalid Mokpo date');
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
        if (startMonth != month || last.isBefore(start)) {
          throw const FormatException('Invalid Mokpo period');
        }
        final sourceId = '$title:${start.toIso8601String()}';
        if (events.containsKey(sourceId)) {
          throw const FormatException('Duplicate Mokpo event identity');
        }
        events[sourceId] = AcademicEvent(
          sourceId: sourceId,
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: 'https://www.mokpo.ac.kr/www/148/subview.do',
        );
      }
    }
    if (months.length != 6 || events.isEmpty) {
      throw const FormatException('Incomplete Mokpo semester');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
