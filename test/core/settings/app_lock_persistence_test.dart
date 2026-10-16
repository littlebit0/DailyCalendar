import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late SettingsRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    FlutterSecureStorage.setMockInitialValues({});
    repository = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await repository.saveAppLockPin('1234');
  });

  for (final failure in ['false', 'throw', 'unwritten']) {
    test(
      '$failure lock write retains persisted lock and PIN; retry succeeds',
      () async {
        final old = repository.load();
        expect(old.appLockEnabled, isTrue);
        expect(old.appLockMethod, AppLockMethod.appPin);
        store.failure = failure;
        await expectLater(
          repository.save(
            old.copyWith(
              appLockEnabled: false,
              appLockMethod: AppLockMethod.noPin,
            ),
            markSyncPending: false,
          ),
          throwsA(isA<Object>()),
        );
        expect(repository.load().appLockEnabled, isTrue);
        expect(repository.load().appLockMethod, AppLockMethod.appPin);
        expect(await repository.verifyAppLockPin('1234'), isTrue);
        store.failure = null;
        await repository.save(
          old.copyWith(
            appLockEnabled: false,
            appLockMethod: AppLockMethod.noPin,
          ),
          markSyncPending: false,
        );
        expect(repository.load().appLockEnabled, isFalse);
        expect(repository.load().appLockMethod, AppLockMethod.noPin);
        final cold = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        expect(cold.load().appLockEnabled, isFalse);
        expect(cold.load().appLockMethod, AppLockMethod.noPin);
      },
    );
  }

  test(
    'stale unrelated save does not replace atomic lock configuration',
    () async {
      final before = repository.load();
      await repository.save(
        before.copyWith(appLockMethod: AppLockMethod.system),
        changedFrom: before,
        markSyncPending: false,
      );
      await repository.save(
        before.copyWith(themeMode: AppThemeMode.dark),
        changedFrom: before,
        markSyncPending: false,
      );
      expect(repository.load().appLockMethod, AppLockMethod.system);
      expect(repository.load().themeMode, AppThemeMode.dark);
    },
  );

  test(
    'malformed new snapshot fails closed instead of using disabled legacy value',
    () async {
      store.values['flutter.appLockConfiguration.v1'] = '{}';
      store.values['flutter.appLockEnabled'] = false;
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      expect(repository.load().appLockEnabled, isTrue);
    },
  );
}

class _Store extends SharedPreferencesStorePlatform {
  final values = <String, Object>{
    'flutter.appLockEnabled': true,
    'flutter.appLockMethod': 'appPin',
    'flutter.appLockBiometricsEnabled': false,
  };
  String? failure;
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
    if (key == 'flutter.appLockConfiguration.v1') {
      if (failure == 'throw') throw StateError('disk unavailable');
      if (failure == 'false') return false;
      if (failure == 'unwritten') return true;
    }
    values[key] = value;
    return true;
  }
}
