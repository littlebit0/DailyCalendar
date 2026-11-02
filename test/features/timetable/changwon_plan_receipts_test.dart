import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every current plan receipt resolves to preserved original bytes', () {
    final asset =
        jsonDecode(
              File(
                'assets/timetable/changwon-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    var checked = 0;
    for (final course in asset['courses'] as List) {
      final receipt = course['sourceEducation']?['currentPublicPlanReceipt'];
      final logical = receipt?['sourceFile'] as String?;
      if (logical == null || !logical.contains('/plans/')) continue;
      // The logical name keeps the original provenance; the bytes live in the
      // frozen fixture directory and must still hash to the receipt.
      final file = File(
        'test/fixtures/changwon_plans/${logical.split('/').last}',
      );
      expect(file.existsSync(), isTrue, reason: logical);
      final bytes = file.readAsBytesSync();
      expect(
        sha256.convert(bytes).toString(),
        receipt['sha256'],
        reason: logical,
      );
      final plan = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(plan['code'], course['courseCode'], reason: logical);
      expect(plan['section'], course['section'], reason: logical);
      expect(plan['sourceURL'], receipt['sourceURL'], reason: logical);
      checked++;
    }
    // The 24 courses refreshed on 2026-10-23.
    expect(checked, 24);
    expect(
      Directory(
        'test/fixtures/changwon_plans',
      ).listSync().whereType<File>().length,
      24,
    );
  });
}
