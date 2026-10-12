import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/bnue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final body = File('test/fixtures/academic/bnue-2026.json').readAsStringSync();
  test(
    'BNUE requests all annual events regardless of selected month metadata',
    () async {
      final source = BnueAcademicSource(
        client: MockClient((request) async {
          expect(request.url.queryParameters, {
            'year': '2026',
            'month': '',
            'viewType': 'yearly',
          });
          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(events.length, 48);
      expect(events.first.start.month, 1);
      expect(events.last.start.month, 12);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final registration = events.singleWhere((e) => e.sourceId == '765');
      expect(registration.start, DateTime(2026, 2, 3));
      expect(registration.end, DateTime(2026, 2, 6));
    },
  );
  test('BNUE rejects another calendar, bad dates and conflicting identity', () {
    expect(() => BnueAcademicSource.parse(body, 2025), throwsFormatException);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final rows = data['dataList'] as List;
    rows.add({...rows.first as Map, 'schedule': 'conflicting title'});
    expect(
      () => BnueAcademicSource.parse(jsonEncode(data), 2026),
      throwsFormatException,
    );
    expect(
      () => BnueAcademicSource.parse(
        body.replaceFirst('2026-01-01', '2026-01-32'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => BnueAcademicSource.parse(
        body.replaceFirst('CALENDAR_000004', 'CALENDAR_000005'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
