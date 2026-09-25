import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _timetableFile = 'daily-sync-v2-timetable.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool previousDatabaseWarning;
  setUpAll(() {
    previousDatabaseWarning =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    // Each simulated device owns a distinct NativeDatabase.memory executor.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        previousDatabaseWarning;
  });

  for (final grouped in [false, true]) {
    test(
      'academic profile restores the selected campus through Drive (${grouped ? 'institution and campus IDs' : 'legacy campus ID'})',
      () async {
        final drive = _TimetableDrive();
        final source = await _Device.create(drive);
        final cheonan = AcademicProfile(
          universityId: grouped
              ? 'institution:academyinfo:0000117'
              : 'academyinfo:0002959',
          campusId: grouped ? 'academyinfo:0002959' : null,
          universityName: '상명대학교',
          schoolKind: 'fourYear',
          campus: '천안캠퍼스',
        );
        await source.settings.saveAcademicProfile(
          cheonan,
          expectedGoogleEmail: source.auth.email,
        );
        await source.service.syncPendingChangesNow();
        final uploaded = drive.payload('daily-sync-v2-settings.json');
        expect(
          (uploaded['settings'] as Map)['academicProfile'],
          cheonan.toJson(),
        );
        expect(drive.writes, ['daily-sync-v2-settings.json']);
        final target = await _Device.create(drive);
        await target.service.restoreNow();
        expect(target.settings.load().academicProfile, cheonan);
        expect(
          target.settings.load().academicProfile!.timetableCampus,
          'cheonan',
        );

        const other = AcademicProfile(
          universityId: 'academyinfo:another',
          universityName: '다른 대학교',
          schoolKind: 'fourYear',
        );
        await source.settings.saveAcademicProfile(
          other,
          expectedGoogleEmail: source.auth.email,
        );
        await source.service.syncPendingChangesNow();
        await target.service.restoreNow();
        expect(target.settings.load().academicProfile, other);
        expect(target.settings.load().academicProfile!.supported, isFalse);
        expect(await target.events.allEventsForSync(), isEmpty);
      },
    );
  }

  test(
    'account switching isolates academic profile uploads and retains offline edits',
    () async {
      final driveA = _TimetableDrive();
      final driveB = _TimetableDrive();
      final device = await _Device.create(
        driveA,
        accountDrives: {
          'tester@example.com': driveA,
          'second@example.com': driveB,
        },
      );
      const profileA = AcademicProfile(
        universityId: 'academyinfo:0002959',
        universityName: '상명대학교',
        schoolKind: 'fourYear',
        campus: '천안캠퍼스',
      );
      await device.settings.saveAcademicProfile(
        profileA,
        expectedGoogleEmail: device.auth.email,
      );
      expect(driveA.writes, isEmpty);
      await device.settings.deleteGoogleAccount();
      device.auth.email = 'second@example.com';
      await device.settings.saveGoogleAccount(
        GoogleAccount(email: device.auth.email),
      );
      expect(device.settings.load().academicProfile, isNull);
      await device.settings.save(
        device.settings.load().copyWith(showLunarDates: false),
      );
      await device.service.syncPendingChangesNow();
      final uploadedB = driveB.payload('daily-sync-v2-settings.json');
      expect(
        (uploadedB['settings'] as Map).containsKey('academicProfile'),
        isFalse,
      );
      expect(
        (uploadedB['fieldRevisions'] as Map).containsKey('academicProfile'),
        isFalse,
      );

      device.auth.email = 'tester@example.com';
      await device.settings.saveGoogleAccount(
        GoogleAccount(email: device.auth.email),
      );
      expect(device.settings.load().academicProfile, profileA);
      await device.service.syncPendingChangesNow();
      expect(
        (driveA.payload('daily-sync-v2-settings.json')['settings']
            as Map)['academicProfile'],
        profileA.toJson(),
      );
      expect(await device.service.hasPendingChanges(), isFalse);
    },
  );

  test(
    'a local course change automatically uploads only the timetable',
    () async {
      final drive = _TimetableDrive();
      final device = await _Device.create(drive, automatic: true);
      await device.service.startListeningOnly(flushPendingChanges: false);
      await device.store.save(_course('local'));
      await _until(
        () => drive.writes.isNotEmpty && !device.store.hasPendingSync,
      );

      expect(drive.writes, [_timetableFile]);
      expect(await device.service.hasPendingChanges(), isFalse);
      expect(drive.payload(_timetableFile)['schemaVersion'], 2);
      expect(drive.payload(_timetableFile)['type'], 'timetable');
      expect(
        drive.requests
            .where((r) => r.url.path == '/drive/v3/files')
            .every(
              (r) =>
                  (r.url.queryParameters['q'] ?? '').contains(_timetableFile),
            ),
        isTrue,
      );
      expect(await device.events.allEventsForSync(), isEmpty);
    },
  );

  test(
    'pending timetable changes survive restart and join lifecycle flush',
    () async {
      final drive = _TimetableDrive();
      final first = await _Device.create(drive);
      await first.store.save(_course('offline'));
      final persisted = first.preferences.getKeys().fold<Map<String, Object>>(
        {},
        (values, key) => values..[key] = first.preferences.get(key)!,
      );
      await first.close();
      final restarted = await _Device.create(drive, initial: persisted);

      expect(await restarted.service.hasPendingChanges(), isTrue);
      await restarted.service.syncPendingChangesNow();
      expect(restarted.store.classes.single.id, 'offline');
      expect(restarted.store.hasPendingSync, isFalse);
      expect(drive.writes, [_timetableFile]);
    },
  );

  test(
    'an existing Drive token still bootstraps a preexisting timetable once',
    () async {
      final drive = _TimetableDrive();
      final source = await _Device.create(drive);
      await source.store.selectTerm(2026, '2');
      await source.store.save(_course('remote'));
      await source.store.renameActive('가을 수업');
      await source.store.setOverride(
        'remote',
        'meeting',
        DateTime(2026, 9, 28),
        LectureMode.cancelled,
      );
      await source.service.syncPendingChangesNow();
      final target = await _Device.create(drive);
      await target.store.selectTerm(2025, '1');
      await target.settings.saveDriveChangePageToken(
        accountEmail: target.auth.email,
        pageToken: drive.cursor,
      );
      drive.requests.clear();

      await target.service.checkForRemoteChangesNow();
      expect(target.store.classes.single.id, 'remote');
      expect(target.store.activeYear, 2025);
      expect(target.store.activeSemester, '1');
      await target.store.selectTerm(2026, '2');
      expect(target.store.activeName, '가을 수업');
      expect(
        target.store.classes.single.overrides.values.single,
        LectureMode.cancelled,
      );
      expect(target.store.hasPendingSync, isFalse);
      final downloads = drive.timetableDownloads;
      await target.service.checkForRemoteChangesNow();
      expect(drive.timetableDownloads, downloads);
      await source.store.save(_course('remote-addition'));
      await source.service.syncPendingChangesNow();
      drive.requests.clear();
      await target.service.checkForRemoteChangesNow();
      expect(target.store.classes.map((c) => c.id).toSet(), {
        'remote',
        'remote-addition',
      });
      expect(drive.timetableDownloads, downloads + 2);
      expect(
        drive.requests
            .where((r) => r.url.path == '/drive/v3/files')
            .every(
              (r) =>
                  (r.url.queryParameters['q'] ?? '').contains(_timetableFile),
            ),
        isTrue,
      );
    },
  );

  test(
    'selecting another term neither uploads nor moves another device',
    () async {
      final drive = _TimetableDrive();
      final source = await _Device.create(drive);
      await source.store.selectTerm(2026, '2');
      await source.store.save(_course('shared'));
      await source.service.syncPendingChangesNow();
      final target = await _Device.create(drive);
      await target.store.selectTerm(2024, '여름');
      await target.service.restoreNow();
      expect(target.store.activeYear, 2024);
      expect(target.store.activeSemester, '여름');
      drive.writes.clear();

      await source.store.selectTerm(2027, '1');
      expect(source.store.hasPendingSync, isFalse);
      expect(await source.service.hasPendingChanges(), isFalse);
      await source.service.syncPendingChangesNow();
      expect(drive.writes, isEmpty);

      // A later data change still synchronizes without carrying UI navigation.
      await source.store.save(_course('shared', title: 'Updated course'));
      await source.service.syncPendingChangesNow();
      await target.service.checkForRemoteChangesNow();
      expect(target.store.classes.single.title, 'Updated course');
      expect(target.store.activeYear, 2024);
      expect(target.store.activeSemester, '여름');
      expect(source.store.activeYear, 2027);
      expect(
        (drive.payload(_timetableFile)['document'] as Map)['activeTerm'],
        isNull,
      );
    },
  );

  test(
    'term periods upload and restore through Drive independently of selection',
    () async {
      final drive = _TimetableDrive();
      final source = await _Device.create(drive);
      final fall = TimetablePeriod(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 12, 21),
      );
      final winter = TimetablePeriod(
        start: DateTime(2026, 12, 22),
        end: DateTime(2027, 1, 8),
      );
      await source.store.setTermPeriod(2026, '2', fall);
      await source.store.createTerm(2026, '겨울', period: winter, name: '겨울 수업');
      await source.store.save(_course('fall'));
      await source.service.syncPendingChangesNow();

      expect(drive.writes, [_timetableFile]);
      final document = Map<String, dynamic>.from(
        drive.payload(_timetableFile)['document'] as Map,
      );
      final periods = Map<String, dynamic>.from(document['termPeriods'] as Map);
      expect(periods[timetableTermSyncKey(2026, '2')]['value'], {
        'startDate': '2026-09-01',
        'endDate': '2026-12-21',
      });
      expect(periods[timetableTermSyncKey(2026, '겨울')]['value'], {
        'startDate': '2026-12-22',
        'endDate': '2027-01-08',
      });
      final target = await _Device.create(drive);
      await target.store.selectTerm(2025, '1');
      await target.service.restoreNow();
      expect(target.store.periodFor(2026, '2'), fall);
      expect(target.store.periodFor(2026, '겨울'), winter);
      expect(
        target.store.terms.singleWhere((t) => t.semester == '겨울').courseCount,
        0,
      );
      expect(target.store.activeYear, 2025);
      expect(target.store.activeSemester, '1');
      expect(await target.events.allEventsForSync(), isEmpty);

      final shortened = TimetablePeriod(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 12, 14),
      );
      await source.store.setTermPeriod(2026, '2', shortened);
      await source.service.syncPendingChangesNow();
      await target.service.checkForRemoteChangesNow();
      expect(target.store.periodFor(2026, '2'), shortened);
      expect(target.store.periodFor(2026, '겨울'), winter);
      expect(target.store.activeYear, 2025);
      expect(target.store.activeSemester, '1');
      expect(target.store.hasPendingSync, isFalse);
      expect(await target.events.allEventsForSync(), isEmpty);
    },
  );

  test(
    'a new device startup restores courses without ordinary calendar events',
    () async {
      final drive = _TimetableDrive();
      final source = await _Device.create(drive);
      await source.store.save(_course('remote', mode: LectureMode.video));
      await source.service.syncPendingChangesNow();
      final target = await _Device.create(drive);
      final previousWrites = drive.writes.length;

      await target.service.start();
      expect(target.store.classes.single.defaultMode, LectureMode.video);
      expect(target.store.hasPendingSync, isFalse);
      expect(await target.events.allEventsForSync(), isEmpty);
      expect(drive.writes, hasLength(previousWrites));
    },
  );

  test(
    'an offline device cannot resurrect a remotely deleted course',
    () async {
      final drive = _TimetableDrive();
      final first = await _Device.create(drive);
      await first.store.save(_course('removed'));
      await first.service.syncPendingChangesNow();
      final stale = await _Device.create(drive);
      await stale.service.restoreNow();
      await first.store.remove('removed');
      await first.service.syncPendingChangesNow();
      await stale.store.save(_course('offline-addition'));

      await stale.service.syncPendingChangesNow();
      expect(stale.store.classes.map((c) => c.id), ['offline-addition']);
      final fresh = await _Device.create(drive);
      await fresh.service.restoreNow();
      expect(fresh.store.classes.map((c) => c.id), ['offline-addition']);
      expect(await stale.service.hasPendingChanges(), isFalse);
    },
  );

  test(
    'an edit during upload stays pending until its own snapshot is uploaded',
    () async {
      final drive = _TimetableDrive();
      final device = await _Device.create(drive);
      await device.store.save(_course('course', title: 'Original'));
      await device.service.syncPendingChangesNow();
      await device.store.save(_course('course', title: 'First edit'));
      drive.beforeWrite = () =>
          device.store.save(_course('course', title: 'Latest edit'));

      await expectLater(
        device.service.syncPendingChangesNow(),
        throwsA(isA<GoogleDriveSyncException>()),
      );
      expect(device.store.classes.single.title, 'Latest edit');
      expect(device.store.hasPendingSync, isTrue);
      await device.service.syncPendingChangesNow();
      expect(device.store.hasPendingSync, isFalse);
      final fresh = await _Device.create(drive);
      await fresh.service.restoreNow();
      expect(fresh.store.classes.single.title, 'Latest edit');
    },
  );

  test('ETag conflict retry merges a course added by another device', () async {
    final drive = _TimetableDrive();
    final local = await _Device.create(drive);
    await local.store.save(_course('shared'));
    await local.service.syncPendingChangesNow();
    final remote = await _Device.create(drive);
    await remote.service.restoreNow();
    await remote.store.save(_course('remote-addition'));
    final concurrent = _envelope(remote.store.syncDocument());
    await local.store.save(_course('local-addition'));
    drive.beforeWrite = () {
      drive.seed('timetable', _timetableFile, concurrent);
    };

    await local.service.syncPendingChangesNow();
    expect(drive.preconditionFailures, 1);
    expect(local.store.classes.map((c) => c.id).toSet(), {
      'shared',
      'local-addition',
      'remote-addition',
    });
    expect(local.store.hasPendingSync, isFalse);
    expect(
      drive.requests
          .where((r) => r.method == 'PUT')
          .every((r) => r.headers['if-match']?.isNotEmpty ?? false),
      isTrue,
    );
  });

  test(
    'malformed remote data preserves local data and the change cursor',
    () async {
      final drive = _TimetableDrive();
      final device = await _Device.create(drive);
      await device.store.save(_course('local'));
      await device.service.syncPendingChangesNow();
      await device.service.checkForRemoteChangesNow();
      final token = device.settings.driveChangePageToken(device.auth.email);
      final before = jsonEncode(device.store.syncDocument().toJson());
      drive.seed('timetable', _timetableFile, {
        'schemaVersion': 2,
        'type': 'timetable',
        'document': {'schemaVersion': 999, 'classes': []},
      });

      await expectLater(
        device.service.checkForRemoteChangesNow(),
        throwsA(isA<GoogleDriveSyncException>()),
      );
      expect(jsonEncode(device.store.syncDocument().toJson()), before);
      expect(device.settings.driveChangePageToken(device.auth.email), token);
      expect(device.store.classes.single.id, 'local');
    },
  );

  test(
    'stop during a download prevents applying the previous session data',
    () async {
      final drive = _TimetableDrive();
      final source = await _Device.create(drive);
      await source.store.save(_course('remote'));
      await source.service.syncPendingChangesNow();
      final target = await _Device.create(drive);
      final downloading = Completer<void>();
      final release = Completer<void>();
      drive.beforeTimetableDownload = () async {
        downloading.complete();
        await release.future;
      };
      final operation = target.service.restoreNow();
      final rejected = expectLater(
        operation,
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await downloading.future;
      final stopped = target.service.stop();
      release.complete();
      await rejected;
      await stopped;
      expect(target.store.classes, isEmpty);
      expect(target.store.hasPendingSync, isFalse);
    },
  );

  test(
    'an account change during download rejects the old account snapshot',
    () async {
      final drive = _TimetableDrive();
      final source = await _Device.create(drive);
      await source.store.save(_course('old-account'));
      await source.service.syncPendingChangesNow();
      final target = await _Device.create(drive);
      final downloading = Completer<void>();
      final release = Completer<void>();
      drive.beforeTimetableDownload = () async {
        downloading.complete();
        await release.future;
      };
      final operation = target.service.checkForRemoteChangesNow();
      final rejected = expectLater(
        operation,
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await downloading.future;
      target.auth.email = 'other@example.com';
      await target.settings.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      release.complete();
      await rejected;
      expect(target.store.classes, isEmpty);
      expect(
        target.settings.driveChangePageToken('tester@example.com'),
        isNull,
      );
    },
  );

  test('a local edit while stop waits cannot restart automatic sync', () async {
    final drive = _TimetableDrive();
    final source = await _Device.create(drive);
    await source.store.save(_course('remote'));
    await source.service.syncPendingChangesNow();
    final target = await _Device.create(drive, automatic: true);
    await target.service.startListeningOnly(flushPendingChanges: false);
    final downloading = Completer<void>();
    final release = Completer<void>();
    drive.beforeTimetableDownload = () async {
      downloading.complete();
      await release.future;
    };
    final operation = target.service.checkForRemoteChangesNow();
    final rejected = expectLater(
      operation,
      throwsA(isA<GoogleDriveAuthException>()),
    );
    await downloading.future;
    final writesBeforeStop = drive.writes.length;
    final stopped = target.service.stop();
    await target.store.save(_course('pending-after-stop'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    release.complete();
    await rejected;
    await stopped;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(drive.writes, hasLength(writesBeforeStop));
    expect(target.store.classes.single.id, 'pending-after-stop');
    expect(target.store.hasPendingSync, isTrue);
  });

  test(
    'a mismatched restored Google session cannot receive linked account data',
    () async {
      final drive = _TimetableDrive();
      final device = await _Device.create(drive);
      await device.store.save(_course('private-course'));
      device.auth.email = 'another-account@example.com';

      await expectLater(
        device.service.syncPendingChangesNow(),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      expect(drive.requests, isEmpty);
      expect(drive.files, isEmpty);
      expect(device.store.classes.single.id, 'private-course');
      expect(device.store.hasPendingSync, isTrue);
      expect(device.service.statusNotifier.value.lastSyncedAt, isNull);
    },
  );

  test(
    'legacy local timetable migrates without replacing existing cloud courses',
    () async {
      final drive = _TimetableDrive();
      final source = await _Device.create(drive);
      await source.store.save(_course('remote'));
      await source.service.syncPendingChangesNow();
      final migrated = await _Device.create(
        drive,
        initial: {
          TimetableStore.storageKey: jsonEncode({
            'version': 1,
            'activeYear': 2026,
            'activeSemester': '2',
            'classes': [_course('legacy').toJson()],
            'termNames': {
              '2026': {'2': '기존 시간표'},
            },
          }),
        },
      );

      expect(migrated.store.hasPendingSync, isTrue);
      await migrated.service.start();
      expect(migrated.store.classes.map((c) => c.id).toSet(), {
        'remote',
        'legacy',
      });
      expect(migrated.store.activeName, '기존 시간표');
      expect(await migrated.service.hasPendingChanges(), isFalse);
      final fresh = await _Device.create(drive);
      await fresh.service.restoreNow();
      expect(fresh.store.classes.map((c) => c.id).toSet(), {
        'remote',
        'legacy',
      });
    },
  );

  test(
    'ordinary event changes do not upload a synchronized timetable',
    () async {
      final drive = _TimetableDrive();
      final device = await _Device.create(drive);
      await device.store.save(_course('course'));
      await device.service.syncPendingChangesNow();
      drive.writes.clear();
      final event = CalendarEvent(
        id: 'event',
        title: 'Ordinary event',
        startAt: DateTime(2026, 9, 25, 9),
        endAt: DateTime(2026, 9, 25, 10),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: DateTime.utc(2026, 9, 25),
        updatedAt: DateTime.utc(2026, 9, 25),
        syncStatus: 'pending',
      );
      await device.events.save(event);
      await device.service.queueEventUpsert(event);
      await device.service.syncPendingChangesNow();

      expect(drive.writes, ['daily-sync-v2-event-event.json']);
      expect(device.store.classes.single.id, 'course');
      expect(await device.service.hasPendingChanges(), isFalse);
    },
  );
}

Map<String, Object?> _envelope(TimetableSyncDocument document) => {
  'schemaVersion': 2,
  'type': 'timetable',
  'document': document.toJson(),
};

TimetableClass _course(
  String id, {
  String? title,
  LectureMode mode = LectureMode.inPerson,
}) => TimetableClass(
  id: id,
  title: title ?? id,
  academicYear: 2026,
  semester: '2',
  defaultMode: mode,
  meetings: const [
    ClassMeeting(
      id: 'meeting',
      weekday: 1,
      startMinute: 540,
      endMinute: 600,
      classroom: '공학관 101',
    ),
  ],
);

Future<void> _until(bool Function() done) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('The queued timetable change did not complete');
}

class _Device {
  _Device(
    this.preferences,
    this.settings,
    this.auth,
    this.database,
    this.events,
    this.service,
    this.client,
  );
  final SharedPreferences preferences;
  final SettingsRepository settings;
  final _Auth auth;
  final AppDatabase database;
  final DriftEventRepository events;
  final GoogleDriveSyncService service;
  final http.Client client;
  bool _closed = false;
  TimetableStore get store => settings.timetableStore;
  static int _serial = 0;

  static Future<_Device> create(
    _TimetableDrive drive, {
    bool automatic = false,
    Map<String, Object> initial = const {},
    Map<String, _TimetableDrive>? accountDrives,
  }) async {
    SharedPreferences.setMockInitialValues({
      'deviceId': 'device-${++_serial}',
      ...initial,
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences: preferences);
    await settings.saveGoogleAccount(
      const GoogleAccount(email: 'tester@example.com'),
    );
    final auth = _Auth();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final events = DriftEventRepository(database);
    final client = MockClient(
      (request) => (accountDrives?[auth.email] ?? drive).handle(request),
    );
    final service = GoogleDriveSyncService(
      driveRequestDelay: Duration.zero,
      authService: auth,
      eventRepository: events,
      notificationService: _Notifications(),
      settingsRepository: settings,
      httpClient: client,
      backupRestoreDelay: Duration.zero,
      changeSyncDelay: automatic ? Duration.zero : const Duration(days: 1),
      automaticRetryDelays: const [],
    );
    final device = _Device(
      preferences,
      settings,
      auth,
      database,
      events,
      service,
      client,
    );
    addTearDown(device.close);
    return device;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await service.stop();
    service.dispose();
    client.close();
    await auth.changes.close();
    await database.close();
  }
}

class _TimetableDrive {
  final files =
      <String, ({String name, Map<String, Object?> data, int version})>{};
  final changes = <Map<String, Object?>>[];
  final requests = <http.Request>[];
  final writes = <String>[];
  FutureOr<void> Function()? beforeWrite;
  Future<void> Function()? beforeTimetableDownload;
  int preconditionFailures = 0;
  int timetableDownloads = 0;
  String get cursor => '${changes.length}';

  void seed(String id, String name, Map<String, Object?> data) {
    files[id] = (
      name: name,
      data: data,
      version: (files[id]?.version ?? 0) + 1,
    );
    changes.add({
      'fileId': id,
      'removed': false,
      'file': {'id': id, 'name': name, 'trashed': false},
    });
  }

  Map<String, Object?> payload(String name) =>
      files.values.firstWhere((file) => file.name == name).data;

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    final id = request.url.pathSegments.last;
    if (request.method == 'GET' && path == '/drive/v3/changes/startPageToken') {
      return _json({'startPageToken': cursor});
    }
    if (request.method == 'GET' && path == '/drive/v3/changes') {
      final previous = int.parse(request.url.queryParameters['pageToken']!);
      return _json({
        'changes': changes.skip(previous).toList(),
        'newStartPageToken': cursor,
      });
    }
    if (request.method == 'GET' && path == '/drive/v3/files') {
      final query = request.url.queryParameters['q'] ?? '';
      final equals = RegExp(
        "name = '([^']+)'",
      ).allMatches(query).map((match) => match[1]!).toSet();
      final prefixes = RegExp(
        "name contains '([^']+)'",
      ).allMatches(query).map((match) => match[1]!);
      return _json({
        'files': [
          for (final entry in files.entries)
            if (equals.contains(entry.value.name) ||
                prefixes.any(entry.value.name.contains))
              {'id': entry.key, 'name': entry.value.name},
        ],
      });
    }
    if (request.method == 'GET' && path.startsWith('/drive/v3/files/')) {
      final file = files[id];
      if (file == null) return http.Response('', 404);
      final snapshot = _json(file.data);
      if (file.name == _timetableFile) {
        timetableDownloads++;
        final action = beforeTimetableDownload;
        beforeTimetableDownload = null;
        await action?.call();
      }
      return snapshot;
    }
    if (request.method == 'GET' && path.startsWith('/drive/v2/files/')) {
      final file = files[id];
      if (file == null) return http.Response('', 404);
      return _json({
        'etag': '"${file.version}"',
        'md5Checksum': md5
            .convert(utf8.encode(jsonEncode(file.data)))
            .toString(),
      });
    }
    if (request.method == 'PUT') {
      final action = beforeWrite;
      beforeWrite = null;
      await action?.call();
      final file = files[id];
      if (file == null) return http.Response('', 404);
      if (request.headers['if-match'] != '"${file.version}"') {
        preconditionFailures++;
        return http.Response('', 412);
      }
      writes.add(file.name);
      seed(id, file.name, jsonDecode(request.body) as Map<String, Object?>);
      return _json({'id': id});
    }
    if (request.method == 'POST') {
      final boundary = request.headers['content-type']!.split('boundary=').last;
      final jsonParts = request.body
          .split('--$boundary')
          .where((part) => part.contains('\r\n\r\n'))
          .map(
            (part) =>
                jsonDecode(part.substring(part.indexOf('\r\n\r\n') + 4).trim())
                    as Map<String, Object?>,
          )
          .toList();
      final name = jsonParts.first['name'] as String;
      expect(jsonParts.first['parents'], ['appDataFolder']);
      final key = name == _timetableFile
          ? 'timetable'
          : 'created-${files.length}';
      writes.add(name);
      seed(key, name, jsonParts.last);
      return _json({'id': key});
    }
    return http.Response('Unexpected request: ${request.method} $path', 500);
  }
}

http.Response _json(Map<String, Object?> data) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Auth extends GoogleDriveAuthService {
  String email = 'tester@example.com';
  final changes = StreamController<GoogleDriveAccount?>.broadcast();
  @override
  GoogleDriveAccount get currentAccount => GoogleDriveAccount(email: email);
  @override
  Stream<GoogleDriveAccount?> get accountChanges => changes.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async => const {'Authorization': 'Bearer test-token'};
}

class _Notifications implements NotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {}
  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {}
  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
  @override
  Future<void> cancelMorningBriefing() async {}
  @override
  Future<int> pendingNotificationCount() async => 0;
  @override
  Future<String> permissionSummary() async => '';
}
