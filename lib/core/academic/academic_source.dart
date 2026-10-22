import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AcademicEvent {
  const AcademicEvent({
    required this.sourceId,
    required this.title,
    required this.start,
    required this.end,
    required this.url,
  });

  final String sourceId;
  final String title;
  final DateTime start;
  final DateTime end; // Exclusive, date-only end, as in CalendarEvent.
  final String url;

  String dailyId(String universityId) {
    final hash = sha256
        .convert(utf8.encode('daily-academic-v1:$universityId:$sourceId'))
        .toString();
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-'
        '${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}';
  }

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'url': url,
  };

  factory AcademicEvent.fromJson(Map<String, dynamic> json) => AcademicEvent(
    sourceId: json['sourceId'] as String,
    title: json['title'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    url: json['url'] as String,
  );
}

abstract interface class AcademicSource {
  String get id;
  String get name;
  Uri get website;
  Future<List<AcademicEvent>> fetch(int year);
  void close();
}

/// One published date range; [last] is the inclusive final day.
typedef AcademicCalendarRecord = ({
  String title,
  DateTime start,
  DateTime last,
});

/// Rejects failed or oversized responses before parsing.
void checkAcademicResponse(http.Response response) {
  if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
    throw const FormatException('Academic source unavailable');
  }
}

/// Builds date-only events for [year] with stable title/occurrence IDs.
List<AcademicEvent> academicCalendarEvents(
  List<AcademicCalendarRecord> records,
  int year,
  String url,
) {
  records.sort((a, b) {
    final order = a.start.compareTo(b.start);
    return order != 0 ? order : a.title.compareTo(b.title);
  });
  final identities = <String, int>{};
  final seen = <String>{};
  final result = <AcademicEvent>[];
  for (final record in records) {
    if (record.last.isBefore(record.start)) {
      throw const FormatException('Invalid academic period');
    }
    final end = DateTime(
      record.last.year,
      record.last.month,
      record.last.day + 1,
    );
    if (!record.start.isBefore(DateTime(year + 1)) ||
        !end.isAfter(DateTime(year))) {
      continue;
    }
    final signature =
        '${record.title}:${record.start.toIso8601String()}:${record.last.toIso8601String()}';
    if (!seen.add(signature)) {
      continue; // Some feeds repeat the same row.
    }
    // Neither public source supplies stable event IDs. Titles, start-year and
    // occurrence order keep date-only corrections on an existing imported event.
    final titleHash = sha256.convert(utf8.encode(record.title)).toString();
    final identity = '${record.start.year}:$titleHash';
    final occurrence = identities.update(
      identity,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    result.add(
      AcademicEvent(
        sourceId: '$identity:$occurrence',
        title: record.title,
        start: record.start,
        end: end,
        url: url,
      ),
    );
  }
  if (result.isEmpty) {
    throw const FormatException('No published academic calendar');
  }
  return result;
}

/// Converts a small HTML fragment to plain text.
String academicHtmlText(String value) => value
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAllMapped(RegExp(r'&#([xX][0-9a-fA-F]+|\d+);'), (match) {
      final encoded = match.group(1)!;
      final code = encoded.toLowerCase().startsWith('x')
          ? int.parse(encoded.substring(1), radix: 16)
          : int.parse(encoded);
      if (code <= 0 || code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff)) {
        throw const FormatException('Invalid HTML character');
      }
      return String.fromCharCode(code);
    })
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .trim();
