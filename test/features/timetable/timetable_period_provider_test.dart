import 'dart:async';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

final _now = DateTime.utc(2026, 9, 25);
final _fall = TimetablePeriod(
  start: DateTime(2026, 9, 1),
  end: DateTime(2026, 12, 21),
);

class _FileBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _PausingPreferences extends InMemorySharedPreferencesStore {
  _PausingPreferences() : super.empty();
  Completer<void>? started;
  Completer<void>? resume;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final pause = resume;
    if (pause != null) {
      resume = null;
      started?.complete();
      await pause.future;
    }
    return super.setValue(type, key, value);
  }
}

TimetableClass _course(String id, {int year = 2026, String semester = '2'}) =>
    TimetableClass(
      id: id,
      title: '자료구조',
      academicYear: year,
      semester: semester,
      meetings: const [
        ClassMeeting(id: 'mon', weekday: 1, startMinute: 540, endMinute: 600),
      ],
    );

Future<SettingsRepository> _settings() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsRepository(
    preferences: await SharedPreferences.getInstance(),
    now: () => _now,
  );
}

Future<TimetablePeriodDefaults> _defaults() =>
    TimetablePeriodDefaults.load(bundle: _FileBundle());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supportedProfiles = {
    'dku': AcademicProfile(
      universityId: 'institution:academyinfo:0000082',
      universityName: '단국대학교',
      schoolKind: 'fourYear',
    ),
    'jnu': AcademicProfile(
      universityId: 'institution:academyinfo:0000023',
      universityName: '전남대학교',
      schoolKind: 'fourYear',
    ),
  };
  final officialPeriods = {
    'dku': {
      '1': TimetablePeriod(
        start: DateTime(2026, 3, 3),
        end: DateTime(2026, 6, 19),
      ),
      '여름': TimetablePeriod(
        start: DateTime(2026, 6, 23),
        end: DateTime(2026, 7, 13),
      ),
      '2': _fall,
      '겨울': TimetablePeriod(
        start: DateTime(2026, 12, 23),
        end: DateTime(2027, 1, 14),
      ),
    },
    'jnu': {
      '1': TimetablePeriod(
        start: DateTime(2026, 3, 3),
        end: DateTime(2026, 6, 23),
      ),
      '여름': TimetablePeriod(
        start: DateTime(2026, 6, 29),
        end: DateTime(2026, 7, 23),
      ),
      '2': _fall,
      '겨울': TimetablePeriod(
        start: DateTime(2026, 12, 28),
        end: DateTime(2027, 1, 22),
      ),
    },
  };

  for (final entry in supportedProfiles.entries) {
    test(
      '${entry.key} profile seeds all four official term periods for new courses',
      () async {
        final settings = await _settings();
        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            appSettingsProvider.overrideWith(
              (ref) => settings.load().copyWith(academicProfile: entry.value),
            ),
          ],
        );
        addTearDown(container.dispose);
        final store = container.read(timetableStoreProvider);
        await container.read(timetablePeriodPreparationProvider.future);
        expect(store.terms, isEmpty);
        expect(store.hasPendingSync, isFalse);
        for (final period in officialPeriods[entry.key]!.entries) {
          await store.save(_course(period.key, semester: period.key));
          expect(store.periodFor(2026, period.key), period.value);
          expect(
            store
                .syncDocument()
                .termPeriods[timetableTermSyncKey(2026, period.key)]!
                .changedAt,
            isNull,
          );
        }
        await store.save(_course('unknown', year: 2027));
        expect(store.periodFor(2027, '2'), isNull);
        final reloaded = TimetableStore(await SharedPreferences.getInstance());
        for (final period in officialPeriods[entry.key]!.entries) {
          expect(reloaded.periodFor(2026, period.key), period.value);
        }
      },
    );

    test(
      '${entry.key} restored profile wins while period defaults are still loading',
      () async {
        final settings = await _settings();
        await settings.timetableStore.save(_course('restored', semester: '여름'));
        final completer = Completer<TimetablePeriodDefaults>();
        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            timetablePeriodDefaultsProvider.overrideWith(
              (ref) => completer.future,
            ),
          ],
        );
        addTearDown(container.dispose);
        final store = container.read(timetableStoreProvider);
        expect(store.periodFor(2026, '여름'), isNull);
        container.read(appSettingsProvider.notifier).state = settings
            .load()
            .copyWith(academicProfile: entry.value);
        final preparation = container.read(
          timetablePeriodPreparationProvider.future,
        );
        completer.complete(await _defaults());
        await preparation;
        expect(store.periodFor(2026, '여름'), officialPeriods[entry.key]!['여름']);
        await store.save(_course('new-term', semester: '겨울'));
        expect(store.periodFor(2026, '겨울'), officialPeriods[entry.key]!['겨울']);
      },
    );
  }

  test(
    'changing university preserves stored legacy and user periods while new terms use the new profile',
    () async {
      final settings = await _settings();
      final store = settings.timetableStore;
      final legacyPeriod = TimetablePeriod(
        start: DateTime(2026, 6, 24),
        end: DateTime(2026, 7, 9),
      );
      final userPeriod = TimetablePeriod(
        start: DateTime(2026, 3, 2),
        end: DateTime(2026, 6, 20),
      );
      await store.mergeSyncDocument(
        TimetableSyncDocument.legacy(
          courses: [_course('legacy', semester: '여름')],
          termNames: {},
          termPeriods: {
            2026: {'여름': legacyPeriod},
          },
          activeYear: 2026,
          activeSemester: '여름',
        ),
      );
      await store.setTermPeriod(2026, '1', userPeriod);
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          appSettingsProvider.overrideWith(
            (ref) => settings.load().copyWith(
              academicProfile: supportedProfiles['dku'],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(timetableStoreProvider);
      await container.read(timetablePeriodPreparationProvider.future);
      container.read(appSettingsProvider.notifier).state = settings
          .load()
          .copyWith(academicProfile: supportedProfiles['jnu']);
      await container.read(timetablePeriodPreparationProvider.future);
      expect(store.periodFor(2026, '여름'), legacyPeriod);
      expect(store.periodFor(2026, '1'), userPeriod);
      await store.save(_course('new-term', semester: '겨울'));
      expect(store.periodFor(2026, '겨울'), officialPeriods['jnu']!['겨울']);
    },
  );

  test('unsupported university never receives SMU period defaults', () async {
    final settings = await _settings();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        appSettingsProvider.overrideWith(
          (ref) => settings.load().copyWith(
            academicProfile: const AcademicProfile(
              universityId: 'institution:unsupported',
              universityName: '미지원 대학교',
              schoolKind: 'fourYear',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final store = container.read(timetableStoreProvider);
    await container.read(timetablePeriodPreparationProvider.future);
    await store.save(_course('unsupported'));
    expect(store.activePeriod, isNull);
    expect(
      classOccurrences(
        store.classes,
        [DateTime(2026, 9, 7)],
        periodFor: (course) =>
            store.periodFor(course.academicYear, course.semester),
      ),
      isEmpty,
    );
  });

  test(
    'production asset provider prepares an existing timetable on first read',
    () async {
      final settings = await _settings();
      await settings.timetableStore.save(_course('existing'));
      expect(settings.timetableStore.activePeriod, isNull);
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(timetableStoreProvider),
        same(settings.timetableStore),
      );
      await container.read(timetablePeriodPreparationProvider.future);
      expect(settings.timetableStore.activePeriod, _fall);
      expect(
        settings.timetableStore
            .syncDocument()
            .termPeriods
            .values
            .single
            .changedAt,
        isNull,
      );
      final reloaded = TimetableStore(await SharedPreferences.getInstance());
      expect(reloaded.activePeriod, _fall);
    },
  );

  test(
    'preparation on an empty cache also bounds later local and remote courses',
    () async {
      final settings = await _settings();
      final defaults = await _defaults();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          timetablePeriodDefaultsProvider.overrideWith((ref) async => defaults),
        ],
      );
      addTearDown(container.dispose);
      final store = container.read(timetableStoreProvider);
      await container.read(timetablePeriodPreparationProvider.future);
      expect(store.terms, isEmpty);
      expect(store.hasPendingSync, isFalse);
      await store.save(_course('local'));
      expect(store.activePeriod, _fall);
      await store.clearLocal();
      final remote = TimetableSyncDocument.legacy(
        courses: [_course('remote'), _course('future-unknown', year: 2027)],
        termNames: {},
        activeYear: 2030,
        activeSemester: '1',
      );
      await store.mergeSyncDocument(remote);
      expect(store.periodFor(2026, '2'), _fall);
      expect(store.periodFor(2027, '2'), isNull);
      expect(store.activeYear, 2026);
      final occurrences = classOccurrences(
        store.classes,
        [DateTime(2026, 8, 31), DateTime(2026, 9, 7), DateTime(2026, 12, 28)],
        periodFor: (course) =>
            store.periodFor(course.academicYear, course.semester),
      );
      expect(occurrences.map((o) => o.course.id), ['remote']);
      expect(occurrences.single.date, DateTime(2026, 9, 7));
    },
  );

  test(
    'failed asset preparation stays bounded and can retry without replacing data',
    () async {
      final settings = await _settings();
      await settings.timetableStore.save(_course('existing'));
      var fail = true;
      final defaults = await _defaults();
      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          timetablePeriodDefaultsProvider.overrideWith((ref) async {
            if (fail) throw const FormatException('Test asset load failure');
            return defaults;
          }),
        ],
      );
      addTearDown(container.dispose);
      final store = container.read(timetableStoreProvider);
      await expectLater(
        container.read(timetablePeriodPreparationProvider.future),
        throwsFormatException,
      );
      expect(store.activePeriod, isNull);
      expect(store.classes.single.id, 'existing');
      expect(
        classOccurrences(
          store.classes,
          [DateTime(2026, 9, 7)],
          periodFor: (c) => store.periodFor(c.academicYear, c.semester),
        ),
        isEmpty,
      );
      fail = false;
      container.invalidate(timetablePeriodDefaultsProvider);
      await container.read(timetablePeriodPreparationProvider.future);
      expect(store.activePeriod, _fall);
      expect(store.classes.single.id, 'existing');
    },
  );

  test(
    'delayed defaults after local logout cannot restore previous-account courses',
    () async {
      final settings = await _settings();
      await settings.timetableStore.save(_course('previous-account'));
      final completer = Completer<TimetablePeriodDefaults>();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          timetablePeriodDefaultsProvider.overrideWith(
            (ref) => completer.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final store = container.read(timetableStoreProvider);
      await store.clearLocal();
      completer.complete(await _defaults());
      await container.read(timetablePeriodPreparationProvider.future);
      expect(store.classes, isEmpty);
      expect(store.terms, isEmpty);
      expect(store.syncDocument().isEmpty, isTrue);
      await store.save(_course('new-account'));
      expect(store.classes.single.id, 'new-account');
      expect(store.activePeriod, _fall);
    },
  );

  test(
    'production retry policy recovers a transient defaults failure',
    () async {
      final settings = await _settings();
      await settings.timetableStore.save(_course('existing'));
      final defaults = await _defaults();
      var attempts = 0;
      final prepared = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          timetablePeriodDefaultsProvider.overrideWith((ref) async {
            if (attempts++ == 0) {
              throw const FormatException('Transient test failure');
            }
            return defaults;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(timetablePeriodPreparationProvider, (previous, next) {
        if (next.hasValue && !prepared.isCompleted) prepared.complete();
      });
      expect(settings.timetableStore.activePeriod, isNull);
      await container
          .read(timetablePeriodPreparationProvider.future)
          .timeout(const Duration(seconds: 5));
      await prepared.future.timeout(const Duration(seconds: 5));
      expect(attempts, greaterThan(1));
      expect(settings.timetableStore.activePeriod, _fall);
      expect(settings.timetableStore.classes.single.id, 'existing');
    },
  );

  test(
    'changing the repository while loading only prepares the current store',
    () async {
      final previous = await _settings();
      await previous.timetableStore.save(_course('previous'));
      final current = await _settings();
      await current.timetableStore.save(_course('current'));
      final completer = Completer<TimetablePeriodDefaults>();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(previous),
          timetablePeriodDefaultsProvider.overrideWith(
            (ref) => completer.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(timetableStoreProvider);
      container.updateOverrides([
        settingsRepositoryProvider.overrideWithValue(current),
        timetablePeriodDefaultsProvider.overrideWith((ref) => completer.future),
      ]);
      expect(
        container.read(timetableStoreProvider),
        same(current.timetableStore),
      );
      completer.complete(await _defaults());
      await container.read(timetablePeriodPreparationProvider.future);
      expect(previous.timetableStore.activePeriod, isNull);
      expect(previous.timetableStore.classes.single.id, 'previous');
      expect(current.timetableStore.activePeriod, _fall);
      expect(current.timetableStore.classes.single.id, 'current');
    },
  );

  test(
    'logout during native seed write rolls back then preparation can retry',
    () async {
      final platform = _PausingPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsRepository(
        preferences: preferences,
        now: () => _now,
      );
      final store = settings.timetableStore;
      await store.save(_course('previous-account'));
      final defaults = await _defaults();
      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          timetablePeriodDefaultsProvider.overrideWith((ref) async => defaults),
        ],
      );
      addTearDown(container.dispose);
      final started = platform.started = Completer<void>();
      final resume = platform.resume = Completer<void>();
      container.read(timetableStoreProvider);
      final rejected = expectLater(
        container.read(timetablePeriodPreparationProvider.future),
        throwsStateError,
      );
      await started.future;
      final cleared = store.clearLocal();
      resume.complete();
      await rejected;
      await cleared;
      expect(store.classes, isEmpty);
      expect(preferences.containsKey(TimetableStore.storageKey), isFalse);
      container.invalidate(timetablePeriodPreparationProvider);
      await container.read(timetablePeriodPreparationProvider.future);
      await store.save(_course('new-account'));
      expect(store.classes.single.id, 'new-account');
      expect(store.activePeriod, _fall);
    },
  );
}
