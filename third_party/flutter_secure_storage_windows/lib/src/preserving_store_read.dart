import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Read failures never authorize deleting or silently replacing credentials.
Future<Map<String, String>> readPreservingStore(
  File file,
  String Function(Uint8List) decrypt,
) async {
  final Uint8List encrypted;
  try {
    encrypted = await file.readAsBytes();
  } on FileSystemException catch (error) {
    // Windows ERROR_FILE_NOT_FOUND / ERROR_PATH_NOT_FOUND only.
    if (error.osError?.errorCode == 2 || error.osError?.errorCode == 3) {
      return {};
    }
    rethrow;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(decrypt(encrypted));
  } on FormatException {
    // Do not expose plaintext through FormatException.source or log messages.
    throw const FormatException(
        'Invalid secure-storage encoding. Original retained.');
  }
  if (decoded is! Map ||
      decoded.entries.any((e) => e.key is! String || e.value is! String)) {
    throw const FormatException(
        'Invalid secure-storage object. Original retained.');
  }
  return Map<String, String>.from(decoded);
}
