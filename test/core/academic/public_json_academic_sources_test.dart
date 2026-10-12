import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final postech = File(
    'test/fixtures/academic/postech-2026.json',
  ).readAsStringSync();
  final sejong = File(
    'test/fixtures/academic/sejong-2026.json',
  ).readAsStringSync();
  test(
    'POSTECH preserves Korean date-only timestamps and stable published IDs',
    () {
      final events = PostechAcademicSource.parse(postech, 2026);
      expect(events, hasLength(81));
      final newYear = events.singleWhere((e) => e.title == '신정 (공휴일)');
      expect(newYear.start, DateTime(2026, 1, 1));
      expect(newYear.end, DateTime(2026, 1, 2));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final json = jsonDecode(postech) as Map<String, dynamic>;
      final first = (json['data'] as List).first as Map;
      (json['data'] as List).add({...first, 'content': 'Conflicting title'});
      expect(
        () => PostechAcademicSource.parse(jsonEncode(json), 2026),
        throwsFormatException,
      );
    },
  );
  test(
    'Sejong imports undergraduate calendar and rejects impossible dates',
    () {
      final events = SejongAcademicSource.parse(sejong, 2026);
      expect(events, hasLength(44));
      final opening = events.singleWhere((e) => e.title == '2학기 개강');
      expect(opening.start, DateTime(2026, 9, 1));
      expect(opening.end, DateTime(2026, 9, 2));
      final json = jsonDecode(sejong) as Map<String, dynamic>;
      final first = (json['data'] as List).first as Map;
      (json['data'] as List).add({
        ...first,
        'collDiv': '0002',
        'scmSubject': 'Graduate only',
      });
      expect(SejongAcademicSource.parse(jsonEncode(json), 2026), hasLength(44));
      first['frDt'] = '2026-02-30';
      expect(
        () => SejongAcademicSource.parse(jsonEncode(json), 2026),
        throwsFormatException,
      );
    },
  );
  test(
    'error pages and unpublished years cannot become empty successful imports',
    () {
      expect(
        () => PostechAcademicSource.parse('{}', 2026),
        throwsFormatException,
      );
      expect(
        () => SejongAcademicSource.parse('{"data":[]}', 2026),
        throwsFormatException,
      );
    },
  );
}
