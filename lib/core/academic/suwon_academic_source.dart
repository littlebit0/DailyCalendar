import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class SuwonAcademicSource implements AcademicSource {
  SuwonAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'suwon';
  @override
  String get name => '수원대학교';
  @override
  Uri get website =>
      Uri.https('www.suwon.ac.kr', '/index.html', {'menuno': '727'});
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .post(
          Uri.https(
            'www.suwon.ac.kr',
            '/mainHp/FrontSchdulManageMonthAjax.html',
          ),
          body: {'year': '$year', 'selYear': '$year'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('Suwon calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final response = jsonDecode(body);
    if (response is! Map ||
        response['resultList'] is! List ||
        (response['resultList'] as List).isEmpty) {
      throw const FormatException('No published Suwon calendar');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{12}$').hasMatch(value)) {
        throw const FormatException('Invalid Suwon date');
      }
      final y = int.parse(value.substring(0, 4));
      final m = int.parse(value.substring(4, 6));
      final d = int.parse(value.substring(6, 8));
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        throw const FormatException('Invalid Suwon date');
      }
      return result;
    }

    final events = <String, AcademicEvent>{};
    for (final row in response['resultList'] as List) {
      if (row is! Map ||
          row['schdulNm'] is! String ||
          (row['schdulNm'] as String).trim().isEmpty) {
        throw const FormatException('Invalid Suwon title');
      }
      final start = date(row['schdulBgnde']);
      final last = date(row['schdulEndde']);
      if (last.isBefore(start) ||
          start.year < year - 1 ||
          start.year > year ||
          (start.year == year - 1 && start.month != 12) ||
          last.year > year + 1) {
        throw const FormatException('Unexpected Suwon calendar year');
      }
      final end = DateTime(last.year, last.month, last.day + 1);
      if (!start.isBefore(DateTime(year + 1)) || !end.isAfter(DateTime(year))) {
        continue;
      }
      final title = (row['schdulNm'] as String).trim();
      final identity = '${start.toIso8601String()}:$title';
      events[identity] = AcademicEvent(
        sourceId: identity,
        title: title,
        start: start,
        end: end,
        url: 'https://www.suwon.ac.kr/index.html?menuno=727',
      );
    }
    if (events.isEmpty || !events.values.any((e) => e.start.year == year)) {
      throw const FormatException('No published Suwon calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
