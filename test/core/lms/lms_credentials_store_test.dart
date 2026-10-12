import 'dart:io';
import 'package:daily/core/lms/lms_credentials_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('local secrets are owner/school scoped and redacted', () async {
    final store = LmsCredentialsStore();
    await store.save(
      'USER@example.com',
      'smu',
      const LmsLocalCredentials('student', 'secret fixture'),
    );
    expect(
      (await store.read(' user@example.com ', 'smu'))!.username,
      'student',
    );
    expect(await store.read('other@example.com', 'smu'), isNull);
    expect(await store.read('user@example.com', 'jnu'), isNull);
    expect(
      (await store.read('user@example.com', 'smu')).toString(),
      isNot(contains('secret fixture')),
    );
    await store.delete('user@example.com', 'smu');
    expect(await store.read('user@example.com', 'smu'), isNull);
  });
  test(
    'Android cloud backup and device transfer exclude only local credential namespace',
    () {
      for (final file in [
        'daily_backup_rules.xml',
        'daily_data_extraction_rules.xml',
      ]) {
        final xml = File(
          'android/app/src/main/res/xml/$file',
        ).readAsStringSync();
        expect(xml, contains('daily_lms_credentials.xml'));
        expect(
          xml,
          contains('FlutterSecureKeyStorage:daily_lms_credentials.xml'),
        );
      }
      final source = File(
        'lib/core/lms/lms_credentials_store.dart',
      ).readAsStringSync();
      expect(source, contains('unlocked_this_device'));
      expect(source, contains('synchronizable: false'));
    },
  );
}
