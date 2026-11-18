import 'dart:io';

/// Writes [bytes] to a sibling temporary file, flushes it and renames it over
/// [file]. An interrupted write then leaves the previous file whole instead of
/// a truncated one that can never be decrypted. A leftover temporary file is
/// overwritten by the next write and is never read.
Future<void> writeFileAtomically(File file, List<int> bytes) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsBytes(bytes, flush: true);
  for (var attempt = 0;; attempt++) {
    try {
      // Replaces an existing file (MoveFileExW with MOVEFILE_REPLACE_EXISTING).
      await temporary.rename(file.path);
      return;
    } on FileSystemException catch (error) {
      // Windows reports access denied (5) while another process, such as a
      // scanner, holds the target open; the in-place write waited this out too.
      if (attempt >= 3 || error.osError?.errorCode != 5) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 25 * (1 << attempt)));
    }
  }
}
