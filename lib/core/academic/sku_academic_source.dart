import 'dart:convert';
import 'package:http/http.dart' as http;
import 'academic_source.dart';

/// The public calendar proxy used by SKU's current undergraduate calendar.
class SkuAcademicSource implements AcademicSource {
  SkuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'sku';
  @override
  String get name => '서경대학교';
  @override
  Uri get website => Uri.https('www.skuniv.ac.kr', '/academic-calendar');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final response = await _client
        .get(
          Uri.https('www.skuniv.ac.kr', '/academy-calendar', {
            // Match the site's Korean-midnight UTC query boundaries.
            'timeMin': DateTime.utc(year - 1, 12, 31, 15).toIso8601String(),
            'timeMax': DateTime.utc(
              year,
              12,
              31,
              14,
              59,
              59,
              999,
            ).toIso8601String(),
          }),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
            'Referer': website.toString(),
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('SKU calendar unavailable');
    }
    return parse(utf8.decode(response.bodyBytes), year);
  }

  static List<AcademicEvent> parse(String body, int year) {
    final data = jsonDecode(body);
    if (data is! Map ||
        data['kind'] != 'calendar#events' ||
        data['summary'] != '포탈 학부/학사' ||
        data['timeZone'] != 'Asia/Seoul' ||
        // Google Calendar returns nextSyncToken only on the last page.
        data['nextPageToken'] != null ||
        data['nextSyncToken'] is! String ||
        (data['nextSyncToken'] as String).isEmpty ||
        data['items'] is! List ||
        (data['items'] as List).isEmpty) {
      throw const FormatException('Incomplete SKU undergraduate calendar');
    }
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid SKU date');
      }
      final parts = value.split('-').map(int.parse).toList();
      final result = DateTime(parts[0], parts[1], parts[2]);
      if (result.year != parts[0] ||
          result.month != parts[1] ||
          result.day != parts[2]) {
        throw const FormatException('Invalid SKU date');
      }
      return result;
    }

    final events = <AcademicEvent>[];
    final ids = <String>{};
    for (final row in data['items'] as List) {
      if (row is! Map ||
          row['id'] is! String ||
          (row['id'] as String).isEmpty ||
          !ids.add(row['id'] as String)) {
        throw const FormatException('Invalid SKU event identity');
      }
      if (row['status'] == 'cancelled') continue;
      if (row['status'] != 'confirmed' ||
          row['summary'] is! String ||
          (row['summary'] as String).trim().isEmpty ||
          row['start'] is! Map ||
          row['end'] is! Map) {
        throw const FormatException('Invalid SKU event');
      }
      final start = date(row['start']['date']);
      // Google Calendar date-only end is already exclusive.
      final end = date(row['end']['date']);
      if (!end.isAfter(start) ||
          !start.isBefore(DateTime(year + 1)) ||
          !end.isAfter(DateTime(year))) {
        throw const FormatException('Unexpected SKU event period');
      }
      events.add(
        AcademicEvent(
          sourceId: row['id'],
          title: (row['summary'] as String).trim(),
          start: start,
          end: end,
          url: 'https://www.skuniv.ac.kr/academic-calendar',
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('Incomplete SKU annual schedule');
    }
    return events..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
