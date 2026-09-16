import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saving one setting only materializes that setting and sync metadata',
    () async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      await repository.save(
        repository.load().copyWith(themeMode: AppThemeMode.dark),
      );

      expect(preferences.getKeys(), {
        'onboardingCompleted',
        'themeMode',
        'settingsSyncRevision',
        'settingsSyncPending',
        'settingsSyncDocument.v1',
        'deviceId',
      });
      expect(repository.load().themeMode, AppThemeMode.dark);
      expect(repository.settingsSyncRevision, 1);
      expect(repository.hasPendingSettingsSync, isTrue);

      await repository.save(
        repository.load().copyWith(weekStartsOnMonday: true),
      );

      expect(preferences.getKeys(), {
        'onboardingCompleted',
        'themeMode',
        'weekStartsOnMonday',
        'settingsSyncRevision',
        'settingsSyncPending',
        'settingsSyncDocument.v1',
        'deviceId',
      });
      expect(repository.load().weekStartsOnMonday, isTrue);
      expect(repository.settingsSyncRevision, 2);
    },
  );

  test('saving removes legacy privacy keys only when they exist', () async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'hideSensitiveEvents': true,
      'hideSensitiveNotifications': true,
      'privateEventHidingConfigured': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(repository.load(), markSyncPending: false);

    expect(preferences.getKeys(), {'onboardingCompleted'});
  });

  test(
    'saving migrates legacy text size before removing its old key',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'calendarEventTextSize': 'extraLarge',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      expect(repository.load().appTextSize, AppTextSize.extraLarge);

      await repository.save(
        repository.load().copyWith(themeMode: AppThemeMode.dark),
        markSyncPending: false,
      );

      expect(preferences.getString('calendarEventTextSize'), isNull);
      expect(preferences.getString('appTextSize'), 'extraLarge');
      expect(repository.load().appTextSize, AppTextSize.extraLarge);
    },
  );

  test('saving materializes the legacy single reminder as a list', () async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultReminderMinutes': 10,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(repository.load(), markSyncPending: false);

    expect(preferences.getString('defaultReminderMinutesList'), '[10]');
    expect(repository.load().defaultReminderMinutesList, [10]);
  });

  test(
    'stale setting snapshots only write fields changed by their caller',
    () async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);
      final staleBase = repository.load();

      await repository.save(
        staleBase.copyWith(themeMode: AppThemeMode.dark),
        markSyncPending: false,
        changedFrom: staleBase,
      );
      await repository.save(
        staleBase.copyWith(weekStartsOnMonday: true),
        markSyncPending: false,
        changedFrom: staleBase,
      );

      final restored = repository.load();
      expect(restored.themeMode, AppThemeMode.dark);
      expect(restored.weekStartsOnMonday, isTrue);
    },
  );

  test('global mutation queue merges concurrent changedFrom saves', () async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    final staleBase = repository.load();

    final saves = <Future<void>>[
      repository.save(
        staleBase.copyWith(themeMode: AppThemeMode.dark),
        changedFrom: staleBase,
      ),
      repository.save(
        staleBase.copyWith(monthNavigationMode: MonthNavigationMode.vertical),
        changedFrom: staleBase,
      ),
      repository.save(
        staleBase.copyWith(language: AppLanguage.english),
        changedFrom: staleBase,
      ),
    ];

    await Future.wait(saves);

    final restored = repository.load();
    expect(restored.themeMode, AppThemeMode.dark);
    expect(restored.monthNavigationMode, MonthNavigationMode.vertical);
    expect(restored.language, AppLanguage.english);
    // Language is device-local and must not create a cloud mutation.
    expect(repository.settingsSyncRevision, 2);
    expect(repository.hasPendingSettingsSync, isTrue);
  });

  test('reset removes theme navigation and language preferences', () async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'themeMode': AppThemeMode.dark.name,
      'monthNavigationMode': MonthNavigationMode.vertical.name,
      'language': AppLanguage.english.name,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    expect(repository.load().themeMode, AppThemeMode.dark);
    expect(repository.load().monthNavigationMode, MonthNavigationMode.vertical);
    expect(repository.load().language, AppLanguage.english);

    await repository.resetAll();

    expect(
      preferences.getKeys().intersection(const {
        'themeMode',
        'monthNavigationMode',
        'language',
      }),
      isEmpty,
    );
    final restored = repository.load();
    expect(restored.themeMode, AppThemeMode.system);
    expect(restored.monthNavigationMode, MonthNavigationMode.horizontal);
    expect(restored.language, AppLanguage.system);
  });

  test('reset invalidates delayed settings mutations', () async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    final generation = repository.settingsMutationGeneration;

    await repository.resetAll();

    expect(repository.settingsMutationGeneration, generation + 1);
    expect(repository.load().onboardingCompleted, isFalse);
  });
}
