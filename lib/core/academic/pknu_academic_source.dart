import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;

import 'academic_source.dart';

class PknuAcademicSource implements AcademicSource {
  PknuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'pknu';
  @override
  String get name => '국립부경대학교';
  @override
  Uri get website => Uri.https('www.pknu.ac.kr', '/main/31');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    String? verifiedAnnual;
    for (var offset = 0; offset <= 12; offset++) {
      final selectedYear = offset == 0 ? year - 1 : year;
      final month = offset == 0 ? 12 : offset;
      if (offset > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.pknu.ac.kr', '/getScheduleList.do'),
            body: {
              'year': '$selectedYear',
              'month': month.toString().padLeft(2, '0'),
              'day': '1',
              'action': 'month',
              'steId': 'IEav5ISH',
            },
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      final body = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(body);
      if (decoded is! Map ||
          decoded['list'] is! List ||
          (selectedYear == year && (decoded['list'] as List).isEmpty)) {
        throw const FormatException('Incomplete PKNU calendar');
      }
      final hasReversed = (decoded['list'] as List).any(
        (row) =>
            row is Map &&
            row['strDt'] is String &&
            row['endDt'] is String &&
            (row['strDt'] as String).compareTo(row['endDt'] as String) > 0,
      );
      if (hasReversed && verifiedAnnual == null) {
        final official = await _client
            .get(Uri.https('stat.pknu.ac.kr', '/stat/281'))
            .timeout(const Duration(seconds: 20));
        checkAcademicResponse(official);
        verifiedAnnual = utf8.decode(official.bodyBytes);
      }
      for (final event in parse(
        body,
        selectedYear,
        month,
        verifiedAnnual: hasReversed ? verifiedAnnual : null,
      )) {
        if (!event.start.isBefore(DateTime(year + 1)) ||
            !event.end.isAfter(DateTime(year))) {
          continue;
        }
        if (events.containsKey(event.sourceId) &&
            jsonEncode(events[event.sourceId]!.toJson()) !=
                jsonEncode(event.toJson())) {
          throw const FormatException('Conflicting PKNU calendar identity');
        }
        events[event.sourceId] = event;
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published PKNU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(
    String body,
    int year,
    int month, {
    String? verifiedAnnual,
  }) {
    if (month < 1 || month > 12) {
      throw const FormatException('Invalid PKNU request month');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['list'] is! List) {
      throw const FormatException('Invalid PKNU calendar');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{8}$').hasMatch(value)) {
        throw const FormatException('Invalid PKNU date');
      }
      final parts = [
        int.parse(value.substring(0, 4)),
        int.parse(value.substring(4, 6)),
        int.parse(value.substring(6, 8)),
      ];
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid PKNU date');
      }
      return result;
    }

    final events = <AcademicEvent>[];
    for (final row in decoded['list'] as List) {
      if (row is! Map ||
          row['steId'] != 'IEav5ISH' ||
          row['stat'] != 'Y' ||
          row['schSeq'] is! int ||
          row['schNm'] is! String ||
          (row['schNm'] as String).trim().isEmpty) {
        throw const FormatException('Invalid PKNU event');
      }
      final start = date(row['strDt']);
      var last = date(row['endDt']);
      var url = 'https://www.pknu.ac.kr/main/31';
      if (last.isBefore(start) && verifiedAnnual != null) {
        // Do not guess a corrected year. The independent official annual
        // publication must match this exact title and start date unambiguously.
        final matches = <DateTime>[];
        for (final tr
            in html.parse(verifiedAnnual).querySelectorAll('table tbody tr')) {
          final cells = tr.querySelectorAll('td');
          if (cells.length != 2 ||
              cells[1].text.replaceAll(RegExp(r'\s+'), '') !=
                  (row['schNm'] as String).replaceAll(RegExp(r'\s+'), '')) {
            continue;
          }
          final range = RegExp(
            r'^(\d{4})\.(\d{2})\.(\d{2})~(\d{4})\.(\d{2})\.(\d{2})$',
          ).firstMatch(cells[0].text.replaceAll(RegExp(r'\s+'), ''));
          if (range != null &&
              date('${range[1]}${range[2]}${range[3]}') == start) {
            final end = date('${range[4]}${range[5]}${range[6]}');
            if (!end.isBefore(start)) matches.add(end);
          }
        }
        if (matches.length != 1) {
          throw const FormatException(
            'PKNU invalid period lacks authoritative correction',
          );
        }
        last = matches.single;
        url = 'https://stat.pknu.ac.kr/stat/281';
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      // The erroneous end year also makes December's winter row appear in the
      // January query. Once its actual interval is independently verified,
      // omit it from that mismatched month; December still returns the event.
      if (url == 'https://stat.pknu.ac.kr/stat/281' &&
          (!start.isBefore(DateTime(year, month + 1)) ||
              !end.isAfter(DateTime(year, month)))) {
        continue;
      }
      if (last.isBefore(start) ||
          !start.isBefore(DateTime(year, month + 1)) ||
          !end.isAfter(DateTime(year, month))) {
        throw const FormatException('Unexpected PKNU period');
      }
      events.add(
        AcademicEvent(
          sourceId: row['schSeq'].toString(),
          title: (row['schNm'] as String).trim(),
          start: start,
          end: end,
          url: url,
        ),
      );
    }
    return events;
  }

  @override
  void close() => _client.close();
}
