import 'dart:io';

import 'package:daily/core/academic/expansion_b_academic_sources.dart';
import 'package:flutter_test/flutter_test.dart';

String academic(String name) =>
    File('test/fixtures/academic/$name').readAsStringSync();

void main() {
  group('K2Web schools', () {
    final heading = RegExp(r'<h3>\s*(?:<em>)?4(?:</em>)?\s*월[^<]*</h3>');
    for (final entry in {
      'hyupsung': (HyupsungAcademicSource.new, 'hyupsung-2026.html'),
      'sungkyul': (SungkyulAcademicSource.new, 'sungkyul-2026.html'),
    }.entries) {
      final (create, file) = entry.value;
      test('${entry.key}: a missing or repeated month heading is rejected', () {
        final source = create();
        addTearDown(source.close);
        final body = academic(file);
        expect(heading.allMatches(body), hasLength(1));
        expect(
          () => source.parse(body.replaceFirst(heading, ''), 2026),
          throwsFormatException,
        );
        final repeated = heading.firstMatch(body)!.group(0)!;
        expect(
          () => source.parse(body.replaceFirst(heading, repeated * 2), 2026),
          throwsFormatException,
        );
      });
    }

    test('a real response with empty months (live 2027 page) is accepted', () {
      final source = SungkyulAcademicSource();
      addTearDown(source.close);
      final rows = source.parse(academic('sungkyul-2027-partial.html'), 2027);
      expect(rows, isNotEmpty);
      expect(rows.every((row) => row.start.month <= 2), isTrue);
    });

    test('an all-empty year (live 2019 page) is not a structure error', () {
      final source = HyupsungAcademicSource();
      addTearDown(source.close);
      // Twelve empty sections pass the structure check; the existing
      // "nothing published" rule then reports the empty year.
      expect(
        () => source.parse(academic('hyupsung-2019-empty.html'), 2019),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'No published academic year',
          ),
        ),
      );
    });
  });
}
