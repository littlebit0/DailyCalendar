import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset removes every persisted appearance setting', () async {
    SharedPreferences.setMockInitialValues({
      'themeMode': AppThemeMode.dark.name,
      'monthNavigationMode': MonthNavigationMode.vertical.name,
      'language': AppLanguage.korean.name,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.resetAll();

    final restored = repository.load();
    expect(restored.themeMode, AppThemeMode.system);
    expect(restored.monthNavigationMode, MonthNavigationMode.horizontal);
    expect(restored.language, AppLanguage.system);
    expect(preferences.getString('themeMode'), isNull);
    expect(preferences.getString('monthNavigationMode'), isNull);
    expect(preferences.getString('language'), isNull);
  });

  test('queued local save wins over a stale downloaded snapshot', () async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    final baseline = repository.load();
    final expectedRevision = repository.settingsSyncRevision;
    final expectedGeneration = repository.settingsMutationGeneration;

    final localSave = repository.save(
      baseline.copyWith(themeMode: AppThemeMode.dark),
      changedFrom: baseline,
    );
    var restoreBuilderCalled = false;
    final restoreApplied = repository.applyRestoredSettingsIfUnchanged(
      expectedRevision: expectedRevision,
      expectedMutationGeneration: expectedGeneration,
      buildRestoredSettings: (current) {
        restoreBuilderCalled = true;
        return current.copyWith(weekStartsOnMonday: true);
      },
    );

    await localSave;
    expect(await restoreApplied, isFalse);
    expect(restoreBuilderCalled, isFalse);
    expect(repository.load().themeMode, AppThemeMode.dark);
    expect(repository.load().weekStartsOnMonday, isFalse);
    expect(repository.settingsSyncRevision, 1);
    expect(repository.hasPendingSettingsSync, isTrue);
  });

  test(
    'account reset clears timetable cache without a cloud deletion',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);
      final store = repository.timetableStore;
      await store.save(
        TimetableClass(
          id: 'account-course',
          title: '자료구조',
          academicYear: store.activeYear,
          semester: store.activeSemester,
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await store.renameActive('이번 학기');
      await store.acknowledgeSyncDocument(store.syncDocument());
      var localChanges = 0;
      store.localRevisionNotifier.addListener(() => localChanges++);

      await repository.resetAll();

      expect(store.classes, isEmpty);
      expect(store.activeName, isNull);
      expect(store.hasPendingSync, isFalse);
      expect(store.syncDocument().isEmpty, isTrue);
      expect(preferences.getString(TimetableStore.storageKey), isNull);
      expect(localChanges, 0);
    },
  );

  test('reset generation rejects an older downloaded snapshot', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    final expectedRevision = repository.settingsSyncRevision;
    final expectedGeneration = repository.settingsMutationGeneration;

    final reset = repository.resetAll();
    final restoreApplied = repository.applyRestoredSettingsIfUnchanged(
      expectedRevision: expectedRevision,
      expectedMutationGeneration: expectedGeneration,
      buildRestoredSettings: (current) =>
          current.copyWith(themeMode: AppThemeMode.dark),
    );

    await reset;
    expect(await restoreApplied, isFalse);
    expect(repository.load().themeMode, AppThemeMode.system);
  });

  test('accepted downloaded snapshot keeps sync metadata unchanged', () async {
    SharedPreferences.setMockInitialValues({
      'settingsSyncRevision': 7,
      'language': AppLanguage.korean.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    final applied = await repository.applyRestoredSettingsIfUnchanged(
      expectedRevision: 7,
      expectedMutationGeneration: repository.settingsMutationGeneration,
      buildRestoredSettings: (current) =>
          current.copyWith(weekStartsOnMonday: true),
    );

    expect(applied, isTrue);
    expect(repository.load().weekStartsOnMonday, isTrue);
    expect(repository.load().language, AppLanguage.korean);
    expect(repository.settingsSyncRevision, 7);
    expect(repository.hasPendingSettingsSync, isFalse);
  });
}
