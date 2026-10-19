import 'dart:io';

import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/cue_academic_source.dart';
import 'package:daily/core/academic/dnue_academic_source.dart';
import 'package:daily/core/academic/expansion_b_academic_sources.dart';
import 'package:daily/core/academic/kyonggi_academic_source.dart';
import 'package:daily/core/academic/uos_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    File('test/fixtures/academic/$name.html').readAsStringSync();

/// #247: an event's source link keeps the year of the page it was read from.
void main() {
  final cases =
      <
        (
          String name,
          List<AcademicEvent> Function(String body, int year) parse,
          int year,
          String host,
          Map<String, String> query,
        )
      >[
        (
          'uos-2026',
          UosAcademicSource.parse,
          2026,
          'www.uos.ac.kr',
          {
            'list_id': 'CA1',
            'menuid': '2000003003001000000',
            'identified': 'anonymous',
            'year_code': '2026',
          },
        ),
        for (final year in [2025, 2026]) ...[
          (
            'cue-$year',
            CueAcademicSource.parse,
            year,
            'www.cue.ac.kr',
            {'mCode': 'MN052', 'calendar_year': '$year'},
          ),
          (
            'dnue-$year',
            DnueAcademicSource.parse,
            year,
            'www.dnue.ac.kr',
            {'mCode': 'MN119', 'calendar_year': '$year'},
          ),
        ],
        (
          'kyonggi-2026',
          KyonggiAcademicSource.parse,
          2026,
          'www.kyonggi.ac.kr',
          {'key': '5819', 'sc1': '10', 'sc3': '2026'},
        ),
        (
          'hansei-2026',
          HanseiAcademicSource.parse,
          2026,
          'hansei.ac.kr',
          {'no': '10302', 'dateY': '2026', 'dateM': '0', 'tab': 'lst'},
        ),
      ];
  for (final (name, parse, year, host, query) in cases) {
    test('$name source links keep the page year', () {
      final events = parse(fixture(name), year);
      expect(events, isNotEmpty);
      for (final event in events) {
        final url = Uri.parse(event.url);
        expect(url.scheme, 'https');
        expect(url.host, host);
        // Also for a period that started in the previous year.
        expect(url.queryParameters, query, reason: event.title);
      }
    });
  }
}
