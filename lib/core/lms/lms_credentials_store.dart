import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Never serialized into settings, events, diagnostics or Drive payloads.
class LmsLocalCredentials {
  const LmsLocalCredentials(
    this.username,
    this.password, {
    this.paused = false,
  });
  final String username;
  final String password;
  final bool paused;
  @override
  String toString() => 'LmsLocalCredentials(redacted)';
}

class LmsCredentialsStore {
  LmsCredentialsStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'daily_lms_credentials'),
            iOptions: IOSOptions(
              synchronizable: false,
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            mOptions: MacOsOptions(
              synchronizable: false,
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  String _key(String owner, String school) =>
      'daily.lms.credentials.v1.${sha256.convert(utf8.encode('${owner.trim().toLowerCase()}\n$school'))}';
  Future<LmsLocalCredentials?> read(String owner, String school) async {
    final raw = await _storage.read(key: _key(owner, school));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['username'] is! String ||
          data['password'] is! String ||
          (data['username'] as String).isEmpty ||
          (data['password'] as String).isEmpty) {
        return null;
      }
      return LmsLocalCredentials(
        data['username'],
        data['password'],
        paused: data['paused'] == true,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> save(
    String owner,
    String school,
    LmsLocalCredentials value,
  ) async {
    if (owner.trim().isEmpty ||
        school != 'smu' ||
        value.username.trim().isEmpty ||
        value.password.isEmpty) {
      throw ArgumentError('Invalid local LMS credential configuration');
    }
    await _storage.write(
      key: _key(owner, school),
      value: jsonEncode({
        'username': value.username.trim(),
        'password': value.password,
        'paused': value.paused,
      }),
    );
  }

  Future<void> delete(String owner, String school) =>
      _storage.delete(key: _key(owner, school));
}
