import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_windows/src/preserving_store_read.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('daily-secure-read-');
    file = File('${directory.path}/store');
    await file.writeAsBytes([1, 2, 3, 4]);
  });
  tearDown(() => directory.delete(recursive: true));
  for (final failure in ['dpapi', 'utf8', 'json', 'array', 'non-string']) {
    test('$failure retains exact ciphertext and successful retry', () async {
      await expectLater(
        readPreservingStore(file, (_) {
          switch (failure) {
            case 'dpapi':
              throw StateError('DPAPI unavailable');
            case 'utf8':
              throw const FormatException('secret', 'secret');
            case 'json':
              return '{invalid';
            case 'array':
              return '[]';
            default:
              return '{"key":1}';
          }
        }),
        throwsA(isA<Object>()),
      );
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      expect(await readPreservingStore(file, (_) => '{"key":"value"}'), {
        'key': 'value',
      });
    });
  }
  test('missing file is empty, other filesystem failure propagates', () async {
    await file.delete();
    expect(
      await readPreservingStore(file, (_) => throw StateError('not called')),
      isEmpty,
    );
    await expectLater(
      readPreservingStore(File(directory.path), (_) => '{}'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await directory.exists(), isTrue);
  });
}
