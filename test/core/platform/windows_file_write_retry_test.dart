import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_windows/src/file_write_retry.dart';

void main() {
  for (final code in [5, 112, 999, null]) {
    test('permanent file error $code returns after one attempt', () async {
      var calls = 0;
      final error = FileSystemException(
        'fixture',
        '',
        code == null ? null : OSError('fixture', code),
      );
      await expectLater(
        retryTransientFileWrite(() async {
          calls++;
          throw error;
        }),
        throwsA(same(error)),
      );
      expect(calls, 1);
    });
  }
  for (final code in [2, 3, 32, 33]) {
    test('transient error $code recovers and is bounded', () async {
      var calls = 0;
      final error = FileSystemException(
        'fixture',
        '',
        OSError('fixture', code),
      );
      await retryTransientFileWrite(() async {
        if (++calls < 3) throw error;
      });
      expect(calls, 3);
      calls = 0;
      await expectLater(
        retryTransientFileWrite(() async {
          calls++;
          throw error;
        }),
        throwsA(same(error)),
      );
      expect(calls, 4);
      await retryTransientFileWrite(() async {
        calls++;
      });
      expect(calls, 5);
    });
  }
  test('non-filesystem failures propagate without retry', () async {
    var calls = 0;
    await expectLater(
      retryTransientFileWrite(() async {
        calls++;
        throw StateError('fixture');
      }),
      throwsStateError,
    );
    expect(calls, 1);
  });
}
