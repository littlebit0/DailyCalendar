import 'dart:async';
import 'dart:convert';

import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restore sync downloads v2 event files without uploading', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([
            {
              'id': 'remote-event-1',
              'name': 'daily-sync-v2-event-iphone-all-day.json',
            },
            {
              'id': 'remote-event-2',
              'name': 'daily-sync-v2-event-iphone-all-day-offset.json',
            },
          ]);
        }
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-event-1') {
        return _jsonResponse(
          _eventFileJson(
            id: 'iphone-all-day',
            title: '6.1 평일외출',
            startAt: '2026-06-01T00:00:00.000Z',
            endAt: '2026-06-02T00:00:00.000Z',
          ),
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-event-2') {
        return _jsonResponse(
          _eventFileJson(
            id: 'iphone-all-day-offset',
            title: '6.5 평일외출',
            startAt: '2026-06-05T00:00:00.000+14:00',
            endAt: '2026-06-06T00:00:00.000+14:00',
          ),
        );
      }
      if (request.url.path.startsWith('/upload/drive/v3/files')) {
        fail('restore sync must not upload Google Drive files');
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.restoreNow();

    final saved = {for (final event in repository.events) event.id: event};
    expect(saved['iphone-all-day']!.allDay, isTrue);
    expect(saved['iphone-all-day']!.startAt, DateTime(2026, 6, 1));
    expect(saved['iphone-all-day']!.endAt, DateTime(2026, 6, 2));
    expect(saved['iphone-all-day-offset']!.allDay, isTrue);
    expect(saved['iphone-all-day-offset']!.startAt, DateTime(2026, 6, 5));
    expect(saved['iphone-all-day-offset']!.endAt, DateTime(2026, 6, 6));
    expect(notificationService.scheduled.length, 2);
    expect(notificationService.scheduled.first.startAt, DateTime(2026, 6, 1));
    expect(
      requests.any(
        (request) => request.url.toString().contains('daily-sync-v1'),
      ),
      isFalse,
    );
  });

  test(
    'manual restore defers a scheduled backup until restore completes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final pending = _event(
        id: 'pending-before-restore',
        title: '복원 전 로컬 변경',
        startAt: DateTime.utc(2026, 8, 21, 9),
        endAt: DateTime.utc(2026, 8, 21, 10),
        updatedAt: DateTime.utc(2026, 8, 21, 8),
        syncStatus: 'pending',
      );
      await repository.save(pending);

      final restoreStarted = Completer<void>();
      final releaseRestore = Completer<void>();
      final uploadRequests = <http.Request>[];
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            if (!restoreStarted.isCompleted) {
              restoreStarted.complete();
              await releaseRestore.future;
            }
            return _driveFiles([]);
          }
          if (query.contains('daily-sync-v2-event-')) {
            return _driveFiles([]);
          }
        }
        if (request.method == 'POST' &&
            request.url.path == '/upload/drive/v3/files') {
          uploadRequests.add(request);
          return _jsonResponse({'id': 'pending-before-restore-file'});
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
        changeSyncDelay: const Duration(milliseconds: 50),
      );
      addTearDown(service.dispose);

      await service.queueEventUpsert(pending);
      final restore = service.restoreNow();
      await restoreStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(uploadRequests, isEmpty);

      releaseRestore.complete();
      await restore;
      await Future<void>.delayed(Duration.zero);
      expect(uploadRequests, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(uploadRequests, hasLength(1));
    },
  );

  test(
    'manual restore leaves local settings and events unchanged on partial download failure',
    () async {
      SharedPreferences.setMockInitialValues({'weekStartsOnMonday': false});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final local = _event(
        id: 'local-before-failure',
        title: '로컬 보존 일정',
        startAt: DateTime.utc(2026, 8, 21, 9),
        endAt: DateTime.utc(2026, 8, 21, 10),
        updatedAt: DateTime.utc(2026, 8, 21, 8),
        syncStatus: 'pending',
      );
      await repository.save(local);
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([
              {'id': 'settings-file', 'name': 'daily-sync-v2-settings.json'},
            ]);
          }
          if (query.contains('daily-sync-v2-event-')) {
            return _driveFiles([
              {
                'id': 'valid-event-file',
                'name': 'daily-sync-v2-event-valid-event.json',
              },
              {
                'id': 'broken-event-file',
                'name': 'daily-sync-v2-event-broken-event.json',
              },
            ]);
          }
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/settings-file') {
          return _jsonResponse({
            'schemaVersion': 2,
            'type': 'settings',
            'settings': {'weekStartsOnMonday': true},
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/valid-event-file') {
          return _jsonResponse(
            _eventFileJson(
              id: 'valid-event',
              title: '원격 일정',
              startAt: '2026-08-22T09:00:00.000Z',
              endAt: '2026-08-22T10:00:00.000Z',
            ),
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/broken-event-file') {
          return http.Response('server unavailable', 500);
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });
      final service = _service(
        repository: repository,
        notificationService: _FakeNotificationService(),
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await expectLater(
        service.restoreNow(),
        throwsA(isA<GoogleDriveSyncException>()),
      );

      expect(
        SettingsRepository(preferences: preferences).load().weekStartsOnMonday,
        isFalse,
      );
      expect(repository.events, hasLength(1));
      final preserved = await repository.findById(local.id);
      expect(preserved?.title, local.title);
      expect(preserved?.updatedAt, local.updatedAt);
      expect(preserved?.syncStatus, local.syncStatus);
      expect(await repository.findById('valid-event'), isNull);
      expect(requests.where((request) => request.method != 'GET'), isEmpty);
      expect(service.statusNotifier.value.message, '동기화 실패');
    },
  );

  test(
    'manual restore rolls settings back when atomic event merge fails',
    () async {
      SharedPreferences.setMockInitialValues({'weekStartsOnMonday': false});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository()..failAtomicRestore = true;
      final local = _event(
        id: 'local-before-transaction-failure',
        title: '트랜잭션 전 일정',
        startAt: DateTime.utc(2026, 8, 21, 9),
        endAt: DateTime.utc(2026, 8, 21, 10),
        updatedAt: DateTime.utc(2026, 8, 21, 8),
      );
      await repository.save(local);
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([
              {'id': 'settings-file', 'name': 'daily-sync-v2-settings.json'},
            ]);
          }
          if (query.contains('daily-sync-v2-event-')) {
            return _driveFiles([
              {
                'id': 'remote-event-file',
                'name': 'daily-sync-v2-event-remote-event.json',
              },
            ]);
          }
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/settings-file') {
          return _jsonResponse({
            'schemaVersion': 2,
            'type': 'settings',
            'settings': {'weekStartsOnMonday': true},
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/remote-event-file') {
          return _jsonResponse(
            _eventFileJson(
              id: 'remote-event',
              title: '원격 일정',
              startAt: '2026-08-22T09:00:00.000Z',
              endAt: '2026-08-22T10:00:00.000Z',
            ),
          );
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });
      final service = _service(
        repository: repository,
        notificationService: _FakeNotificationService(),
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await expectLater(service.restoreNow(), throwsA(isA<StateError>()));

      expect(
        SettingsRepository(preferences: preferences).load().weekStartsOnMonday,
        isFalse,
      );
      expect(repository.events, hasLength(1));
      final preserved = await repository.findById(local.id);
      expect(preserved?.title, local.title);
      expect(preserved?.updatedAt, local.updatedAt);
      expect(service.settingsRevisionNotifier.value, 0);
      expect(requests.where((request) => request.method != 'GET'), isEmpty);
    },
  );

  test(
    'backup-only event sync uploads only the changed v2 event file',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final changed = _event(
        id: 'queued-event',
        title: '6.20~21 캠핑 약속',
        startAt: DateTime(2026, 6, 20),
        endAt: DateTime(2026, 6, 22),
        updatedAt: DateTime(2026, 5, 30, 18),
        syncStatus: 'pending',
      ).copyWith(completed: true);
      await repository.save(changed);

      final uploadedEventBodies = <Map<String, Object?>>[];
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            fail('queued event sync must not touch the settings file');
          }
          if (query.contains('daily-sync-v2-event-queued-event.json')) {
            return _driveFiles([
              {
                'id': 'remote-queued-event',
                'name': 'daily-sync-v2-event-queued-event.json',
              },
            ]);
          }
          if (query.contains('name contains')) {
            fail('queued event sync must not list every event file');
          }
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/remote-queued-event') {
          return _jsonResponse(
            _eventFileJson(
              id: changed.id,
              title: '이전 일정',
              startAt: changed.startAt.toIso8601String(),
              endAt: changed.endAt.toIso8601String(),
              updatedAt: '2025-05-30T17:00:00.000Z',
              sourceDeviceId: 'remote-device',
            ),
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/upload/drive/v3/files/remote-queued-event') {
          uploadedEventBodies.add(
            jsonDecode(request.body) as Map<String, Object?>,
          );
          return _jsonResponse({'id': 'remote-queued-event'});
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.backupNow(eventIds: {changed.id});

      expect(uploadedEventBodies, hasLength(1));
      final event = uploadedEventBodies.single['event'] as Map<String, Object?>;
      expect(event['id'], 'queued-event');
      expect(event['startDate'], '2026-06-20');
      expect(event['endDate'], '2026-06-22');
      expect(event['title'], '6.20~21 캠핑 약속');
      expect(event['completed'], isTrue);
      expect((await repository.findById('queued-event'))!.syncStatus, 'synced');
      expect(
        requests.any(
          (request) => request.url.toString().contains('daily-sync-v1'),
        ),
        isFalse,
      );
    },
  );

  test(
    'migration download reads Todo completion without mutating local data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          return _driveFiles([
            {
              'id': 'migration-event-file',
              'name': 'daily-sync-v2-event-migration-event.json',
            },
          ]);
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/migration-event-file') {
          return _jsonResponse(
            _eventFileJson(
              id: 'migration-event',
              title: '완료한 일정',
              startAt: '2026-08-21T09:00:00.000Z',
              endAt: '2026-08-21T10:00:00.000Z',
              completed: true,
            ),
          );
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });
      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      final events = await service.downloadEventsForMigration();

      expect(events, hasLength(1));
      expect(events!.single.completed, isTrue);
      expect(await repository.allEventsForSync(), isEmpty);
    },
  );

  test(
    'queued settings change uploads the settings file without an event',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.save(
        settingsRepository.load().copyWith(
          calendarManualEventOrders: {
            '2026-08-21': CalendarManualEventOrder(
              eventKeys: const ['second', 'first'],
              updatedAt: DateTime.utc(2026, 8, 21, 3),
              deviceId: 'local-device',
            ),
          },
        ),
      );
      final uploaded = <String>[];
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([]);
          }
        }
        if (request.method == 'POST' &&
            request.url.path == '/upload/drive/v3/files') {
          uploaded.add(request.body);
          return _jsonResponse({'id': 'settings-file'});
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });
      final service = _service(
        repository: _MemoryEventRepository(),
        notificationService: _FakeNotificationService(),
        preferences: preferences,
        httpClient: httpClient,
        changeSyncDelay: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      await service.syncPendingChangesNow();

      expect(uploaded, hasLength(1));
      expect(uploaded.single, contains('calendarManualEventOrders'));
      expect(uploaded.single, contains('2026-08-21'));
      expect(uploaded.single, contains('second'));
      expect(settingsRepository.hasPendingSettingsSync, isFalse);
    },
  );

  test('settings backup does not upload unchanged event files', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    await repository.save(
      _event(
        id: 'unchanged-event',
        title: '변경 없는 일정',
        startAt: DateTime(2026, 6, 10),
        endAt: DateTime(2026, 6, 11),
        updatedAt: DateTime(2026, 6, 1, 9),
      ),
    );
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([]);
        }
        fail('settings backup must not list event files');
      }
      if (request.method == 'POST' &&
          request.url.path == '/upload/drive/v3/files') {
        return _jsonResponse({'id': 'settings-file'});
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.backupNow();

    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(
      requests.any((request) => request.body.contains('unchanged-event')),
      isFalse,
    );
  });

  test(
    'pending category color sync uploads matching event and settings snapshots',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final category = EventCategory.custom(
        label: '업무',
        colorValue: 0xff7c3aed,
      );
      await settingsRepository.save(
        AppSettings(categories: [EventCategory.basic, category]),
      );
      await repository.save(
        _event(
          id: 'category-color-event',
          title: '최종 색상 일정',
          startAt: DateTime(2026, 7, 30, 10),
          endAt: DateTime(2026, 7, 30, 11),
          updatedAt: DateTime(2026, 7, 29, 12),
          syncStatus: 'pending',
        ).copyWith(category: category, colorValue: category.colorValue),
      );

      final uploadOrder = <String>[];
      Map<String, Object?>? uploadedEvent;
      Map<String, Object?>? uploadedSettings;
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-event-category-color-event.json')) {
            return _driveFiles([
              {
                'id': 'category-color-event-file',
                'name': 'daily-sync-v2-event-category-color-event.json',
              },
            ]);
          }
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([
              {'id': 'settings-file', 'name': 'daily-sync-v2-settings.json'},
            ]);
          }
        }
        if (request.method == 'PATCH' &&
            request.url.path ==
                '/upload/drive/v3/files/category-color-event-file') {
          uploadOrder.add('event');
          uploadedEvent =
              (jsonDecode(request.body) as Map<String, Object?>)['event']
                  as Map<String, Object?>;
          return _jsonResponse({'id': 'category-color-event-file'});
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/category-color-event-file') {
          return _jsonResponse(
            _eventFileJson(
              id: 'category-color-event',
              title: '이전 색상 일정',
              startAt: '2026-07-30T10:00:00.000',
              endAt: '2026-07-30T11:00:00.000',
              updatedAt: '2025-07-29T11:00:00.000Z',
              sourceDeviceId: 'remote-device',
            ),
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/upload/drive/v3/files/settings-file') {
          uploadOrder.add('settings');
          uploadedSettings =
              (jsonDecode(request.body) as Map<String, Object?>)['settings']
                  as Map<String, Object?>;
          return _jsonResponse({'id': 'settings-file'});
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.syncPendingChangesNow();

      expect(uploadOrder, ['event', 'settings']);
      expect(uploadedEvent?['colorValue'], category.colorValue);
      final categories = uploadedSettings?['categories'] as List<Object?>;
      final uploadedCategory = categories
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .singleWhere((item) => item['id'] == category.id);
      expect(uploadedCategory['colorValue'], category.colorValue);
      expect(settingsRepository.hasPendingSettingsSync, isFalse);
      expect(
        (await repository.findById('category-color-event'))?.syncStatus,
        'synced',
      );
    },
  );

  test('restore keeps a locally pending category color', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final localCategory = EventCategory.custom(
      label: '업무',
      colorValue: 0xffec4899,
    );
    await settingsRepository.save(
      AppSettings(categories: [EventCategory.basic, localCategory]),
    );

    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          fail('pending local settings must not request an older remote file');
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([]);
        }
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.restoreNow();

    final savedCategory = settingsRepository.load().categories.singleWhere(
      (category) => category.id == localCategory.id,
    );
    expect(savedCategory.colorValue, localCategory.colorValue);
    expect(settingsRepository.hasPendingSettingsSync, isTrue);
    expect(service.settingsRevisionNotifier.value, 0);
  });

  test('start flushes locally pending v2 event files after restore', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final pending = _event(
      id: 'restart-pending',
      title: '6.30 전역',
      startAt: DateTime(2026, 6, 30),
      endAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 6, 1, 8),
      syncStatus: 'pending',
    );
    await repository.save(pending);

    final uploadedEventBodies = <Map<String, Object?>>[];
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([]);
        }
        if (query.contains(
          "name = 'daily-sync-v2-event-restart-pending.json'",
        )) {
          return _driveFiles([
            {
              'id': 'restart-pending-file',
              'name': 'daily-sync-v2-event-restart-pending.json',
            },
          ]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([]);
        }
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/restart-pending-file') {
        uploadedEventBodies.add(
          jsonDecode(request.body) as Map<String, Object?>,
        );
        return _jsonResponse({'id': 'restart-pending-file'});
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/restart-pending-file') {
        return _jsonResponse(
          _eventFileJson(
            id: pending.id,
            title: '이전 일정',
            startAt: pending.startAt.toIso8601String(),
            endAt: pending.endAt.toIso8601String(),
            updatedAt: '2025-06-01T07:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.start();

    expect(uploadedEventBodies, hasLength(1));
    final event = uploadedEventBodies.single['event'] as Map<String, Object?>;
    expect(event['id'], 'restart-pending');
    expect(event['startDate'], '2026-06-30');
    expect(
      (await repository.findById('restart-pending'))!.syncStatus,
      'synced',
    );
  });

  test('pending change flush cancels the delayed event timer', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final changed = _event(
      id: 'queued-before-exit',
      title: '6.6 면회외출',
      startAt: DateTime(2026, 6, 6),
      endAt: DateTime(2026, 6, 7),
      updatedAt: DateTime(2026, 6, 1, 9),
      syncStatus: 'pending',
    );
    await repository.save(changed);

    final uploadedEventBodies = <Map<String, Object?>>[];
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          fail('pending event flush must not touch the settings file');
        }
        if (query.contains(
          "name = 'daily-sync-v2-event-queued-before-exit.json'",
        )) {
          return _driveFiles([
            {
              'id': 'queued-before-exit-file',
              'name': 'daily-sync-v2-event-queued-before-exit.json',
            },
          ]);
        }
        if (query.contains('name contains')) {
          fail('pending event flush must not list every event file');
        }
      }
      if (request.method == 'PATCH' &&
          request.url.path ==
              '/upload/drive/v3/files/queued-before-exit-file') {
        uploadedEventBodies.add(
          jsonDecode(request.body) as Map<String, Object?>,
        );
        return _jsonResponse({'id': 'queued-before-exit-file'});
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/queued-before-exit-file') {
        return _jsonResponse(
          _eventFileJson(
            id: changed.id,
            title: '이전 일정',
            startAt: changed.startAt.toIso8601String(),
            endAt: changed.endAt.toIso8601String(),
            updatedAt: '2025-06-01T08:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
      changeSyncDelay: const Duration(hours: 1),
    );
    addTearDown(service.dispose);

    await service.queueEventUpsert(changed);
    await service.syncPendingChangesNow();
    await Future<void>.delayed(Duration.zero);

    expect(uploadedEventBodies, hasLength(1));
    final event = uploadedEventBodies.single['event'] as Map<String, Object?>;
    expect(event['id'], 'queued-before-exit');
    expect(event['startDate'], '2026-06-06');
    expect(
      (await repository.findById('queued-before-exit'))!.syncStatus,
      'synced',
    );
  });

  test('full sync backs up before restore after the configured gap', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final localEvent = _event(
      id: 'local-event',
      title: 'local first',
      startAt: DateTime(2026, 6, 10),
      endAt: DateTime(2026, 6, 11),
      updatedAt: DateTime(2026, 6, 1, 9),
      syncStatus: 'pending',
    );
    await repository.save(localEvent);
    await repository.save(
      _event(
        id: 'already-synced',
        title: 'unchanged local event',
        startAt: DateTime(2026, 6, 8),
        endAt: DateTime(2026, 6, 9),
        updatedAt: DateTime(2026, 6, 1, 8),
      ),
    );

    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([
            {
              'id': 'local-file',
              'name': 'daily-sync-v2-event-local-event.json',
            },
            {
              'id': 'remote-file',
              'name': 'daily-sync-v2-event-remote-event.json',
            },
          ]);
        }
      }
      if (request.method == 'POST' &&
          request.url.path == '/upload/drive/v3/files') {
        return _jsonResponse({'id': 'settings-file'});
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/local-file') {
        return _jsonResponse({'id': 'local-file'});
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/local-file') {
        return _jsonResponse(
          _eventFileJson(
            id: 'local-event',
            title: 'local first',
            startAt: '2026-06-10T00:00:00.000',
            endAt: '2026-06-11T00:00:00.000',
            updatedAt: '2025-06-01T09:00:00.000Z',
          ),
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-file') {
        return _jsonResponse(
          _eventFileJson(
            id: 'remote-event',
            title: 'remote after',
            startAt: '2026-06-12T00:00:00.000',
            endAt: '2026-06-13T00:00:00.000',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
      backupRestoreDelay: const Duration(milliseconds: 20),
    );
    addTearDown(service.dispose);

    final stopwatch = Stopwatch()..start();
    await service.syncNow();
    stopwatch.stop();

    final uploadIndex = requests.indexWhere(
      (request) =>
          request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/local-file',
    );
    final restoreDownloadIndex = requests.indexWhere(
      (request) =>
          request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-file',
    );
    expect(uploadIndex, isNonNegative);
    expect(restoreDownloadIndex, isNonNegative);
    expect(uploadIndex, lessThan(restoreDownloadIndex));
    expect(
      stopwatch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 20)),
    );
    expect(await repository.findById('remote-event'), isNotNull);
    expect((await repository.findById('local-event'))!.syncStatus, 'synced');
    expect(
      requests
          .where((request) => request.method == 'POST')
          .any((request) => request.body.contains('already-synced')),
      isFalse,
    );
  });

  test('queued sync callers wait for their own request to finish', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final releaseSecond = Completer<void>();
    var settingsRequestCount = 0;
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          settingsRequestCount += 1;
          if (settingsRequestCount == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          } else if (settingsRequestCount == 2) {
            secondStarted.complete();
            await releaseSecond.future;
          }
          return _driveFiles([]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([]);
        }
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    final first = service.restoreNow();
    await firstStarted.future;
    final second = service.restoreNow();
    final third = service.restoreNow();
    var secondCompleted = false;
    var thirdCompleted = false;
    unawaited(second.then((_) => secondCompleted = true));
    unawaited(third.then((_) => thirdCompleted = true));

    releaseFirst.complete();
    await first;
    await secondStarted.future;
    expect(secondCompleted, isFalse);
    expect(thirdCompleted, isFalse);

    releaseSecond.complete();
    await second;
    await third;
    expect(secondCompleted, isTrue);
    expect(thirdCompleted, isTrue);
    expect(settingsRequestCount, 2);
  });

  test(
    'unchanged restored event skips database and notification work',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final unchanged = _event(
        id: 'unchanged-remote',
        title: '같은 일정',
        startAt: DateTime.utc(2026, 6, 20),
        endAt: DateTime.utc(2026, 6, 21),
        updatedAt: DateTime.utc(2026, 5, 29),
      );
      await repository.save(unchanged);
      final beforeRestore = await repository.findById(unchanged.id);

      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([]);
          }
          if (query.contains('daily-sync-v2-event-')) {
            return _driveFiles([
              {
                'id': 'unchanged-remote-file',
                'name': 'daily-sync-v2-event-unchanged-remote.json',
              },
            ]);
          }
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/unchanged-remote-file') {
          return _jsonResponse(
            _eventFileJson(
              id: unchanged.id,
              title: unchanged.title,
              startAt: unchanged.startAt.toIso8601String(),
              endAt: unchanged.endAt.toIso8601String(),
              updatedAt: unchanged.updatedAt.toIso8601String(),
            ),
          );
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.restoreNow();

      expect(notificationService.scheduled, isEmpty);
      expect(
        identical(await repository.findById(unchanged.id), beforeRestore),
        isTrue,
      );
    },
  );

  test('startListeningOnly does not run an initial restore', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.startListeningOnly();

    expect(requests, isEmpty);
  });

  test(
    'sync asks for Google Drive connection when auth headers are missing',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        authService: _MissingHeaderGoogleDriveAuthService(),
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await expectLater(
        service.syncNow(),
        throwsA(
          isA<GoogleDriveAuthException>().having(
            (error) => error.message,
            'message',
            'Google Drive 연결이 필요합니다.',
          ),
        ),
      );

      expect(service.statusNotifier.value.message, '동기화 실패');
      expect(service.statusNotifier.value.error, 'Google Drive 연결이 필요합니다.');
      expect(requests, isEmpty);
    },
  );

  test(
    'restore settings updates category colors and notifies listeners',
    () async {
      SharedPreferences.setMockInitialValues({
        'appTextSize': AppTextSize.large.name,
        'appStartView': AppStartView.quickView.name,
        'weekDayLayoutMode': WeekDayLayoutMode.schedule.name,
        'categories': jsonEncode([
          {
            'id': 'basic',
            'label': '기본',
            'colorValue': EventCategory.basic.colorValue,
            'locked': false,
          },
          {
            'id': 'custom-work',
            'label': '업무',
            'colorValue': 0xff2563eb,
            'locked': false,
          },
          {
            'id': 'holiday',
            'label': '공휴일',
            'colorValue': EventCategory.holiday.colorValue,
            'locked': true,
          },
        ]),
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([
              {'id': 'settings-file', 'name': 'daily-sync-v2-settings.json'},
            ]);
          }
          if (query.contains('daily-sync-v2-event-')) {
            return _driveFiles([]);
          }
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/settings-file') {
          return _jsonResponse({
            'schemaVersion': 2,
            'type': 'settings',
            'settings': {
              'defaultReminderMinutesList': [0, 10, 60],
              'categories': [
                {
                  'id': 'basic',
                  'label': '기본',
                  'colorValue': EventCategory.basic.colorValue,
                  'locked': false,
                },
                {
                  'id': 'custom-work',
                  'label': '업무',
                  'colorValue': 0xff10b981,
                  'locked': false,
                },
                {
                  'id': 'holiday',
                  'label': '공휴일',
                  'colorValue': 0xffa855f7,
                  'locked': true,
                },
              ],
              'calendarHolidayBackgroundEnabled': false,
              'calendarEventTitleAlignment':
                  CalendarEventTitleAlignment.center.name,
              'calendarEventSortPriority':
                  CalendarEventSortPriority.category.name,
            },
          });
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      expect(service.settingsRevisionNotifier.value, 0);
      await service.restoreNow();

      final restored = SettingsRepository(preferences: preferences).load();
      final work = restored.categories.singleWhere(
        (category) => category.id == 'custom-work',
      );
      final holiday = restored.categories.singleWhere(
        (category) => category.id == EventCategory.holiday.id,
      );
      expect(work.colorValue, 0xff10b981);
      expect(holiday.colorValue, 0xffa855f7);
      expect(holiday.locked, isTrue);
      expect(restored.calendarHolidayBackgroundEnabled, isFalse);
      expect(
        restored.calendarEventTitleAlignment,
        CalendarEventTitleAlignment.center,
      );
      expect(
        restored.calendarEventSortPriority,
        CalendarEventSortPriority.category,
      );
      expect(restored.defaultReminderMinutesList, [0, 10, 60]);
      expect(restored.appTextSize, AppTextSize.large);
      expect(restored.appStartView, AppStartView.quickView);
      expect(restored.weekDayLayoutMode, WeekDayLayoutMode.schedule);
      expect(service.settingsRevisionNotifier.value, 1);
    },
  );

  test('restore settings applies an explicitly synced app text size', () async {
    SharedPreferences.setMockInitialValues({
      'appTextSize': AppTextSize.large.name,
      'appStartView': AppStartView.quickView.name,
      'weekDayLayoutMode': WeekDayLayoutMode.list.name,
      'calendarHolidayBackgroundEnabled': false,
      'calendarEventTitleAlignment': CalendarEventTitleAlignment.center.name,
      'calendarEventSortPriority': CalendarEventSortPriority.category.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([
            {'id': 'settings-file', 'name': 'daily-sync-v2-settings.json'},
          ]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([]);
        }
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/settings-file') {
        return _jsonResponse({
          'schemaVersion': 2,
          'type': 'settings',
          'settings': {
            'appTextSize': AppTextSize.basic.name,
            'appStartView': AppStartView.calendar.name,
            'weekDayLayoutMode': WeekDayLayoutMode.schedule.name,
          },
        });
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.restoreNow();

    final restored = SettingsRepository(preferences: preferences).load();
    expect(restored.appTextSize, AppTextSize.basic);
    expect(restored.appStartView, AppStartView.calendar);
    expect(restored.weekDayLayoutMode, WeekDayLayoutMode.schedule);
    expect(restored.calendarHolidayBackgroundEnabled, isFalse);
    expect(
      restored.calendarEventTitleAlignment,
      CalendarEventTitleAlignment.center,
    );
    expect(
      restored.calendarEventSortPriority,
      CalendarEventSortPriority.category,
    );
  });

  test(
    'completed upload does not overwrite a newer local event edit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final uploaded = _event(
        id: 'editing-event',
        title: '회의',
        startAt: DateTime(2026, 7, 17, 10),
        endAt: DateTime(2026, 7, 17, 11),
        updatedAt: DateTime(2026, 7, 17, 9),
        syncStatus: 'pending',
      );
      await repository.save(uploaded);

      final newer = uploaded.copyWith(
        memo: '최신 메모',
        url: 'https://example.com/latest',
        weather: '맑음',
        updatedAt: DateTime(2026, 7, 17, 9, 1),
        syncStatus: 'pending',
      );
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          return _driveFiles([
            {
              'id': 'editing-event-file',
              'name': 'daily-sync-v2-event-editing-event.json',
            },
          ]);
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/editing-event-file') {
          return _jsonResponse(
            _eventFileJson(
              id: uploaded.id,
              title: '이전 회의',
              startAt: uploaded.startAt.toIso8601String(),
              endAt: uploaded.endAt.toIso8601String(),
              updatedAt: '2025-07-17T08:59:00.000Z',
              sourceDeviceId: 'remote-device',
            ),
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/upload/drive/v3/files/editing-event-file') {
          await repository.save(newer);
          return _jsonResponse({'id': 'editing-event-file'});
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.backupNow(eventIds: {'editing-event'});

      final saved = await repository.findById('editing-event');
      expect(saved?.memo, '최신 메모');
      expect(saved?.url, 'https://example.com/latest');
      expect(saved?.weather, '맑음');
      expect(saved?.syncStatus, 'pending');
    },
  );

  test(
    'restore snapshot does not overwrite a newer local category color',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final original = _event(
        id: 'category-race',
        title: '분류 색상 변경 일정',
        startAt: DateTime(2026, 7, 29, 10),
        endAt: DateTime(2026, 7, 29, 11),
        updatedAt: DateTime(2026, 7, 29, 9),
      );
      await repository.save(original);

      final latestCategory = EventCategory.custom(
        label: '업무',
        colorValue: 0xff10b981,
      );
      final latest = original.copyWith(
        category: latestCategory,
        colorValue: latestCategory.colorValue,
        updatedAt: DateTime(2026, 7, 29, 9, 2),
        syncStatus: 'pending',
      );
      repository.beforeAtomicRestore = () async {
        repository.beforeAtomicRestore = null;
        await repository.save(latest);
      };

      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([]);
          }
          if (query.contains('daily-sync-v2-event-')) {
            return _driveFiles([
              {
                'id': 'category-race-file',
                'name': 'daily-sync-v2-event-category-race.json',
              },
            ]);
          }
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/category-race-file') {
          return _jsonResponse(
            _eventFileJson(
              id: original.id,
              title: original.title,
              startAt: original.startAt.toIso8601String(),
              endAt: original.endAt.toIso8601String(),
              updatedAt: DateTime(2026, 7, 29, 9, 1).toIso8601String(),
            ),
          );
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
        changeSyncDelay: const Duration(hours: 1),
      );
      addTearDown(service.dispose);

      await service.restoreNow();

      final saved = await repository.findById(original.id);
      expect(saved?.category.id, latestCategory.id);
      expect(saved?.colorValue, latestCategory.colorValue);
      expect(saved?.syncStatus, 'pending');
      expect(notificationService.scheduled, isEmpty);
    },
  );

  test('change detection restores only another device event', () async {
    SharedPreferences.setMockInitialValues({
      'deviceId': 'local-device',
      'driveChangeAccount': 'tester@example.com',
      'driveChangePageToken': 'token-1',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path == '/drive/v3/changes') {
        expect(request.url.queryParameters['pageToken'], 'token-1');
        expect(request.url.queryParameters['spaces'], 'appDataFolder');
        return _jsonResponse({
          'newStartPageToken': 'token-2',
          'changes': [
            {
              'fileId': 'external-event-file',
              'removed': false,
              'file': {
                'id': 'external-event-file',
                'name': 'daily-sync-v2-event-external-event.json',
              },
            },
          ],
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/external-event-file') {
        return _jsonResponse(
          _eventFileJson(
            id: 'external-event',
            title: '다른 기기 일정',
            startAt: '2026-07-30T00:00:00.000Z',
            endAt: '2026-07-31T00:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.checkForRemoteChangesNow();

    expect((await repository.findById('external-event'))?.title, '다른 기기 일정');
    expect(notificationService.scheduled, hasLength(1));
    expect(
      SettingsRepository(
        preferences: preferences,
      ).driveChangePageToken('tester@example.com'),
      'token-2',
    );
    expect(
      requests.any(
        (request) => request.url.path == '/drive/v3/changes/startPageToken',
      ),
      isFalse,
    );
  });

  test('change detection ignores the current device upload', () async {
    SharedPreferences.setMockInitialValues({
      'deviceId': 'local-device',
      'driveChangeAccount': 'tester@example.com',
      'driveChangePageToken': 'token-1',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final local = _event(
      id: 'own-event',
      title: '현재 기기 최신 일정',
      startAt: DateTime(2026, 7, 30),
      endAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 29, 15),
    );
    await repository.save(local);
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/changes') {
        return _jsonResponse({
          'newStartPageToken': 'token-2',
          'changes': [
            {
              'fileId': 'own-event-file',
              'removed': false,
              'file': {
                'id': 'own-event-file',
                'name': 'daily-sync-v2-event-own-event.json',
              },
            },
          ],
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/own-event-file') {
        return _jsonResponse(
          _eventFileJson(
            id: 'own-event',
            title: '원격에 기록된 동일 기기 파일',
            startAt: '2026-07-30T00:00:00.000Z',
            endAt: '2026-07-31T00:00:00.000Z',
            sourceDeviceId: 'local-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.checkForRemoteChangesNow();

    expect((await repository.findById('own-event'))?.title, local.title);
    expect(notificationService.scheduled, isEmpty);
    expect(service.statusNotifier.value.message, '최신 상태');
  });

  test(
    'initial change detection restores once and stores a baseline',
    () async {
      SharedPreferences.setMockInitialValues({'deviceId': 'local-device'});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      var startTokenRequests = 0;
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/changes/startPageToken') {
          startTokenRequests += 1;
          return _jsonResponse({'startPageToken': 'baseline-token'});
        }
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            return _driveFiles([]);
          }
          if (query.contains('daily-sync-v2-event-')) {
            return _driveFiles([]);
          }
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.checkForRemoteChangesNow();

      expect(startTokenRequests, 1);
      expect(
        SettingsRepository(
          preferences: preferences,
        ).driveChangePageToken('tester@example.com'),
        'baseline-token',
      );
    },
  );

  test(
    'resume restores external settings without uploading unchanged settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'deviceId': 'local-device',
        'driveChangeAccount': 'tester@example.com',
        'driveChangePageToken': 'token-1',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/changes') {
          return _jsonResponse({
            'newStartPageToken': 'token-2',
            'changes': [
              {
                'fileId': 'settings-file',
                'removed': false,
                'file': {
                  'id': 'settings-file',
                  'name': 'daily-sync-v2-settings.json',
                },
              },
            ],
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/settings-file') {
          return _jsonResponse({
            'schemaVersion': 2,
            'type': 'settings',
            'sourceDeviceId': 'remote-device',
            'settings': {'appTextSize': AppTextSize.large.name},
          });
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.syncOnResume();

      expect(
        SettingsRepository(preferences: preferences).load().appTextSize,
        AppTextSize.large,
      );
      expect(
        requests.any(
          (request) => request.method == 'POST' || request.method == 'PATCH',
        ),
        isFalse,
      );
    },
  );

  test('resume backs up before restoring external changes', () async {
    SharedPreferences.setMockInitialValues({
      'deviceId': 'local-device',
      'driveChangeAccount': 'tester@example.com',
      'driveChangePageToken': 'token-1',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final pending = _event(
      id: 'local-pending',
      title: '로컬 변경',
      startAt: DateTime(2026, 7, 30),
      endAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 29, 17),
      syncStatus: 'pending',
    );
    await repository.save(pending);
    final requestOrder = <String>[];
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        return _driveFiles([]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/upload/drive/v3/files') {
        requestOrder.add('backup');
        return _jsonResponse({'id': 'local-pending-file'});
      }
      if (request.method == 'GET' && request.url.path == '/drive/v3/changes') {
        requestOrder.add('detect');
        return _jsonResponse({
          'newStartPageToken': 'token-2',
          'changes': [
            {
              'fileId': 'external-event-file',
              'removed': false,
              'file': {
                'id': 'external-event-file',
                'name': 'daily-sync-v2-event-external-event.json',
              },
            },
          ],
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/external-event-file') {
        return _jsonResponse(
          _eventFileJson(
            id: 'external-event',
            title: '다른 기기 변경',
            startAt: '2026-07-31T00:00:00.000Z',
            endAt: '2026-08-01T00:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.syncOnResume();

    expect(requestOrder, ['backup', 'detect']);
    expect((await repository.findById(pending.id))?.syncStatus, 'synced');
    expect((await repository.findById('external-event'))?.title, '다른 기기 변경');
  });

  test('backup keeps a pending local event when remote is newer', () async {
    SharedPreferences.setMockInitialValues({'deviceId': 'local-device'});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final local = _event(
      id: 'conflict-event',
      title: '오래된 로컬 수정',
      startAt: DateTime(2026, 7, 30),
      endAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 29, 17),
      syncStatus: 'pending',
    );
    await repository.save(local);
    var uploadCount = 0;
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        return _driveFiles([
          {
            'id': 'conflict-event-file',
            'name': 'daily-sync-v2-event-conflict-event.json',
          },
        ]);
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/conflict-event-file') {
        return _jsonResponse(
          _eventFileJson(
            id: local.id,
            title: '더 최신인 다른 기기 수정',
            startAt: local.startAt.toIso8601String(),
            endAt: local.endAt.toIso8601String(),
            updatedAt: '2027-07-29T17:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      if (request.method == 'PATCH') {
        uploadCount += 1;
        return _jsonResponse({'id': 'conflict-event-file'});
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.backupNow(eventIds: {local.id});

    expect(uploadCount, 0);
    expect((await repository.findById(local.id))?.title, '오래된 로컬 수정');
    expect((await repository.findById(local.id))?.syncStatus, 'pending');
    expect(service.statusNotifier.value.message, '일부 백업 보류 · 먼저 복원 필요');
  });

  test('backup never applies a newer remote tombstone to local data', () async {
    SharedPreferences.setMockInitialValues({'deviceId': 'local-device'});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final local = _event(
      id: 'protected-event',
      title: '보존할 일정',
      startAt: DateTime(2026, 7, 30),
      endAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 29, 17),
      syncStatus: 'pending',
    );
    await repository.save(local);

    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        return _driveFiles([
          {
            'id': 'protected-event-file',
            'name': 'daily-sync-v2-event-protected-event.json',
          },
        ]);
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/protected-event-file') {
        return _jsonResponse(
          _eventFileJson(
            id: local.id,
            title: local.title,
            startAt: local.startAt.toIso8601String(),
            endAt: local.endAt.toIso8601String(),
            updatedAt: local.updatedAt.toIso8601String(),
            deletedAt: DateTime(2026, 7, 29, 18).toIso8601String(),
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.backupNow(eventIds: {local.id});

    final saved = await repository.findById(local.id);
    expect(saved?.deletedAt, isNull);
    expect(saved?.syncStatus, 'pending');
    expect(notificationService.cancelled, isEmpty);
    expect(service.statusNotifier.value.message, '일부 백업 보류 · 먼저 복원 필요');
  });

  test('failed automatic backup keeps pending data and retries', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final pending = _event(
      id: 'retry-event',
      title: '재시도 일정',
      startAt: DateTime(2026, 7, 30),
      endAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 29, 16),
      syncStatus: 'pending',
    );
    await repository.save(pending);
    var uploadAttempts = 0;
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        return _driveFiles([
          {
            'id': 'retry-event-file',
            'name': 'daily-sync-v2-event-retry-event.json',
          },
        ]);
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/retry-event-file') {
        uploadAttempts += 1;
        if (uploadAttempts == 1) {
          return http.Response('temporary server error', 503);
        }
        return _jsonResponse({'id': 'retry-event-file'});
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/retry-event-file') {
        return _jsonResponse(
          _eventFileJson(
            id: pending.id,
            title: '이전 일정',
            startAt: pending.startAt.toIso8601String(),
            endAt: pending.endAt.toIso8601String(),
            updatedAt: '2025-07-29T15:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
      automaticRetryDelays: const [Duration(milliseconds: 1)],
    );
    addTearDown(service.dispose);

    await expectLater(
      service.syncPendingChangesNow(),
      throwsA(isA<GoogleDriveSyncException>()),
    );
    expect((await repository.findById(pending.id))?.syncStatus, 'pending');

    for (var attempt = 0; attempt < 20 && uploadAttempts < 2; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(uploadAttempts, 2);
    expect((await repository.findById(pending.id))?.syncStatus, 'synced');
  });

  test(
    'successful change detection does not cancel a pending backup retry',
    () async {
      SharedPreferences.setMockInitialValues({
        'deviceId': 'local-device',
        'driveChangeAccount': 'tester@example.com',
        'driveChangePageToken': 'token-1',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final pending = _event(
        id: 'independent-retry',
        title: '독립 재시도',
        startAt: DateTime(2026, 7, 30),
        endAt: DateTime(2026, 7, 31),
        updatedAt: DateTime(2026, 7, 29, 18),
        syncStatus: 'pending',
      );
      await repository.save(pending);
      var uploadAttempts = 0;
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          return _driveFiles([]);
        }
        if (request.method == 'POST' &&
            request.url.path == '/upload/drive/v3/files') {
          uploadAttempts += 1;
          if (uploadAttempts == 1) {
            return http.Response('temporary server error', 503);
          }
          return _jsonResponse({'id': 'independent-retry-file'});
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/changes') {
          return _jsonResponse({
            'newStartPageToken': 'token-2',
            'changes': <Object?>[],
          });
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
        automaticRetryDelays: const [Duration(milliseconds: 20)],
      );
      addTearDown(service.dispose);

      await expectLater(
        service.syncPendingChangesNow(),
        throwsA(isA<GoogleDriveSyncException>()),
      );
      await service.checkForRemoteChangesNow();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(uploadAttempts, 2);
      expect((await repository.findById(pending.id))?.syncStatus, 'synced');
    },
  );

  test('partial batch failure retries only the remaining event', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final first = _event(
      id: 'partial-success',
      title: '먼저 완료',
      startAt: DateTime(2026, 7, 30),
      endAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 29, 16),
      syncStatus: 'pending',
    );
    final second = _event(
      id: 'partial-retry',
      title: '재시도 필요',
      startAt: DateTime(2026, 7, 31),
      endAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 7, 29, 16),
      syncStatus: 'pending',
    );
    await repository.save(first);
    await repository.save(second);
    var firstUploads = 0;
    var secondUploads = 0;
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        return _driveFiles([
          if (query.contains('partial-success'))
            {
              'id': 'partial-success-file',
              'name': 'daily-sync-v2-event-partial-success.json',
            },
          if (query.contains('partial-retry'))
            {
              'id': 'partial-retry-file',
              'name': 'daily-sync-v2-event-partial-retry.json',
            },
        ]);
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/partial-success-file') {
        firstUploads += 1;
        return _jsonResponse({'id': 'partial-success-file'});
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/partial-retry-file') {
        secondUploads += 1;
        if (secondUploads == 1) {
          return http.Response('temporary server error', 503);
        }
        return _jsonResponse({'id': 'partial-retry-file'});
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/partial-success-file') {
        return _jsonResponse(
          _eventFileJson(
            id: first.id,
            title: '이전 일정',
            startAt: first.startAt.toIso8601String(),
            endAt: first.endAt.toIso8601String(),
            updatedAt: '2025-07-29T15:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/partial-retry-file') {
        return _jsonResponse(
          _eventFileJson(
            id: second.id,
            title: '이전 일정',
            startAt: second.startAt.toIso8601String(),
            endAt: second.endAt.toIso8601String(),
            updatedAt: '2025-07-29T15:00:00.000Z',
            sourceDeviceId: 'remote-device',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
      automaticRetryDelays: const [Duration(milliseconds: 1)],
    );
    addTearDown(service.dispose);

    await expectLater(
      service.syncPendingChangesNow(),
      throwsA(isA<GoogleDriveSyncException>()),
    );
    for (var attempt = 0; attempt < 20 && secondUploads < 2; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(firstUploads, 1);
    expect(secondUploads, 2);
    expect((await repository.findById(first.id))?.syncStatus, 'synced');
    expect((await repository.findById(second.id))?.syncStatus, 'synced');
  });

  test('offline automatic backup retries a bounded number of times', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final pending = _event(
      id: 'offline-event',
      title: '오프라인 일정',
      startAt: DateTime(2026, 7, 30),
      endAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 29, 16),
      syncStatus: 'pending',
    );
    await repository.save(pending);
    var attempts = 0;
    final httpClient = MockClient((request) async {
      attempts += 1;
      throw http.ClientException('network unavailable', request.url);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
      automaticRetryDelays: const [
        Duration(milliseconds: 1),
        Duration(milliseconds: 1),
      ],
    );
    addTearDown(service.dispose);

    await expectLater(
      service.syncPendingChangesNow(),
      throwsA(isA<http.ClientException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(attempts, 3);
    expect((await repository.findById(pending.id))?.syncStatus, 'pending');
    expect(service.statusNotifier.value.message, '동기화 실패');
  });

  test(
    'sync analytics records categorized failure without changing the error',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final analytics = _RecordingAnalytics();
      final service = _service(
        authService: _MissingHeaderGoogleDriveAuthService(),
        repository: _MemoryEventRepository(),
        notificationService: _FakeNotificationService(),
        preferences: preferences,
        httpClient: MockClient((request) async => http.Response('', 500)),
        analytics: analytics,
      );
      addTearDown(service.dispose);

      await expectLater(
        service.restoreNow(),
        throwsA(isA<GoogleDriveAuthException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(analytics.records.map((record) => record.name), [
        AnalyticsEventName.syncStarted,
        AnalyticsEventName.syncFailed,
      ]);
      expect(
        analytics.records.last.attributes['errorCode'],
        AnalyticsErrorCode.authenticationRequired.name,
      );
    },
  );
}

GoogleDriveSyncService _service({
  GoogleDriveAuthService? authService,
  required _MemoryEventRepository repository,
  required _FakeNotificationService notificationService,
  required SharedPreferences preferences,
  required http.Client httpClient,
  Duration backupRestoreDelay = Duration.zero,
  Duration changeSyncDelay = Duration.zero,
  List<Duration> automaticRetryDelays = const [],
  ProductAnalytics analytics = const NoopProductAnalytics(),
}) {
  return GoogleDriveSyncService(
    authService: authService ?? _FakeGoogleDriveAuthService(),
    eventRepository: repository,
    notificationService: notificationService,
    settingsRepository: SettingsRepository(preferences: preferences),
    httpClient: httpClient,
    backupRestoreDelay: backupRestoreDelay,
    changeSyncDelay: changeSyncDelay,
    automaticRetryDelays: automaticRetryDelays,
    analytics: analytics,
  );
}

http.Response _driveFiles(List<Map<String, Object?>> files) {
  return _jsonResponse({'files': files});
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> _eventFileJson({
  required String id,
  required String title,
  required String startAt,
  required String endAt,
  String updatedAt = '2026-05-29T00:00:00.000Z',
  String? deletedAt,
  String? sourceDeviceId,
  bool completed = false,
}) {
  return {
    'schemaVersion': 2,
    'type': 'event',
    'sourceDeviceId': ?sourceDeviceId,
    'event': {
      'id': id,
      'title': title,
      'startAt': startAt,
      'endAt': endAt,
      'allDay': true,
      'category': 'basic',
      'colorValue': EventCategory.basic.colorValue,
      'createdAt': '2026-05-29T00:00:00.000Z',
      'updatedAt': updatedAt,
      'deletedAt': ?deletedAt,
      'completed': completed,
    },
  };
}

CalendarEvent _event({
  required String id,
  required String title,
  required DateTime startAt,
  required DateTime endAt,
  required DateTime updatedAt,
  String syncStatus = 'synced',
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startAt: startAt,
    endAt: endAt,
    allDay: true,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    syncStatus: syncStatus,
  );
}

class _FakeGoogleDriveAuthService extends GoogleDriveAuthService {
  final _accountChanges = StreamController<GoogleDriveAccount?>.broadcast();

  @override
  Stream<GoogleDriveAccount?> get accountChanges => _accountChanges.stream;

  @override
  GoogleDriveAccount? get currentAccount =>
      const GoogleDriveAccount(email: 'tester@example.com');

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    return const {'Authorization': 'Bearer test-token'};
  }
}

class _RecordingAnalytics extends NoopProductAnalytics {
  final records = <AnalyticsRecord>[];

  @override
  Future<void> record(AnalyticsRecord record) async => records.add(record);
}

class _MissingHeaderGoogleDriveAuthService extends _FakeGoogleDriveAuthService {
  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    return null;
  }
}

class _FakeNotificationService implements NotificationService {
  final scheduled = <CalendarEvent>[];
  final cancelled = <String>[];

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    cancelled.add(eventId);
  }

  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<int> pendingNotificationCount() async => scheduled.length;

  @override
  Future<String> permissionSummary() async => 'test';

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    scheduled.add(event);
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
}

class _MemoryEventRepository implements EventRepository {
  final _events = <String, CalendarEvent>{};
  Future<void> Function(String id)? onFindById;
  Future<void> Function()? beforeAtomicRestore;
  bool failAtomicRestore = false;

  List<CalendarEvent> get events => _events.values.toList();

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => events;

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    final affected = <CalendarEvent>[];
    for (final entry in _events.entries.toList()) {
      final event = entry.value;
      if (event.deletedAt != null || event.category.id != previous.id) {
        continue;
      }
      final next = event.copyWith(
        category: updated,
        colorValue: updated.colorValue,
        updatedAt: updatedAt,
        syncStatus: 'pending',
        holiday: updated.id == EventCategory.holiday.id,
      );
      _events[entry.key] = next;
      affected.add(next);
    }
    return affected;
  }

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    return events
        .where(
          (event) =>
              event.deletedAt == null &&
              event.startAt.isBefore(rangeEnd) &&
              event.endAt.isAfter(rangeStart),
        )
        .toList();
  }

  @override
  Future<void> clearAll() async {
    _events.clear();
  }

  @override
  Future<void> delete(String eventId) async {
    final event = _events[eventId];
    if (event != null) {
      _events[eventId] = event.copyWith(
        deletedAt: DateTime.now(),
        syncStatus: 'pending_delete',
      );
    }
  }

  @override
  Future<CalendarEvent?> findById(String id) async {
    await onFindById?.call(id);
    return _events[id];
  }

  @override
  Future<void> hardDelete(String eventId) async {
    _events.remove(eventId);
  }

  @override
  Future<void> markSynced(String eventId) async {
    final event = _events[eventId];
    if (event != null) {
      _events[eventId] = event.copyWith(syncStatus: 'synced');
    }
  }

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async {
    await beforeAtomicRestore?.call();
    if (failAtomicRestore) {
      throw StateError('atomic restore failed');
    }
    final workingCopy = Map<String, CalendarEvent>.from(_events);
    final mutations = <EventRestoreMutation>[];
    for (final remote in remoteEvents) {
      final normalizedRemote = remote.normalizeAllDayBounds();
      final previous = workingCopy[normalizedRemote.id];
      final current = resolve(
        previous,
        normalizedRemote,
      ).normalizeAllDayBounds();
      if (!identical(previous, current)) {
        workingCopy[current.id] = current;
        mutations.add(
          EventRestoreMutation(previous: previous, current: current),
        );
      }
    }
    _events
      ..clear()
      ..addAll(workingCopy);
    return mutations;
  }

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async {
    return _events.values
        .where((event) => event.syncStatus != 'synced')
        .toList();
  }

  @override
  Future<void> save(CalendarEvent event) async {
    _events[event.id] = event.normalizeAllDayBounds();
  }

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {
    for (final event in events) {
      _events[event.id] = event.normalizeAllDayBounds();
    }
  }

  @override
  Future<List<CalendarEvent>> search(String query) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return Stream.value(events);
  }
}
