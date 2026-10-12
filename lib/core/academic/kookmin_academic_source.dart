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
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Kookmin calendar unavailable');
      }
      events.addAll(
        parse(utf8.decode(response.bodyBytes), academicYear).where(
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

  static List<AcademicEvent> parse(String body, int academicYear) {
    final document = html.parse(body);
    if (document.querySelector('input[name=yyyy]')?.attributes['value'] !=
        '$academicYear') {
      throw const FormatException('Unexpected Kookmin academic year');
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
      DateTime date(String value) {
        final match = RegExp(
          r'^\s*(\d{2})\.(\d{2}) \([월화수목금토일]\)\s*$',
        ).firstMatch(value);
        if (match == null) {
          throw const FormatException('Invalid Kookmin date');
        }
        final m = int.parse(match[1]!);
        final d = int.parse(match[2]!);
        final y = academicYear + (m <= 2 ? 1 : 0);
        final result = DateTime(y, m, d);
        if (result.year != y || result.month != m || result.day != d) {
          throw const FormatException('Invalid Kookmin date');
        }
        return result;
      }

      final start = date(ranges.first);
      final last = date(ranges.last);
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
