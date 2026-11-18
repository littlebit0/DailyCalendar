import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'academic_source.dart';

class KookminAcademicSource implements AcademicSource {
  KookminAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kookmin';
  @override
  String get name => '국민대학교';
  @override
  Uri get website =>
      Uri.https('www.kookmin.ac.kr', '/user/scGuid/scSchedule/index.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <AcademicEvent>[];
    // An academic year runs March to the next February.
    for (final academicYear in [year - 1, year]) {
      final response = await _client
          .get(
            website.replace(
              queryParameters: {
                'type': 'yy',
                'yyyy': '$academicYear',
                'listType': 'list',
              },
            ),
          )
          .timeout(const Duration(seconds: 20));
      checkAcademicResponse(response);
      events.addAll(
        parse(
          utf8.decode(response.bodyBytes),
          academicYear,
          // January–February of [year] belong to the prior academic year, so
          // a not yet published [year] page must not discard them.
          allowUnpublished: academicYear == year,
        ).where(
          (e) =>
              e.start.isBefore(DateTime(year + 1)) &&
              e.end.isAfter(DateTime(year)),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Empty Kookmin calendar');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  /// [allowUnpublished] returns no events for a year page that shows its
  /// "no data" notice (observed for 2028 on 2026-11-19).
  static List<AcademicEvent> parse(
    String body,
    int academicYear, {
    bool allowUnpublished = false,
  }) {
    final document = html.parse(body);
    if (document.querySelector('input[name=yyyy]')?.attributes['value'] !=
        '$academicYear') {
      throw const FormatException('Unexpected Kookmin academic year');
    }
    // Published pages also carry `li.no_result` in their week list, so only
    // the annual list's notice counts.
    if (allowUnpublished &&
        document.querySelectorAll('#monthTable tr').isEmpty &&
        document
                .querySelector('.list_type .table_wrap .no_result p')
                ?.text
                .trim() ==
            '등록된 데이터가 없습니다.') {
      return const [];
    }
    final months = <int>{};
    final occurrences = <String, int>{};
    final events = <AcademicEvent>[];
    for (final row in document.querySelectorAll('#monthTable tr')) {
      final cells = row.querySelectorAll('td');
      if (cells.length != 3) {
        throw const FormatException('Invalid Kookmin calendar row');
      }
      final ranges = cells[1].text.trim().split('~');
      final title = cells[2].text.trim();
      if (ranges.length != 2 || title.isEmpty) {
        throw const FormatException('Invalid Kookmin event');
      }
      DateTime date(String value, [DateTime? start]) {
        final match = RegExp(
          r'^\s*(\d{2})\.(\d{2}) \(([월화수목금토일])\)\s*$',
        ).firstMatch(value);
        if (match == null) {
          throw const FormatException('Invalid Kookmin date');
        }
        final m = int.parse(match[1]!);
        final d = int.parse(match[2]!);
        final y = start == null
            ? academicYear + (m <= 2 ? 1 : 0)
            : academicRangeEndYear(start, m);
        final result = DateTime(y, m, d);
        // The published weekday confirms the inferred calendar year.
        if (result.year != y ||
            result.month != m ||
            result.day != d ||
            '월화수목금토일'[result.weekday - 1] != match[3]) {
          throw const FormatException('Invalid Kookmin date');
        }
        return result;
      }

      final start = date(ranges.first);
      final last = date(ranges.last, start);
      if (last.isBefore(start)) {
        throw const FormatException('Invalid Kookmin period');
      }
      months.add(start.month);
      final key = '$academicYear:$title';
      final occurrence = occurrences.update(
        key,
        (n) => n + 1,
        ifAbsent: () => 0,
      );
      events.add(
        AcademicEvent(
          sourceId: '$key:$occurrence',
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url:
              'https://www.kookmin.ac.kr/user/scGuid/scSchedule/index.do?type=yy&yyyy=$academicYear&listType=list',
        ),
      );
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete Kookmin annual calendar');
    }
    return events;
  }

  @override
  void close() => _client.close();
}
