import 'dart:io';

import 'package:daily/core/academic/ut_academic_source.dart';
import 'package:daily/core/academic/kookmin_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'UT fetches every month sequentially and deduplicates published IDs',
    () async {
      final months = <int>[];
      var active = false;
      final source = UtAcademicSource(
        client: MockClient((request) async {
          expect(active, isFalse);
          active = true;
          final date = Uri.splitQueryString(request.body)['rdate']!;
          months.add(int.parse(date.substring(5)));
          await Future<void>.delayed(const Duration(milliseconds: 1));
          active = false;
          return http.Response(
            File('test/fixtures/academic/ut-$date.json').readAsStringSync(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(months, List.generate(12, (i) => i + 1));
      expect(events.length, 44);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(
        () => UtAcademicSource.parse(
          File('test/fixtures/academic/ut-2026-03.json').readAsStringSync(),
          2025,
          3,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'Kookmin retains next January winter class period and preceding January',
    () async {
      final source = KookminAcademicSource(
        client: MockClient((request) async {
          final year = request.url.queryParameters['yyyy'];
          return http.Response(
            File(
              'test/fixtures/academic/kookmin-$year.html',
            ).readAsStringSync(),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(events.length, 62);
      final winter = events.singleWhere(
        (e) => e.title == '동계 계절학기 수업 기간' && e.start.year == 2026,
      );
      expect(winter.start, DateTime(2026, 12, 22));
      expect(winter.end, DateTime(2027, 1, 14));
      expect(events.any((e) => e.start.month == 1), isTrue);
      expect(
        () => KookminAcademicSource.parse(
          File('test/fixtures/academic/kookmin-2026.html').readAsStringSync(),
          2025,
        ),
        throwsFormatException,
      );
    },
  );
}
