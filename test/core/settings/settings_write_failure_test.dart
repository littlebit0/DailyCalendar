import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/settings_sync_document.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late SharedPreferences preferences;
  late SettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    FlutterSecureStorage.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    repository = SettingsRepository(preferences: preferences);
  });

  Future<SettingsRepository> cold() async {
    await preferences.reload();
    return SettingsRepository(preferences: preferences);
  }

  for (final failure in ['false', 'throw']) {
    test('$failure local write fails and keeps stored value', () async {
      final before = repository.load();
      expect(before.morningBriefingEnabled, isTrue);
      store.failingKeys['flutter.morningBriefingEnabled'] = failure;

      await expectLater(
        repository.save(before.copyWith(morningBriefingEnabled: false)),
        throwsA(isA<Object>()),
      );

      expect(repository.load().morningBriefingEnabled, isTrue);
      final reread = await cold();
      expect(reread.load().morningBriefingEnabled, isTrue);
      expect(reread.hasPendingSettingsSync, isFalse);
      expect(reread.settingsSyncRevision, 0);

      store.failingKeys.clear();
      await repository.save(before.copyWith(morningBriefingEnabled: false));
      expect((await cold()).load().morningBriefingEnabled, isFalse);
    });
  }

  test('partial write registers only the persisted field', () async {
    final before = repository.load();
    store.failingKeys['flutter.morningBriefingEnabled'] = 'false';

    await expectLater(
      repository.save(
        before.copyWith(
          morningBriefingHour: (before.morningBriefingHour + 1) % 24,
          morningBriefingEnabled: false,
        ),
      ),
      throwsA(isA<Object>()),
    );

    final reread = await cold();
    final stored = reread.load();
    expect(stored.morningBriefingHour, (before.morningBriefingHour + 1) % 24);
    expect(stored.morningBriefingEnabled, isTrue);
    expect(reread.hasPendingSettingsSync, isTrue);
    final values = syncSettingsValues(stored);
    expect(reread.settingsSyncDocument().values(values), values);
  });

  test(
    'remote merge write failure is not confirmed and can be retried',
    () async {
      final current = repository.load();
      final remote = const SettingsSyncDocument().recordChanges(
        before: syncSettingsValues(current),
        after: syncSettingsValues(
          current.copyWith(morningBriefingEnabled: false),
        ),
        changedAt: DateTime.now().add(const Duration(minutes: 1)),
        deviceId: 'remote-device',
      );
      AppSettings decode(Map<String, Object?> values, AppSettings base) =>
          base.copyWith(
            morningBriefingEnabled:
                values['morningBriefingEnabled'] as bool? ??
                base.morningBriefingEnabled,
          );
      store.failingKeys['flutter.morningBriefingEnabled'] = 'false';

      await expectLater(
        repository.mergeSettingsSyncDocument(remote, decode),
        throwsA(isA<Object>()),
      );

      final reread = await cold();
      expect(reread.load().morningBriefingEnabled, isTrue);
      expect(
        reread.settingsSyncDocument().values(
          syncSettingsValues(reread.load()),
        )['morningBriefingEnabled'],
        isTrue,
      );

      store.failingKeys.clear();
      expect(
        await repository.mergeSettingsSyncDocument(remote, decode),
        isTrue,
      );
      final applied = await cold();
      expect(applied.load().morningBriefingEnabled, isFalse);
      expect(
        applied.settingsSyncDocument().values(
          syncSettingsValues(applied.load()),
        )['morningBriefingEnabled'],
        isFalse,
      );
    },
  );

  for (final key in [
    'flutter.settingsSyncDocument.v1',
    'flutter.settingsSyncPending',
  ]) {
    test('remote $key failure rolls back and retry reports change', () async {
      final current = repository.load();
      final remote = const SettingsSyncDocument().recordChanges(
        before: syncSettingsValues(current),
        after: syncSettingsValues(
          current.copyWith(themeMode: AppThemeMode.dark),
        ),
        changedAt: DateTime.now().add(const Duration(minutes: 1)),
        deviceId: 'remote-device',
      );
      AppSettings decode(Map<String, Object?> values, AppSettings base) =>
          base.copyWith(
            themeMode: AppThemeMode.values.byName(
              values['themeMode'] as String,
            ),
          );
      store.failingKeys[key] = 'false';

      await expectLater(
        repository.mergeSettingsSyncDocument(remote, decode),
        throwsA(isA<Object>()),
      );
      final reread = await cold();
      expect(reread.load().themeMode, current.themeMode);
      expect(reread.settingsSyncDocument().sameAs(remote), isFalse);

      store.failingKeys.clear();
      expect(
        await repository.mergeSettingsSyncDocument(remote, decode),
        isTrue,
      );
      final applied = await cold();
      expect(applied.load().themeMode, AppThemeMode.dark);
      expect(applied.settingsSyncDocument().sameAs(remote), isTrue);
      expect(applied.hasPendingSettingsSync, isFalse);
    });
  }
}

class _Store extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};
  final failingKeys = <String, String>{};

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final failure = failingKeys[key];
    if (failure == 'throw') throw StateError('disk unavailable');
    if (failure == 'false') return false;
    values[key] = value;
    return true;
  }
}
