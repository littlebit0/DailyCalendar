import 'dart:async';
import 'dart:convert';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/auth/apple_account.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _documentKey = 'flutter.settingsSyncDocument.v1';
const _ownerKey = 'flutter.academicProfile.owner.v1';
const _apple = AppleAccount(userIdentifier: 'apple-user');
const _seoul = AcademicProfile(
  universityId: 'academyinfo:0000117',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
  campus: '서울캠퍼스',
);

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

  test('a damaged settings sync document does not block saving', () async {
    store.values[_documentKey] = '{"themeMode":';
    await preferences.reload();
    final before = repository.load();

    await repository.save(before.copyWith(morningBriefingEnabled: false));

    final reread = await cold();
    expect(reread.load().morningBriefingEnabled, isFalse);
    expect(reread.hasPendingSettingsSync, isTrue);
    expect(jsonDecode(store.values[_documentKey]! as String), isA<Map>());
    expect(
      reread.settingsSyncDocument().fields['morningBriefingEnabled']!.value,
      isFalse,
    );
  });

  test('a failed revision write still leaves the change pending', () async {
    final before = repository.load();
    store.failingKeys['flutter.settingsSyncRevision'] = 1;

    await expectLater(
      repository.save(before.copyWith(morningBriefingEnabled: false)),
      throwsA(isA<Object>()),
    );

    final reread = await cold();
    expect(reread.hasPendingSettingsSync, isTrue);
    expect(
      reread.settingsSyncDocument().fields['morningBriefingEnabled']!.value,
      isFalse,
    );
  });

  test('Apple link saved during a Google disconnect is kept', () async {
    await repository.saveGoogleAccount(const GoogleAccount(email: 'a@x.com'));
    final gate = store.gates[_ownerKey] = Completer<void>();

    final disconnect = repository.deleteGoogleAccount();
    await pumpEventQueue();
    final appleSave = repository.saveAppleAccount(_apple);
    await pumpEventQueue();
    gate.complete();
    await Future.wait([disconnect, appleSave]);

    final reread = await cold();
    expect(reread.hasStoredDailyAccount, isTrue);
    expect(reread.dailyAccount()!.googleAccount, isNull);
    expect(reread.dailyAccount()!.appleAccount!.userIdentifier, 'apple-user');
  });

  test(
    'Apple link saved before a failed Google switch rolls back is kept',
    () async {
      await repository.saveGoogleAccount(const GoogleAccount(email: 'a@x.com'));
      final gate = store.gates[_ownerKey] = Completer<void>();
      store.failingKeys['flutter.dailyAccount'] = 1;

      final failedSwitch = repository.saveGoogleAccount(
        const GoogleAccount(email: 'b@x.com'),
      );
      final failure = expectLater(failedSwitch, throwsA(isA<Object>()));
      await pumpEventQueue();
      final appleSave = repository.saveAppleAccount(_apple);
      await pumpEventQueue();
      gate.complete();
      await failure;
      await appleSave;

      final account = (await cold()).dailyAccount()!;
      expect(account.googleAccount!.email, 'a@x.com');
      expect(account.appleAccount!.userIdentifier, 'apple-user');
    },
  );

  test(
    'school save keeps an LMS login stored after the editor opened',
    () async {
      const email = 'student@example.com';
      await repository.saveGoogleAccount(const GoogleAccount(email: email));
      await repository.saveAcademicProfile(_seoul, expectedGoogleEmail: email);
      // The editor's snapshot is `_seoul` without an LMS user; a login finishes.
      expect(
        await repository.updateLmsConnection(
          expectedGoogleEmail: email,
          expectedSchoolId: _seoul.timetableUniversity!,
          userId: 'lms-user',
          allowPrincipalChange: true,
          enabled: true,
        ),
        isTrue,
      );

      await repository.saveAcademicSchool(_seoul, expectedGoogleEmail: email);

      final sameSchool = (await cold()).load().academicProfile!;
      expect(sameSchool.lmsUserId, 'lms-user');
      expect(sameSchool.lmsIntegrationEnabled, isTrue);

      await repository.saveAcademicSchool(
        const AcademicProfile(
          universityId: 'other',
          universityName: '다른대학교',
          schoolKind: 'fourYear',
        ),
        expectedGoogleEmail: email,
      );
      final otherSchool = (await cold()).load().academicProfile!;
      expect(otherSchool.universityId, 'other');
      expect(otherSchool.lmsUserId, isNull);
      expect(otherSchool.lmsIntegrationEnabled, isNull);
    },
  );
}

class _Store extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};

  /// Number of upcoming writes of a key that report failure.
  final failingKeys = <String, int>{};

  /// A write or removal of a gated key waits until its completer finishes.
  final gates = <String, Completer<void>>{};

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    await gates.remove(key)?.future;
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await gates.remove(key)?.future;
    final remaining = failingKeys[key] ?? 0;
    if (remaining > 0) {
      failingKeys[key] = remaining - 1;
      return false;
    }
    values[key] = value;
    return true;
  }
}
