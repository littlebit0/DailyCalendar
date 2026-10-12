import 'dart:io';
import 'dart:typed_data';

import 'package:daily/core/academic/kangnam_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kangnam parses actual annual PDF columns and cross-year ranges', () {
    final bytes = File(
      'test/fixtures/kangnam/2026-calendar.pdf',
    ).readAsBytesSync();
    final events = KangnamAcademicSource.parsePdf(bytes, 2026);
    final opening = events.singleWhere(
      (e) => e.title.replaceAll(' ', '') == '2학기개강일',
    );
    expect(opening.start, DateTime(2026, 9, 1));
    expect(opening.end, DateTime(2026, 9, 2));
    final winter = events.singleWhere(
      (e) => e.title.replaceAll(' ', '') == '동계계절수업기간',
    );
    expect(winter.start, DateTime(2026, 12, 17));
    expect(winter.end, DateTime(2027, 1, 9));
    // The separately published current calendar has January 19–20, while
    // the other whole-course book contains an older January 12–13 revision.
    final preregistration = events.singleWhere(
      (e) => e.title.contains('예비수강신청') && e.start.year == 2027,
    );
    expect(preregistration.start, DateTime(2027, 1, 19));
    expect(preregistration.end, DateTime(2027, 1, 21));
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
    expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    expect(
      () => KangnamAcademicSource.parsePdf(bytes, 2025),
      throwsFormatException,
    );
  });

  test('Kangnam rejects an HTML download error rather than importing it', () {
    expect(
      () => KangnamAcademicSource.parsePdf(
        Uint8List.fromList('<html>error</html>'.codeUnits),
        2026,
      ),
      throwsFormatException,
    );
  });
}
