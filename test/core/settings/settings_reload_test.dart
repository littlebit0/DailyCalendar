import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/auth/apple_account.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// test/widget_test.dart에서 옮긴 SettingsRepository 단위 테스트입니다(#955).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme mode remains selected after settings reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(
      repository.load().copyWith(themeMode: AppThemeMode.dark),
    );

    expect(repository.load().themeMode, AppThemeMode.dark);
    expect(DailyTheme.dark().brightness, Brightness.dark);
    expect(DailyTheme.light().brightness, Brightness.light);
    final darkTheme = DailyTheme.dark();
    expect(darkTheme.scaffoldBackgroundColor, const Color(0xff000000));
    expect(
      darkTheme.colorScheme.surfaceContainerLowest,
      const Color(0xff000000),
    );
    expect(darkTheme.colorScheme.surface, const Color(0xff0a0b0d));
    expect(darkTheme.colorScheme.surfaceContainerHigh, const Color(0xff11141a));
  });

  test(
    'month navigation mode remains selected after settings reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      await repository.save(
        repository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.vertical,
        ),
      );

      expect(
        repository.load().monthNavigationMode,
        MonthNavigationMode.vertical,
      );
    },
  );

  test(
    'week and day layout mode remains selected after settings reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      await repository.save(
        repository.load().copyWith(
          weekDayLayoutMode: WeekDayLayoutMode.schedule,
        ),
      );

      expect(repository.load().weekDayLayoutMode, WeekDayLayoutMode.schedule);
    },
  );

  test('app text size remains selected after settings reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(appTextSize: AppTextSize.extraLarge),
    );

    expect(settingsRepository.load().appTextSize, AppTextSize.extraLarge);
  });

  test(
    'adjacent-month date visibility remains selected after reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);

      await settingsRepository.save(
        settingsRepository.load().copyWith(showAdjacentMonthDates: false),
      );

      expect(settingsRepository.load().showAdjacentMonthDates, isFalse);
    },
  );

  test('legacy default reminder migrates into the reminder list', () async {
    SharedPreferences.setMockInitialValues({'defaultReminderMinutes': 10});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    expect(settingsRepository.load().defaultReminderMinutesList, [10]);
  });

  test('multiple default reminders remain selected after reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(
        defaultReminderMinutesList: const [60, 10, 30, 10],
      ),
    );

    expect(settingsRepository.load().defaultReminderMinutesList, [10, 30, 60]);
  });

  test('empty default reminder list remains disabled after reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(
        defaultReminderMinutesList: const <int>[],
      ),
    );

    expect(settingsRepository.load().defaultReminderMinutesList, isEmpty);
  });

  test('legacy biometric app lock migrates to the system method', () async {
    SharedPreferences.setMockInitialValues({
      'appLockEnabled': true,
      'appLockBiometricsEnabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences: preferences).load();

    expect(settings.appLockMethod, AppLockMethod.system);
  });

  test('selected app lock method remains stored locally', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(
      repository.load().copyWith(
        appLockEnabled: true,
        appLockMethod: AppLockMethod.noPin,
      ),
    );

    expect(repository.load().appLockMethod, AppLockMethod.noPin);
  });

  test('Daily account keeps Apple and Google identities together', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.saveAppleAccount(
      const AppleAccount(
        userIdentifier: 'apple-user',
        email: 'apple@example.com',
      ),
    );
    final accountAfterApple = settingsRepository.dailyAccount();
    await settingsRepository.saveGoogleAccount(
      const GoogleAccount(email: 'google@example.com', displayName: 'Daily'),
    );
    final mergedAccount = settingsRepository.dailyAccount();

    expect(mergedAccount?.id, accountAfterApple?.id);
    expect(mergedAccount?.appleAccount?.userIdentifier, 'apple-user');
    expect(mergedAccount?.googleAccount?.email, 'google@example.com');
  });

  test(
    'Daily account reset removes merged Apple and Google identities',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.saveAppleAccount(
        const AppleAccount(userIdentifier: 'apple-user'),
      );
      await settingsRepository.saveGoogleAccount(
        const GoogleAccount(email: 'google@example.com'),
      );

      await settingsRepository.resetAll();

      expect(settingsRepository.dailyAccount(), isNull);
      expect(settingsRepository.appleAccount(), isNull);
    },
  );
}
