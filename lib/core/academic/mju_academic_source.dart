import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'academic_source.dart';

class MjuAcademicSource implements AcademicSource {
  MjuAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'mju';
  @override
  String get name => '명지대학교';
  @override
  Uri get website => Uri.https('www.mju.ac.kr', '/mjukr/262/subview.do');
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .post(
            Uri.https('www.mju.ac.kr', '/schdulmanage/mjukr/4/yearSchdul.do'),
            body: {'kind': '', 'year': '$selected'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('MJU calendar unavailable');
      }
      for (final event in parse(utf8.decode(response.bodyBytes), selected)) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published MJU calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parse(String body, int year) {
    final document = html.parse(body);
    if (document.querySelector('#year')?.attributes['value'] != '$year') {
      throw const FormatException('Unexpected MJU year');
    }
    final months = <int>{};
    final events = <String, AcademicEvent>{};
    for (final group in document.querySelectorAll('dl')) {
      final label = group.querySelector('dt > strong')?.text.trim();
      if (label == null) continue;
      final monthMatch = RegExp(r'^(\d{2})월$').firstMatch(label);
      if (monthMatch == null) continue;
      final month = int.parse(monthMatch[1]!);
      if (month < 1 || month > 12 || !months.add(month)) {
        throw const FormatException('Invalid MJU month');
      }
      for (final row in group.querySelectorAll('.text-list > li')) {
        final strong = row.querySelector('strong');
        if (strong == null) throw const FormatException('Missing MJU dates');
        final matches = RegExp(
          r'\.(\d{2})\s*\.(\d{2})',
        ).allMatches(strong.text).toList();
        if (matches.length != 2) {
          throw const FormatException('Invalid MJU dates');
        }
        DateTime date(RegExpMatch m, int y) {
          final mm = int.parse(m[1]!);
          final dd = int.parse(m[2]!);
          final result = DateTime(y, mm, dd);
          if (result.year != y || result.month != mm || result.day != dd) {
            throw const FormatException('Invalid MJU date');
          }
          return result;
        }

        final startMonth = int.parse(matches.first[1]!);
        final start = date(matches.first, startMonth > month ? year - 1 : year);
        final last = date(
          matches.last,
          int.parse(matches.last[1]!) < startMonth
              ? start.year + 1
              : start.year,
        );
        final end = DateTime(last.year, last.month, last.day + 1);
        if (last.isBefore(start) ||
            !start.isBefore(DateTime(year, month + 1)) ||
            !end.isAfter(DateTime(year, month))) {
          throw const FormatException('Unexpected MJU period');
        }
        strong.remove();
        final text = row.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isEmpty) throw const FormatException('Empty MJU title');
        final labelled = RegExp(
          r'\[([^\]]+)\]\s*([^\[]+)',
        ).allMatches(text).toList();
        final titles = labelled.isEmpty
            ? [text]
            : [
                for (final part in labelled)
                  if (part[1]!.replaceAll(' ', '').contains('학부'))
                    '[${part[1]!.replaceAll(' ', '')}] ${part[2]!.trim()}',
              ];
        for (final title in titles) {
          final identity =
              '${start.toIso8601String()}:${last.toIso8601String()}:$title';
          events[identity] = AcademicEvent(
            sourceId: identity,
            title: title,
            start: start,
            end: end,
            url: 'https://www.mju.ac.kr/mjukr/262/subview.do',
          );
        }
      }
    }
    if (months.length != 12 || events.isEmpty) {
      throw const FormatException('Incomplete MJU calendar');
    }
    return events.values.toList();
  }

  @override
  void close() => _client.close();
}
