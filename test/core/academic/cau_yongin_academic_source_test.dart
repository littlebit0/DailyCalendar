import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/cau_academic_source.dart';
import 'package:daily/core/academic/yongin_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'CAU recurring holidays use displayed date fields rather than old epochs',
    () {
      final body = File(
        'test/fixtures/academic/cau-2026.json',
      ).readAsStringSync();
      final events = CauAcademicSource.parse(body, 2026);
      expect(events.length, 82);
      final holiday = events.singleWhere((e) => e.title == '신정(공휴일)');
      expect(holiday.start, DateTime(2026, 1, 1));
      expect(holiday.end, DateTime(2026, 1, 2));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final invalid = jsonDecode(body) as Map<String, dynamic>;
      invalid['data'][0]['START_D'] = '32';
      expect(
        () => CauAcademicSource.parse(jsonEncode(invalid), 2026),
        throwsFormatException,
      );
      expect(() => CauAcademicSource.parse(body, 2025), throwsFormatException);
    },
  );

  test('CAU row order does not change same-title identities', () {
    final body = File(
      'test/fixtures/academic/cau-2026.json',
    ).readAsStringSync();
    String key(AcademicEvent e) => '${e.title}|${e.start}|${e.end}';
    final original = {
      for (final e in CauAcademicSource.parse(body, 2026)) key(e): e.sourceId,
    };
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    decoded['data'] = (decoded['data'] as List).reversed.toList();
    final reordered = CauAcademicSource.parse(jsonEncode(decoded), 2026);
    expect(
      reordered.map((e) => e.sourceId).toSet(),
      hasLength(reordered.length),
    );
    for (final e in reordered) {
      expect(e.sourceId, original[key(e)], reason: key(e));
    }
    expect(
      original.values.where((id) => id.endsWith(':1')),
      isNotEmpty,
      reason: 'fixture must contain same-title rows',
    );
  });

  test(
    'Yongin uses current January and February and recognises empty months',
    () async {
      final requests = <int>[];
      final source = YonginAcademicSource(
        client: MockClient((request) async {
          final year = int.parse(
            Uri.splitQueryString(request.body)['srchYear']!,
          );
          requests.add(year);
          return http.Response(
            File('test/fixtures/academic/yongin-$year.html').readAsStringSync(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(requests, [2025, 2026]);
      expect(events.length, 48);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final january = events.singleWhere(
        (e) => e.title == '복학 신청기간' && e.start.month == 1,
      );
      expect(january.start, DateTime(2026, 1, 5));
      expect(january.end, DateTime(2026, 2, 27));
      final body = File(
        'test/fixtures/academic/yongin-2026.html',
      ).readAsStringSync();
      expect(
        () => YonginAcademicSource.parse(body, 2025),
        throwsFormatException,
      );
      expect(
        () => YonginAcademicSource.parse(
          body.replaceFirst('01.05(월)', '01.32(월)'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
}
