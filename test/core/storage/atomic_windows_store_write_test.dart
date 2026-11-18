import 'dart:io';

import 'package:flutter_secure_storage_windows/src/atomic_file_write.dart';
import 'package:flutter_secure_storage_windows/src/preserving_store_read.dart';
import 'package:flutter_test/flutter_test.dart';

// #934: the store was overwritten in place, so a write cut short left a
// truncated file that failed to decrypt on every later start.
void main() {
  late Directory directory;
  late File file;
  // Stands in for DPAPI: the "ciphertext" is the JSON text itself.
  Future<Map<String, String>> read() =>
      readPreservingStore(file, String.fromCharCodes);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('daily-secure-write-');
    file = File('${directory.path}/nested/store.dat');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'creates the folder, replaces the file and leaves no temporary file',
    () async {
      await writeFileAtomically(file, '{"pin":"old"}'.codeUnits);
      expect(await read(), {'pin': 'old'});
      await writeFileAtomically(file, '{"pin":"new"}'.codeUnits);
      expect(await read(), {'pin': 'new'});
      expect(await file.parent.list().length, 1);
    },
  );

  test(
    'a write cut short before the replace keeps the previous store',
    () async {
      await writeFileAtomically(file, '{"pin":"old"}'.codeUnits);
      // What an interrupted write leaves behind: a partial temporary file.
      await File('${file.path}.tmp').writeAsBytes('{"pin":"n'.codeUnits);

      expect(await read(), {'pin': 'old'});
      await writeFileAtomically(file, '{"pin":"new"}'.codeUnits);
      expect(await read(), {'pin': 'new'});
      expect(await File('${file.path}.tmp').exists(), isFalse);
    },
  );

  test('a failed write leaves the previous store untouched', () async {
    await writeFileAtomically(file, '{"pin":"old"}'.codeUnits);
    // The temporary path cannot be written while a folder holds its name.
    await Directory('${file.path}.tmp').create();

    await expectLater(
      writeFileAtomically(file, '{"pin":"new"}'.codeUnits),
      throwsA(isA<FileSystemException>()),
    );
    expect(await read(), {'pin': 'old'});
  });
}
