import 'dart:async';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/settings_sync_document.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only failure injection through the same platform adapter as store tests.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _seoul = AcademicProfile(
  universityId: 'academyinfo:0000117',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
  campus: '서울캠퍼스',
);
const _cheonan = AcademicProfile(
  universityId: 'academyinfo:0002959',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
  campus: '천안캠퍼스',
);
const _other = AcademicProfile(
  universityId: 'other',
  universityName: '다른 대학',
  schoolKind: 'juniorCollege',
);

class _FailPreferences extends InMemorySharedPreferencesStore {
  _FailPreferences() : super.empty();
  String? failKey;
  String? pauseKey;
  final writeStarted = Completer<void>();
  final continueWrite = Completer<void>();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == pauseKey) {
      pauseKey = null;
      writeStarted.complete();
      await continueWrite.future;
    }
    if (key == failKey) {
      failKey = null;
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  Future<SettingsRepository> repository({bool signedIn = true}) async {
    final result = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
      now: () => DateTime.utc(2026, 9, 25),
    );
    if (signedIn) {
      await result.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
    }
    return result;
  }

  AppSettings decode(Map<String, Object?> values, AppSettings current) =>
      current.copyWith(
        academicProfile: values['academicProfile'] == null
            ? null
            : AcademicProfile.fromJson(
                Map<String, Object?>.from(values['academicProfile'] as Map),
              ),
        clearAcademicProfile: values['academicProfile'] == null,
      );

  test(
    'integrated universities and cyber profiles round-trip without a campus choice',
    () {
      for (final (id, university, campus) in [
        ('0000117', 'smu', 'seoul'),
        ('0000082', 'dku', 'jukjeon'),
        ('0000023', 'jnu', 'gwangju'),
      ]) {
        final profile = AcademicProfile.fromJson({
          'universityId': 'institution:academyinfo:$id',
          'universityName': 'University',
          'schoolKind': 'fourYear',
        });
        expect(profile.timetableUniversity, university);
        expect(profile.timetableCampus, campus);
        expect(profile.academicSourceId, university);
        expect(AcademicProfile.fromJson(profile.toJson()), profile);
        expect(profile.campusId, isNull);
      }
      expect(
        AcademicProfile.fromJson({
          'universityId': 'institution:cyber',
          'universityName': 'Cyber',
          'schoolKind': 'cyberUniversity',
        }).schoolKind,
        'cyberUniversity',
      );
      expect(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000117',
          universityName: 'School',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000024',
        ).supported,
        isFalse,
      );
    },
  );

  test('profiles round-trip and support follows stable campus identity', () {
    expect(AcademicProfile.fromJson(_seoul.toJson()), _seoul);
    expect(_seoul.timetableCampus, 'seoul');
    expect(_cheonan.timetableCampus, 'cheonan');
    expect(_seoul.academicSourceId, 'smu');
    expect(_seoul.displayName, '상명대학교');
    expect(_other.supported, isFalse);
    expect(
      const AcademicProfile(
        universityId: 'untrusted',
        universityName: '상명대학교',
        schoolKind: 'fourYear',
      ).supported,
      isFalse,
    );
    for (final invalid in [
      {..._seoul.toJson(), 'schoolKind': 'unknown'},
      {..._seoul.toJson(), 'universityId': ''},
      {..._seoul.toJson(), 'universityName': ' '},
      {..._seoul.toJson(), 'campus': 3},
    ]) {
      expect(() => AcademicProfile.fromJson(invalid), throwsFormatException);
    }
  });

  test(
    'institution and campus IDs remain distinct while legacy JSON stays unchanged',
    () {
      for (final (id, label, integration) in [
        ('academyinfo:0000117', '서울캠퍼스', 'seoul'),
        ('academyinfo:0002959', '천안캠퍼스', 'cheonan'),
      ]) {
        final profile = AcademicProfile(
          universityId: 'institution:academyinfo:0000117',
          universityName: '상명대학교',
          schoolKind: 'fourYear',
          campusId: id,
          campus: label,
        );
        expect(AcademicProfile.fromJson(profile.toJson()), profile);
        expect(profile.selectedCampusId, id);
        expect(profile.timetableCampus, integration);
        expect(profile.supported, isTrue);
      }
      for (final legacy in [_seoul, _cheonan]) {
        final json = legacy.toJson();
        expect(json.containsKey('campusId'), isFalse);
        expect(AcademicProfile.fromJson(json).toJson(), json);
        expect(
          AcademicProfile.fromJson(json).selectedCampusId,
          legacy.universityId,
        );
      }
      expect(
        const AcademicProfile(
          universityId: 'institution:other',
          universityName: '상명대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).supported,
        isFalse,
      );
      for (final malformed in [
        {..._seoul.toJson(), 'campusId': ''},
        {..._seoul.toJson(), 'campusId': 3},
      ]) {
        expect(
          () => AcademicProfile.fromJson(malformed),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'campus-only change stays one atomic Drive profile value across reload',
    () async {
      final repo = await repository();
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000117',
        universityName: '상명대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0002959',
        campus: '천안캠퍼스',
      );
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.acknowledgeSettingsSyncDocument(repo.settingsSyncDocument());
      await repo.saveAcademicProfile(
        profile,
        expectedGoogleEmail: 'student@example.com',
      );
      expect(repo.settingsSyncDocument().fields.keys, ['academicProfile']);
      expect(
        repo.settingsSyncDocument().fields['academicProfile']!.value,
        profile.toJson(),
      );
      expect((await repository()).load().academicProfile, profile);
      expect(repo.load().academicProfile!.timetableCampus, 'cheonan');
    },
  );

  test(
    'saved profile persists as one Drive settings register and idempotent save stays clean',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'STUDENT@example.com',
      );
      expect(repo.load().academicProfile, _seoul);
      expect(
        syncSettingsValues(repo.load())['academicProfile'],
        _seoul.toJson(),
      );
      final doc = repo.settingsSyncDocument();
      expect(doc.fields.keys, ['academicProfile']);
      expect(doc.fields['academicProfile']!.value, _seoul.toJson());
      expect(
        doc.fields['academicProfile']!.changedAt,
        DateTime.utc(2026, 9, 25),
      );
      expect(repo.hasPendingSettingsSync, isTrue);
      expect((await repository()).load().academicProfile, _seoul);
      await repo.acknowledgeSettingsSyncDocument(doc);
      final revision = repo.settingsSyncRevision;
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      expect(repo.hasPendingSettingsSync, isFalse);
      expect(repo.settingsSyncRevision, revision);
    },
  );

  test(
    'newer remote profile replaces whole campus and clearing is a sync null value',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      final remote = SettingsSyncDocument({
        'academicProfile': SettingsSyncValue(
          _cheonan.toJson(),
          DateTime.utc(2026, 9, 26),
          'remote',
        ),
      });
      expect(await repo.mergeSettingsSyncDocument(remote, decode), isTrue);
      expect(repo.load().academicProfile, _cheonan);
      expect(repo.hasPendingSettingsSync, isFalse);
      await repo.save(repo.load().copyWith(clearAcademicProfile: true));
      expect(repo.load().academicProfile, isNull);
      expect(
        repo.settingsSyncDocument().fields['academicProfile']!.value,
        isNull,
      );
      expect(repo.hasPendingSettingsSync, isTrue);
      final cleared = repo.settingsSyncDocument();
      expect(await repo.acknowledgeSettingsSyncDocument(cleared), isTrue);
      expect(repo.hasPendingSettingsSync, isFalse);
      final remoteClear = SettingsSyncDocument({
        'academicProfile': SettingsSyncValue(
          null,
          DateTime.utc(2026, 9, 27),
          'remote',
        ),
      });
      await repo.mergeSettingsSyncDocument(remoteClear, decode);
      expect(repo.load().academicProfile, isNull);
      expect(
        repo.settingsSyncDocument().fields['academicProfile']!.value,
        isNull,
      );
      expect(repo.hasPendingSettingsSync, isFalse);
    },
  );

  test(
    'older or absent remote academic data cannot erase saved school',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      final older = SettingsSyncDocument({
        'academicProfile': SettingsSyncValue(
          _other.toJson(),
          DateTime.utc(2026, 9, 24),
          'remote',
        ),
      });
      await repo.mergeSettingsSyncDocument(older, decode);
      await repo.mergeSettingsSyncDocument(
        const SettingsSyncDocument(),
        decode,
      );
      expect(repo.load().academicProfile, _seoul);
    },
  );

  test('signed-out and stale-account editors cannot write a school', () async {
    final repo = await repository(signedIn: false);
    await expectLater(
      repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      ),
      throwsStateError,
    );
    await repo.saveGoogleAccount(
      const GoogleAccount(email: 'other@example.com'),
    );
    await expectLater(
      repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      ),
      throwsStateError,
    );
    expect(repo.load().academicProfile, isNull);
    expect(repo.hasPendingSettingsSync, isFalse);
  });

  test(
    'reset invalidates queued profile save and clears local school with account',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      final rejected = expectLater(
        repo.saveAcademicProfile(
          _cheonan,
          expectedGoogleEmail: 'student@example.com',
        ),
        throwsStateError,
      );
      await repo.resetAll();
      await rejected;
      expect(repo.load().academicProfile, isNull);
      expect(repo.dailyAccount(), isNull);
      expect(repo.hasPendingSettingsSync, isFalse);
      expect(repo.settingsSyncDocument().fields, isEmpty);
    },
  );

  test(
    'account switch waits for a profile write then retains its outbox for the original owner',
    () async {
      final backend = _FailPreferences();
      SharedPreferencesStorePlatform.instance = backend;
      SharedPreferences.resetStatic();
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.acknowledgeSettingsSyncDocument(repo.settingsSyncDocument());
      backend.pauseKey = 'flutter.academicProfile.v1';
      final write = repo.saveAcademicProfile(
        _cheonan,
        expectedGoogleEmail: 'student@example.com',
      );
      await backend.writeStarted.future;
      final switchAccount = repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      backend.continueWrite.complete();
      await write;
      await switchAccount;
      expect(repo.load().academicProfile, isNull);
      expect(
        repo.settingsSyncDocument().fields.containsKey('academicProfile'),
        isFalse,
      );
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      expect(repo.load().academicProfile, _cheonan);
      expect(
        repo.settingsSyncDocument().fields['academicProfile']!.value,
        _cheonan.toJson(),
      );
      expect(repo.hasPendingSettingsSync, isTrue);
    },
  );

  test(
    'queued upload acknowledgement cannot attach the previous account deletion to the new account',
    () async {
      final backend = _FailPreferences();
      SharedPreferencesStorePlatform.instance = backend;
      SharedPreferences.resetStatic();
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.save(repo.load().copyWith(clearAcademicProfile: true));
      final uploaded = repo.settingsSyncDocument();
      expect(uploaded.fields['academicProfile']!.value, isNull);
      backend.pauseKey = 'flutter.academicProfile.accounts.v1';
      final switchAccount = repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      await backend.writeStarted.future;
      expect(repo.dailyAccount()!.googleAccount!.email, 'student@example.com');
      final rejectedAck = expectLater(
        repo.acknowledgeSettingsSyncDocument(
          uploaded,
          validateSession: () {
            if (repo.dailyAccount()?.googleAccount?.email !=
                'student@example.com') {
              throw StateError('Sync account changed');
            }
          },
        ),
        throwsStateError,
      );
      backend.continueWrite.complete();
      await switchAccount;
      await rejectedAck;
      expect(repo.load().academicProfile, isNull);
      expect(
        repo.settingsSyncDocument().fields.containsKey('academicProfile'),
        isFalse,
      );
      expect(repo.hasPendingSettingsSync, isFalse);
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      expect(repo.settingsSyncDocument().sameAs(uploaded), isTrue);
      expect(repo.hasPendingSettingsSync, isTrue);
    },
  );

  test(
    'different Google accounts retain separate profiles without moving ordinary settings',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.save(repo.load().copyWith(use24HourTime: false));
      final ordinary = repo
          .settingsSyncDocument()
          .fields['use24HourTime']!
          .toJson();
      final firstRegister = repo
          .settingsSyncDocument()
          .fields['academicProfile']!
          .toJson();
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      expect(repo.load().academicProfile, isNull);
      expect(
        repo.settingsSyncDocument().fields.containsKey('academicProfile'),
        isFalse,
      );
      expect(
        syncSettingsValues(repo.load()).containsKey('academicProfile'),
        isFalse,
      );
      expect(repo.load().use24HourTime, isFalse);
      expect(
        repo.settingsSyncDocument().fields['use24HourTime']!.toJson(),
        ordinary,
      );
      await repo.saveAcademicProfile(
        _other,
        expectedGoogleEmail: 'other@example.com',
      );
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'STUDENT@example.com'),
      );
      expect(repo.load().academicProfile, _seoul);
      expect(
        repo.settingsSyncDocument().fields['academicProfile']!.toJson(),
        firstRegister,
      );
      expect(repo.hasPendingSettingsSync, isTrue);
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      expect(repo.load().academicProfile, _other);
    },
  );

  test(
    'unlink and restart preserve unuploaded profile for only its original account',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      final register = repo
          .settingsSyncDocument()
          .fields['academicProfile']!
          .toJson();
      await repo.deleteGoogleAccount();
      expect(repo.load().academicProfile, isNull);
      expect(
        repo.settingsSyncDocument().fields.containsKey('academicProfile'),
        isFalse,
      );
      expect(repo.hasPendingSettingsSync, isFalse);
      final restarted = await repository(signedIn: false);
      await restarted.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      expect(restarted.load().academicProfile, isNull);
      expect(
        restarted.settingsSyncDocument().fields.containsKey('academicProfile'),
        isFalse,
      );
      await restarted.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      expect(restarted.load().academicProfile, _seoul);
      expect(
        restarted.settingsSyncDocument().fields['academicProfile']!.toJson(),
        register,
      );
      expect(restarted.hasPendingSettingsSync, isTrue);
    },
  );

  test(
    'same-account reconnect and legacy owner migration preserve acknowledged profile',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.acknowledgeSettingsSyncDocument(repo.settingsSyncDocument());
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('academicProfile.owner.v1');
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'STUDENT@example.com'),
      );
      expect(repo.load().academicProfile, _seoul);
      expect(repo.hasPendingSettingsSync, isFalse);
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      expect(repo.load().academicProfile, isNull);
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      expect(repo.load().academicProfile, _seoul);
      expect(repo.hasPendingSettingsSync, isFalse);
    },
  );

  test(
    'a profile deletion register stays with its account and never deletes another account profile',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.save(repo.load().copyWith(clearAcademicProfile: true));
      final deletion = repo
          .settingsSyncDocument()
          .fields['academicProfile']!
          .toJson();
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      expect(
        repo.settingsSyncDocument().fields.containsKey('academicProfile'),
        isFalse,
      );
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      expect(
        repo.settingsSyncDocument().fields['academicProfile']!.toJson(),
        deletion,
      );
      expect(
        repo.settingsSyncDocument().fields['academicProfile']!.value,
        isNull,
      );
      expect(repo.hasPendingSettingsSync, isTrue);
    },
  );

  test(
    'unowned legacy data is preserved without assigning it to a new login',
    () async {
      final repo = await repository(signedIn: false);
      await repo.save(repo.load().copyWith(academicProfile: _seoul));
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      expect(repo.load().academicProfile, isNull);
      expect(
        repo.settingsSyncDocument().fields.containsKey('academicProfile'),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('academicProfile.accounts.v1'),
        contains('_unassigned'),
      );
      expect(
        prefs.getString('academicProfile.accounts.v1'),
        contains('academyinfo:0000117'),
      );
    },
  );

  test(
    'explicit reset removes inactive account caches as well as active data',
    () async {
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      await repo.resetAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('academicProfile.accounts.v1'), isFalse);
      expect(prefs.containsKey('academicProfile.owner.v1'), isFalse);
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      expect(repo.load().academicProfile, isNull);
    },
  );

  for (final key in [
    'dailyAccount',
    'academicProfile.v1',
    'academicProfile.owner.v1',
    'academicProfile.accounts.v1',
    'settingsSyncDocument.v1',
    'settingsSyncPending',
    'settingsSyncRevision',
  ]) {
    test(
      'failed account transition at $key restores account and all profile data',
      () async {
        final backend = _FailPreferences();
        SharedPreferencesStorePlatform.instance = backend;
        SharedPreferences.resetStatic();
        final repo = await repository();
        await repo.saveAcademicProfile(
          _seoul,
          expectedGoogleEmail: 'student@example.com',
        );
        await repo.saveGoogleAccount(
          const GoogleAccount(email: 'other@example.com'),
        );
        await repo.saveAcademicProfile(
          _other,
          expectedGoogleEmail: 'other@example.com',
        );
        await repo.saveGoogleAccount(
          const GoogleAccount(email: 'student@example.com'),
        );
        final prefs = await SharedPreferences.getInstance();
        final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
        backend.failKey = 'flutter.$key';
        await expectLater(
          repo.saveGoogleAccount(
            const GoogleAccount(email: 'other@example.com'),
          ),
          throwsStateError,
        );
        expect({
          for (final key in prefs.getKeys()) key: prefs.get(key),
        }, before);
        expect(repo.load().academicProfile, _seoul);
        expect(
          repo.dailyAccount()!.googleAccount!.email,
          'student@example.com',
        );
      },
    );
  }

  for (final key in [
    'academicProfile.v1',
    'settingsSyncDocument.v1',
    'settingsSyncRevision',
    'settingsSyncPending',
  ]) {
    test('failed $key write restores profile and pending document', () async {
      final backend = _FailPreferences();
      SharedPreferencesStorePlatform.instance = backend;
      SharedPreferences.resetStatic();
      final repo = await repository();
      await repo.saveAcademicProfile(
        _seoul,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.acknowledgeSettingsSyncDocument(repo.settingsSyncDocument());
      final doc = repo.settingsSyncDocument().toJson();
      final revision = repo.settingsSyncRevision;
      backend.failKey = 'flutter.$key';
      await expectLater(
        repo.saveAcademicProfile(
          _other,
          expectedGoogleEmail: 'student@example.com',
        ),
        throwsStateError,
      );
      expect(repo.load().academicProfile, _seoul);
      expect(repo.settingsSyncDocument().toJson(), doc);
      expect(repo.settingsSyncRevision, revision);
      expect(repo.hasPendingSettingsSync, isFalse);
    });
  }
}
