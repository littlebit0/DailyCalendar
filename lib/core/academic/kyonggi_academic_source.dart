import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class KyonggiAcademicSource implements AcademicSource {
  KyonggiAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kyonggi';
  @override
  String get name => '경기대학교';
  @override
  Uri get website => Uri.https(
    'www.kyonggi.ac.kr',
    '/www/selectTnSchafsSchdulListUS.do',
    {'key': '5819', 'sc1': '10'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          website.replace(
            queryParameters: {...website.queryParameters, 'sc3': '$year'},
          ),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Kyonggi calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document
            .querySelector('.calendar_yearly .calendar_date span')
            ?.text
            .trim() !=
        '$year') {
      throw const FormatException('Unexpected Kyonggi year');
    }
    final months = <String>{};
    final events = <String, AcademicEvent>{};
    for (final block in document.querySelectorAll(
      '.schedule_content__group .schedule_content',
    )) {
      final monthId = block.id.replaceFirst('sc_con_', '');
      final match = RegExp(r'^(\d{4})(\d{2})$').firstMatch(monthId);
      if (match == null || !months.add(monthId)) {
        throw const FormatException('Invalid Kyonggi month');
      }
      final monthYear = int.parse(match[1]!);
      final month = int.parse(match[2]!);
      for (final row in block.querySelectorAll('.info_box__item')) {
        final text = row.querySelector('.info_box__date')?.text.trim() ?? '';
        final dates = RegExp(
          r'(\d{4})\.(\d{2})\.(\d{2})\([^)]*\)',
        ).allMatches(text).toList();
        final remainder = text
            .replaceAll(RegExp(r'\d{4}\.\d{2}\.\d{2}\([^)]*\)'), '')
            .replaceAll('~', '')
            .trim();
        final title =
            row
                .querySelector('.info_box__text')
                ?.text
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim() ??
            '';
        if (dates.isEmpty ||
            dates.length > 2 ||
            remainder.isNotEmpty ||
            title.isEmpty) {
          throw const FormatException('Invalid Kyonggi event');
        }
        DateTime date(RegExpMatch m) {
          final y = int.parse(m[1]!);
          final mo = int.parse(m[2]!);
          final d = int.parse(m[3]!);
          final value = DateTime(y, mo, d);
          if (value.year != y || value.month != mo || value.day != d) {
            throw const FormatException('Invalid Kyonggi date');
          }
          return value;
        }

        final start = date(dates.first);
        final last = date(dates.last);
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(monthYear, month + 1)) ||
            !end.isAfter(DateTime(monthYear, month))) {
          throw const FormatException('Unexpected Kyonggi event period');
        }
        if (start.isBefore(DateTime(year + 1)) && end.isAfter(DateTime(year))) {
          final identity =
              '${start.toIso8601String()}:${last.toIso8601String()}:$title';
          events[identity] = AcademicEvent(
            sourceId: identity,
            title: title,
            start: start,
            end: end,
            url:
                'https://www.kyonggi.ac.kr/www/selectTnSchafsSchdulListUS.do?key=5819&sc1=10&sc3=$year',
          );
        }
      }
    }
    final expected = {
      for (var month = 1; month <= 14; month++)
        '${month <= 12 ? year : year + 1}${(month <= 12 ? month : month - 12).toString().padLeft(2, '0')}',
    };
    if (months.length != 14 ||
        !months.containsAll(expected) ||
        events.isEmpty) {
      throw const FormatException('Incomplete Kyonggi calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
