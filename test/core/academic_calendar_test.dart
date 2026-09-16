import 'dart:async';
import 'dart:convert';

import 'package:daily/core/academic/academic_calendar_service.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/academic_store.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/settings/presentation/academic_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

AcademicEvent remote({
  String id = '766720',
  String title = '수강신청 정정',
  int day = 1,
  int end = 8,
}) => AcademicEvent(
  sourceId: id,
  title: title,
  start: DateTime(2026, 9, day),
  end: DateTime(2026, 9, end),
  url:
      'https://www.smu.ac.kr/ko/life/academicCalendar.do?mode=view&articleNo=$id&boardNo=85',
);

Map<String, Object?> row({
  String start = '2026-09-01',
  String end = '2026-09-07',
  String id = '766720',
}) => {
  'articleNo': int.parse(id),
  'boardNo': '85',
  'articleTitle': '수강신청 정정',
  'etcChar6': start,
  'etcChar7': end,
  'etcChar8': 'etc',
};
String response(List<Map<String, Object?>> rows) =>
    jsonEncode({'success': true, 'list': rows});

class Source implements AcademicSource {
  @override
  String get id => 'smu';
  @override
  String get name => '상명대학교';
  @override
  Uri get website =>
      Uri.parse('https://www.smu.ac.kr/ko/life/academicCalendar.do');
  List<AcademicEvent> events = [remote()];
  int requests = 0;
  final years = <int>[];
  Future<List<AcademicEvent>> Function()? answer;
  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    requests++;
    years.add(year);
    return answer == null ? events : await answer!();
  }

  @override
  void close() {}
}

class Repository implements EventRepository {
  final events = <String, CalendarEvent>{};
  Set<String> fail = {};
  bool failCategoryUpdate = false;
  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    if (failCategoryUpdate) throw StateError('category write failed');
    final affected = [
      for (final event in events.values)
        if (!event.isDeleted &&
            (event.category.id == previous.id ||
                event.category.label == previous.label))
          event.copyWith(
            category: updated,
            colorValue: updated.colorValue,
            updatedAt: updatedAt,
            syncStatus: 'pending',
          ),
    ];
    for (final event in affected) {
      events[event.id] = event;
    }
    return affected;
  }

  @override
  Future<CalendarEvent?> findById(String id) async => events[id];
  @override
  Future<void> save(CalendarEvent event) async {
    if (fail.contains(event.id)) throw StateError('disk failure');
    events[event.id] = event;
  }

  @override
  Future<void> delete(String id) async {
    events[id] = events[id]!.copyWith(deletedAt: DateTime(2026, 9, 16));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Notifications implements NotificationService {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Sync implements SyncService {
  final uploaded = <String>[];
  final deleted = <String>[];
  int settingsBackups = 0;
  @override
  Future<void> queueSettingsBackup() async {
    settingsBackups++;
  }

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {
    uploaded.add(event.id);
  }

  @override
  Future<void> queueEventDelete(String eventId) async {
    deleted.add(eventId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsRepository settings;
  late Source source;
  late Repository repository;
  late Sync sync;
  late AcademicCalendarService service;
  late DateTime now;
  late EventCommandService commands;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    source = Source();
    repository = Repository();
    sync = Sync();
    now = DateTime(2026, 9, 16);
    commands = EventCommandService(
      repository: repository,
      settingsRepository: settings,
      notificationService: Notifications(),
      syncService: sync,
    );
    service = AcademicCalendarService(
      sources: [source],
      store: settings.academicStore,
      settings: settings,
      repository: repository,
      commands: commands,
      sync: sync,
      now: () => now,
    );
  });
  tearDown(() => service.dispose());
  Future<void> importAll() async {
    final preview = await service.preview(source, 2026);
    await service.importSelection(
      preview,
      preview.events.map((e) => e.sourceId).toSet(),
    );
  }

  test(
    'initial color persists on import and existing color wins on refresh',
    () async {
      final preview = await service.preview(source, 2026);
      await service.importSelection(preview, {
        '766720',
      }, colorValue: 0xff123456);
      expect(repository.events.values.single.colorValue, 0xff123456);
      expect(settings.load().categories.last.colorValue, 0xff123456);
      expect(sync.settingsBackups, 1);
      await service.importSelection(preview, {
        '766720',
      }, colorValue: 0xffabcdef);
      await service.refresh('smu');
      expect(settings.load().categories.last.colorValue, 0xff123456);
      expect(repository.events.values.single.colorValue, 0xff123456);
    },
  );

  test(
    'repeated color changes update events, settings and sync without duplicating categories',
    () async {
      await importAll();
      final id = repository.events.keys.single;
      repository.events[id] = repository.events[id]!.copyWith(
        completed: true,
        memo: 'keep',
      );
      final before = settings.load();
      await settings.save(
        before.copyWith(
          showLunarDates: false,
          hiddenCategoryIds: [AcademicCalendarService.categoryId('smu')],
        ),
        changedFrom: before,
      );
      final original = repository.events[id]!;
      for (final color in [0xff10b981, 0xffab1267, 0xff2563eb]) {
        await service.setCategoryColor('smu', color);
        final event = repository.events[id]!;
        expect(event.colorValue, color);
        expect(event.category.colorValue, color);
        expect(event.completed, isTrue);
        expect(event.memo, 'keep');
        expect(event.startAt, original.startAt);
        expect(event.endAt, original.endAt);
        expect(settings.load().categories.last.colorValue, color);
      }
      expect(settings.load().categories, hasLength(before.categories.length));
      expect(settings.load().hiddenCategoryIds, [
        AcademicCalendarService.categoryId('smu'),
      ]);
      expect(settings.load().showLunarDates, isFalse);
      expect(sync.uploaded.where((event) => event == id), hasLength(4));
      expect(sync.settingsBackups, 4);
    },
  );

  test(
    'failed color propagation reports failure and allows same-color retry',
    () async {
      await importAll();
      repository.failCategoryUpdate = true;
      await expectLater(
        service.setCategoryColor('smu', 0xff123456),
        throwsStateError,
      );
      expect(service.unavailable, isTrue);
      repository.failCategoryUpdate = false;
      await service.setCategoryColor('smu', 0xff123456);
      expect(service.unavailable, isFalse);
      expect(repository.events.values.single.colorValue, 0xff123456);
    },
  );

  test(
    'changing a missing category cannot create a subscription or import events',
    () async {
      await expectLater(
        service.setCategoryColor('smu', 0xff123456),
        throwsStateError,
      );
      expect(service.subscriptions, isEmpty);
      expect(repository.events, isEmpty);
      expect(settings.load().categories, hasLength(2));
    },
  );

  test(
    'SQLite category colors survive reads and refresh while unrelated events stay intact',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftEventRepository(db);
      var widgetRefreshes = 0;
      final realService = AcademicCalendarService(
        sources: [source],
        store: settings.academicStore,
        settings: settings,
        repository: repo,
        sync: sync,
        commands: EventCommandService(
          repository: repo,
          settingsRepository: settings,
          notificationService: Notifications(),
          syncService: sync,
          onEventsChanged: () async {
            widgetRefreshes++;
          },
        ),
      );
      addTearDown(realService.dispose);
      final preview = await realService.preview(source, 2026);
      await realService.importSelection(preview, {
        '766720',
      }, colorValue: 0xff123456);
      final id = remote().dailyId('smu');
      final imported = (await repo.findById(id))!;
      await repo.save(imported.copyWith(completed: true, memo: 'private note'));
      await repo.save(
        imported.copyWith(
          id: 'personal',
          category: EventCategory.basic,
          colorValue: 0xfffedcba,
        ),
      );
      for (final color in [0xffab1234, 0xff104872]) {
        await realService.setCategoryColor('smu', color);
        await realService.refresh('smu');
        final event = (await repo.findById(id))!;
        expect(event.colorValue, color);
        expect(event.category.colorValue, color);
        expect(event.completed, isTrue);
        expect(event.memo, 'private note');
        expect(event.startAt, imported.startAt);
        expect((await repo.findById('personal'))!.colorValue, 0xfffedcba);
      }
      expect(widgetRefreshes, greaterThanOrEqualTo(3));
      expect(sync.uploaded.where((e) => e == id), hasLength(3));
    },
  );

  test(
    'official JSON includes end date and ignores unrelated boards; IDs survive edits',
    () {
      final parsed = SangmyungAcademicSource.parse(
        response([
          row(),
          {...row(id: '999'), 'boardNo': '86'},
        ]),
        2026,
      );
      expect(parsed, hasLength(1));
      expect(parsed.single.end, DateTime(2026, 9, 8));
      expect(
        parsed.single.dailyId('smu'),
        remote(day: 3, title: 'changed').dailyId('smu'),
      );
      expect(
        parsed.single.dailyId('another'),
        isNot(parsed.single.dailyId('smu')),
      );
    },
  );
  test('JSON handles year crossing, one-day and leap-day bounds', () {
    final parsed = SangmyungAcademicSource.parse(
      response([
        row(id: '1', start: '2023-12-30', end: '2024-01-02'),
        row(id: '2', start: '2024-02-29', end: '2024-02-29'),
        row(id: '3', start: '2025-01-01', end: '2025-01-01'),
      ]),
      2024,
    );
    expect(parsed, hasLength(2));
    expect(parsed.last.end, DateTime(2024, 3, 1));
  });
  test(
    'malformed, impossible dates, incomplete, conflicting and empty data fail closed',
    () {
      for (final body in [
        '<html>maintenance</html>',
        '{}',
        response([]),
        response([row(start: '2026-02-30')]),
        response([row(start: '2026-09-09')]),
        response([
          {...row(), 'articleTitle': ''},
        ]),
        response([row(), row(end: '2026-09-09')]),
      ]) {
        expect(
          () => SangmyungAcademicSource.parse(body, 2026),
          throwsA(anything),
        );
      }
    },
  );
  test(
    'HTTP uses official undergraduate board and calendar year; status errors fail',
    () async {
      final api = SangmyungAcademicSource(
        client: MockClient((request) async {
          expect(request.url.host, 'www.smu.ac.kr');
          final body = Uri.splitQueryString(request.body);
          expect(jsonDecode(body['jsonStr']!)['bachelorBoardNoList'], ['85']);
          expect(jsonDecode(body['jsonStr']!)['year'], '2026');
          return http.Response(
            response([row()]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(await api.fetch(2026), hasLength(1));
      api.close();
      final failed = SangmyungAcademicSource(
        client: MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(failed.fetch(2026), throwsFormatException);
      failed.close();
    },
  );
  test(
    'preview is read-only; import creates named category and queues v2 event uploads',
    () async {
      final preview = await service.preview(source, 2026);
      expect(repository.events, isEmpty);
      expect(service.subscriptions, isEmpty);
      await service.importSelection(preview, {'766720'});
      expect(repository.events, hasLength(1));
      final event = repository.events.values.single;
      expect(event.category.label, '상명대학교');
      expect(event.allDay, isTrue);
      expect(event.endAt, DateTime(2026, 9, 8));
      expect(sync.uploaded, [event.id]);
      expect(service.result!.added, 1);
    },
  );
  test(
    're-import and refresh are idempotent; source date/title changes update same ID',
    () async {
      await importAll();
      await importAll();
      await service.refresh('smu');
      expect(repository.events, hasLength(1));
      expect(sync.uploaded, hasLength(1));
      final before = repository.events.values.single;
      source.events = [remote(title: '변경됨', day: 3)];
      await service.refresh('smu');
      final after = repository.events[before.id]!;
      expect(after.title, '변경됨');
      expect(after.startAt.day, 3);
      expect(after.createdAt, before.createdAt);
      expect(service.result!.updated, 1);
    },
  );
  test(
    'completion, notes, alarms, category colors survive source updates',
    () async {
      await importAll();
      final before = repository.events.values.single;
      repository.events[before.id] = before.copyWith(
        completed: true,
        memo: 'my notes',
        colorValue: 0xff884422,
        alarmEnabled: true,
        reminderMinutesBeforeList: [10],
      );
      source.events = [remote(day: 2)];
      await service.refresh('smu');
      final after = repository.events[before.id]!;
      expect(after.completed, isTrue);
      expect(after.memo, 'my notes');
      expect(after.colorValue, 0xff884422);
      expect(after.alarmEnabled, isTrue);
      expect(after.reminderMinutesBeforeList, [10]);
      expect(after.startAt.day, 2);
    },
  );
  test(
    'user-controlled date/title and tombstones are never overwritten or resurrected',
    () async {
      await importAll();
      final id = repository.events.keys.single;
      repository.events[id] = repository.events[id]!.copyWith(title: 'mine');
      source.events = [remote(day: 2)];
      await service.refresh('smu');
      expect(repository.events[id]!.title, 'mine');
      expect(repository.events[id]!.startAt.day, 1);
      expect(service.result!.preserved, 1);
      await repository.delete(id);
      await importAll();
      expect(repository.events[id]!.isDeleted, isTrue);
      expect(repository.events, hasLength(1));
    },
  );
  test(
    'another device without baselines adopts matching records but preserves differences',
    () async {
      await importAll();
      final id = repository.events.keys.single;
      await settings.academicStore.clear();
      source.events = [remote(day: 4)];
      await importAll();
      expect(repository.events[id]!.startAt.day, 1);
      expect(service.result!.preserved, 1);
    },
  );
  test(
    'failed source and missing source records preserve events and last success',
    () async {
      await importAll();
      final last = service.subscriptions['smu']!.lastSuccess;
      now = now.add(const Duration(days: 2));
      source.answer = () => Future.error(StateError('offline'));
      await service.refreshIfDue();
      expect(repository.events, hasLength(1));
      expect(service.subscriptions['smu']!.failed, isTrue);
      expect(service.subscriptions['smu']!.lastSuccess, last);
      source.answer = null;
      source.events = [remote(id: 'new')];
      await service.refresh('smu');
      expect(repository.events, hasLength(2));
    },
  );
  test(
    'automatic checks throttle success and failure, and follow year rollover',
    () async {
      await service.refreshIfDue();
      expect(source.requests, 0);
      await importAll();
      final first = source.requests;
      await service.refreshIfDue();
      expect(source.requests, first);
      now = now.add(const Duration(days: 1));
      await service.refreshIfDue();
      expect(source.requests, first + 1);
      now = DateTime(2027, 1, 1);
      await service.refreshIfDue();
      expect(source.years.last, 2027);
      source.answer = () => Future.error(StateError('offline'));
      now = now.add(const Duration(days: 1));
      await service.refreshIfDue();
      final failed = source.requests;
      await service.refreshIfDue();
      expect(source.requests, failed);
    },
  );
  test(
    'deselected schedules stay excluded and new source records are imported',
    () async {
      source.events = [remote(), remote(id: '2')];
      final preview = await service.preview(source, 2026);
      await service.importSelection(preview, {'766720'});
      source.events = [...source.events, remote(id: '3')];
      await service.refresh('smu');
      expect(repository.events, hasLength(2));
      expect(
        repository.events.containsKey(remote(id: '2').dailyId('smu')),
        isFalse,
      );
    },
  );
  test(
    'partial write failure keeps pending provenance and retries only failed event',
    () async {
      source.events = [remote(), remote(id: '2')];
      repository.fail = {remote().dailyId('smu')};
      await importAll();
      expect(service.result!.failed, 1);
      expect(service.subscriptions['smu']!.lastSuccess, isNull);
      expect(service.subscriptions['smu']!.managedIds, hasLength(2));
      repository.fail.clear();
      await service.refresh('smu');
      expect(repository.events, hasLength(2));
      expect(sync.uploaded, hasLength(2));
    },
  );
  test(
    'disconnect preserves events; explicit removal deletes only managed IDs',
    () async {
      await importAll();
      final imported = repository.events.values.single;
      repository.events['personal'] = imported.copyWith(
        id: 'personal',
        title: 'Personal',
      );
      await service.setEnabled('smu', false);
      now = now.add(const Duration(days: 2));
      final count = source.requests;
      await service.refreshIfDue();
      expect(source.requests, count);
      expect(repository.events[imported.id]!.isDeleted, isFalse);
      await service.removeImported('smu');
      expect(repository.events[imported.id]!.isDeleted, isTrue);
      expect(repository.events['personal']!.isDeleted, isFalse);
      expect(sync.deleted, [imported.id]);
    },
  );
  test('reset invalidates in-flight source fetch and stale preview', () async {
    final preview = await service.preview(source, 2026);
    await settings.academicStore.clear();
    await expectLater(
      service.importSelection(preview, {'766720'}),
      throwsStateError,
    );
    expect(repository.events, isEmpty);
    final pending = Completer<List<AcademicEvent>>();
    source.answer = () => pending.future;
    final operation = service.preview(source, 2026);
    await settings.academicStore.clear();
    pending.complete([remote()]);
    await expectLater(operation, throwsStateError);
    expect(repository.events, isEmpty);
  });
  test(
    'settings persist exclusions/baselines and custom category edits',
    () async {
      await importAll();
      final before = settings.load();
      await settings.save(
        before.copyWith(
          categories: [
            for (final c in before.categories)
              c.id == 'academic_smu'
                  ? const EventCategory(
                      id: 'academic_smu',
                      label: 'My school',
                      colorValue: 0xff228844,
                    )
                  : c,
          ],
        ),
        changedFrom: before,
      );
      await service.refresh('smu');
      expect(settings.load().categories.last.label, 'My school');
      final loaded = settings.academicStore.load()['smu']!;
      expect(loaded.baselines, hasLength(1));
      expect(loaded.managedIds, hasLength(1));
    },
  );
  testWidgets(
    'compact settings preview/import in four locales and large text',
    (tester) async {
      for (final locale in [
        const Locale('ko'),
        const Locale('en'),
        const Locale('ja'),
        const Locale('zh', 'TW'),
      ]) {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settings),
              academicCalendarServiceProvider.overrideWithValue(service),
            ],
            child: MaterialApp(
              locale: locale,
              supportedLocales: [locale],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const AcademicCalendarPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final color = locale.languageCode == 'ko' ? 0xff10b981 : 0xffec4899;
        final countBefore = repository.events.length;
        await tester.tap(find.byKey(const ValueKey('academic-color-smu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('category-color-$color')));
        await tester.tap(find.text('적용'));
        await tester.pump();
        // The repository mutation queue was created outside the widget clock.
        for (var frame = 0; service.busy && frame < 20; frame++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(service.busy, isFalse);
        await tester.pumpAndSettle();
        expect(repository.events.length, countBefore);
        if (countBefore == 0) {
          expect(settings.load().categories, hasLength(2));
          expect(service.subscriptions, isEmpty);
        } else {
          expect(repository.events.values.single.colorValue, color);
        }
        await tester.tap(find.byKey(const ValueKey('academic-preview')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('academic-event-766720')),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('수강신청 정정'), findsOneWidget);
        final button = find.byKey(const ValueKey('academic-import'));
        expect(button, findsOneWidget);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final completed = Completer<void>();
          void onChange() {
            if (!service.busy && !completed.isCompleted) completed.complete();
          }

          service.addListener(onChange);
          try {
            await tester.tap(button);
            await completed.future;
          } finally {
            service.removeListener(onChange);
          }
        });
        await tester.pumpAndSettle();
        expect(repository.events, hasLength(1));
        expect(repository.events.values.single.colorValue, color);
        expect(settings.load().categories.last.colorValue, color);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  test(
    'empty source response cannot clear existing data or mark success',
    () async {
      await importAll();
      source.events = [];
      final previous = service.subscriptions['smu']!.lastSuccess;
      now = now.add(const Duration(days: 2));
      await expectLater(service.refresh('smu'), throwsFormatException);
      expect(repository.events, hasLength(1));
      expect(service.subscriptions['smu']!.lastSuccess, previous);
      expect(service.subscriptions['smu']!.failed, isTrue);
    },
  );

  test(
    'busy lifecycle refresh does not start a duplicate source request',
    () async {
      await importAll();
      now = now.add(const Duration(days: 2));
      final pending = Completer<List<AcademicEvent>>();
      source.answer = () => pending.future;
      final first = service.refreshIfDue();
      await Future<void>.delayed(Duration.zero);
      final count = source.requests;
      await service.refreshIfDue();
      expect(source.requests, count);
      pending.complete([remote()]);
      await first;
    },
  );

  test(
    'corrupt provenance prevents import instead of silently resetting history',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(AcademicStore.key, '{broken');
      final guarded = AcademicCalendarService(
        sources: [Source()],
        store: settings.academicStore,
        settings: settings,
        repository: repository,
        commands: commands,
        sync: sync,
      );
      expect(guarded.unavailable, isTrue);
      await expectLater(
        guarded.preview(guarded.sources.single, 2026),
        throwsStateError,
      );
      expect(repository.events, isEmpty);
      guarded.dispose();
    },
  );

  test(
    'reset during batch prepare prevents the queued save and upload',
    () async {
      await importAll();
      final event = repository.events.values.single.copyWith(title: 'stale');
      final generation = settings.academicStore.generation;
      final pending = Completer<CalendarEvent?>();
      final operation = commands.importBatch(
        [event],
        prepare: (_) => pending.future,
        isCurrent: () => generation == settings.academicStore.generation,
      );
      await settings.academicStore.clear();
      pending.complete(event);
      expect(await operation, isEmpty);
      expect(repository.events.values.single.title, isNot('stale'));
      expect(sync.uploaded, hasLength(1));
    },
  );
}
