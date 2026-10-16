import 'package:daily/core/localization/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:daily/features/chat/presentation/chat_input_bar.dart';
import 'package:daily/features/chat/application/rule_based_schedule_parser.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily/core/alarms/alarm_service.dart';
import 'package:daily/core/calendar/recurring_event_edit.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'same recurrence detail sheet toggles one persisted row despite follow-up failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final source = _event('detail-series', EventCategory.basic).copyWith(
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          count: 3,
        ),
      );
      await repository.save(source);
      final occurrence = RecurrenceExpander()
          .expand(
            source,
            source.startAt,
            source.startAt.add(const Duration(days: 4)),
          )
          .elementAt(1);
      final commands = EventCommandService(
        repository: repository,
        settingsRepository: settings,
        notificationService: _FailingMoveNotifications(),
        syncService: _CountingSyncService(),
      );
      Widget panel(CalendarEvent event) => ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          eventRepositoryProvider.overrideWithValue(repository),
          eventCommandServiceProvider.overrideWithValue(commands),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EventDetailsPanel(
              date: event.startAt,
              events: [event],
              initialEvent: event,
            ),
          ),
        ),
      );
      await tester.pumpWidget(panel(occurrence));
      await tester.pumpAndSettle();
      String? detachedID;
      for (final completed in [true, false, true]) {
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, completed);
        final rows = await repository.allEventsForSync();
        expect(rows.length, 2);
        final detached = rows.singleWhere((event) => event.id != source.id);
        detachedID ??= detached.id;
        expect(detached.id, detachedID);
        expect(detached.completed, completed);
        final remaining = RecurrenceExpander()
            .expand(
              rows.singleWhere((event) => event.id == source.id),
              source.startAt,
              source.startAt.add(const Duration(days: 4)),
            )
            .toList();
        expect(remaining.length, 2);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(panel((await repository.findById(detachedID!))!));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    },
  );

  for (final stage in ['notification', 'alarm', 'sync', 'widgets']) {
    test(
      'post-save $stage failure leaves one saved row and retries only pending stage',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = DriftEventRepository(database);
        final notifications = _FailingMoveNotifications()
          ..fail = stage == 'notification';
        final alarms = _FailingSaveAlarms()..fail = stage == 'alarm';
        final sync = _FailingSaveSync()..fail = stage == 'sync';
        var failWidgets = stage == 'widgets';
        final commands = EventCommandService(
          repository: repository,
          settingsRepository: settings,
          notificationService: notifications,
          alarmService: alarms,
          syncService: sync,
          onEventsChanged: () async {
            if (failWidgets) throw StateError('injected widget failure');
          },
        );
        final event = await commands.create(
          EventDraft(
            title: 'saved',
            startAt: DateTime(2027, 1, 1, 9),
            endAt: DateTime(2027, 1, 1, 10),
          ),
        );
        expect((await repository.allEventsForSync()).length, 1);
        expect(settings.pendingEventFollowUps()[event.id]['stages'], [stage]);
        notifications.fail = false;
        alarms.fail = false;
        sync.fail = false;
        failWidgets = false;
        expect(await commands.retryPendingFollowUps(), isTrue);
        expect(settings.pendingEventFollowUps(), isEmpty);
        expect((await repository.allEventsForSync()).length, 1);
      },
    );
  }

  for (final failDatabase in [false, true]) {
    testWidgets(
      'chat preserves only unsaved drafts databaseFailure=$failDatabase',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = DriftEventRepository(database);
        await repository.allEventsForSync();
        if (failDatabase) {
          await database.customStatement(
            "CREATE TRIGGER reject_create BEFORE INSERT ON event_records BEGIN SELECT RAISE(ABORT, 'injected write failure'); END",
          );
        }
        final notifications = _FailingMoveNotifications();
        final commands = EventCommandService(
          repository: repository,
          settingsRepository: settings,
          notificationService: notifications,
          syncService: _CountingSyncService(),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settings),
              eventCommandServiceProvider.overrideWithValue(commands),
              scheduleParserProvider.overrideWithValue(
                RuleBasedScheduleParser(),
              ),
            ],
            child: const MaterialApp(
              locale: Locale('ko'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(body: ChatInputBar()),
            ),
          ),
        );
        const input = '내일 오후 3시 회의';
        await tester.enterText(find.byType(TextField), input);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() async {
          await tester.tap(find.byType(FilledButton));
          for (var attempt = 0; attempt < 200; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          failDatabase ? input : '',
        );
        expect(
          (await repository.allEventsForSync()).length,
          failDatabase ? 0 : 1,
        );
        if (!failDatabase) {
          notifications.fail = false;
          expect(await commands.retryPendingFollowUps(), isTrue);
          expect((await repository.allEventsForSync()).length, 1);
        }
      },
    );
  }

  test(
    'saved create survives notification failure and restart recovery uses same ID',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsRepository(preferences: preferences);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final notifications = _FailingMoveNotifications();
      final sync = _CountingSyncService();
      var notices = 0;
      final commands = EventCommandService(
        repository: repository,
        settingsRepository: settings,
        notificationService: notifications,
        syncService: sync,
        onFollowUpFailure: () => notices++,
      );
      final saved = await commands.create(
        EventDraft(
          title: 'persisted',
          startAt: DateTime(2027, 1, 1, 9),
          endAt: DateTime(2027, 1, 1, 10),
        ),
      );
      expect((await repository.findById(saved.id))?.title, 'persisted');
      expect(notices, 1);
      expect(sync.upsertedIds, contains(saved.id));
      expect(settings.pendingEventFollowUps().keys, contains(saved.id));
      notifications.fail = false;
      final restarted = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        syncService: sync,
      );
      expect(await restarted.retryPendingFollowUps(), isTrue);
      expect(settings.pendingEventFollowUps(), isEmpty);
      expect(sync.upsertedIds.where((id) => id == saved.id).length, 1);
      expect((await repository.allEventsForSync()).length, 1);
    },
  );

  test(
    'old follow-up acknowledgement cannot remove newer save intent',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      await settings.stageEventFollowUp('event', 'old', [10]);
      await settings.stageEventFollowUp('event', 'new', [30]);
      await settings.acknowledgeEventFollowUp('event', 'old');
      expect(settings.pendingEventFollowUps()['event']['token'], 'new');
      expect(
        settings.pendingEventFollowUps()['event']['reminders'],
        containsAll([10, 30]),
      );
      await settings.acknowledgeEventFollowUp('event', 'new');
      expect(settings.pendingEventFollowUps(), isEmpty);
    },
  );

  for (final reverse in [false, true]) {
    test(
      'parallel occurrence completion preserves both exclusions reverse=$reverse',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = DriftEventRepository(database);
        final source = _event('concurrent-series', EventCategory.basic)
            .copyWith(
              recurrence: const RecurrenceRule(
                frequency: RecurrenceFrequency.daily,
                count: 5,
              ),
            );
        await repository.save(source);
        final occurrences = [1, 2]
            .map(
              (day) => source.copyWith(
                startAt: source.startAt.add(Duration(days: day)),
                endAt: source.endAt.add(Duration(days: day)),
                occurrenceId: 'series@$day',
              ),
            )
            .toList();
        EventCommandService commands() => EventCommandService(
          repository: repository,
          settingsRepository: settings,
          notificationService: _CountingNotificationService(),
          syncService: _CountingSyncService(),
        );
        final ordered = reverse ? occurrences.reversed : occurrences;
        await Future.wait(ordered.map((e) => commands().setCompleted(e, true)));
        final saved = (await repository.findById(source.id))!;
        for (final occurrence in occurrences) {
          expect(saved.recurrence.excludes(occurrence.startAt), isTrue);
        }
        var all = await repository.allEventsForSync();
        expect(all.length, 3);
        expect(
          all.where((e) => e.id != source.id).every((e) => e.completed),
          isTrue,
        );
        await commands().setCompleted(occurrences.first, true);
        await commands().setCompleted(occurrences.first, false);
        all = await repository.allEventsForSync();
        expect(all.length, 3);
        expect(
          all
              .singleWhere(
                (e) =>
                    e.id != source.id && e.startAt == occurrences.first.startAt,
              )
              .completed,
          isFalse,
        );
        final displayed = all.expand(
          (e) => RecurrenceExpander().expand(
            e,
            source.startAt,
            source.startAt.add(const Duration(days: 7)),
          ),
        );
        expect(displayed.length, 5);
      },
    );
  }
  for (final mutation in ['deleted', 'no-repeat']) {
    test(
      'completion cannot revive a $mutation source during the transaction boundary',
      () async {
        SharedPreferences.setMockInitialValues({});
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _RacingLmsRepository(database);
        final source = _event('racing-series', EventCategory.basic).copyWith(
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            count: 3,
          ),
        );
        await repository.save(source);
        final changed = mutation == 'deleted'
            ? source.copyWith(deletedAt: DateTime(2026, 10, 16))
            : source.copyWith(recurrence: const RecurrenceRule());
        repository.beforeMerge = () => repository.save(changed);
        final commands = EventCommandService(
          repository: repository,
          settingsRepository: SettingsRepository(
            preferences: await SharedPreferences.getInstance(),
          ),
          notificationService: _CountingNotificationService(),
          syncService: _CountingSyncService(),
        );
        await expectLater(
          commands.setCompleted(
            source.copyWith(occurrenceId: 'original'),
            true,
          ),
          throwsStateError,
        );
        expect((await repository.allEventsForSync()).length, 1);
        final current = (await repository.findById(source.id))!;
        expect(current.isDeleted, changed.isDeleted);
        expect(current.recurrence.isRepeating, changed.recurrence.isRepeating);
      },
    );
  }

  for (final scope in [RecurringEditScope.all, RecurringEditScope.future]) {
    for (final index in [0, 2, 4]) {
      test(
        'recurring title edit $scope occurrence $index keeps dates and live exclusions',
        () async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsRepository(
            preferences: await SharedPreferences.getInstance(),
          );
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final repository = DriftEventRepository(database);
          final original = _event('edit-source', EventCategory.basic).copyWith(
            recurrence: const RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              count: 5,
            ),
          );
          final selectedStart = original.startAt.add(Duration(days: index));
          final occurrence = original.copyWith(
            startAt: selectedStart,
            endAt: selectedStart.add(original.duration),
            occurrenceId: 'selected',
          );
          // The snapshot held by the editor predates another occurrence's deletion.
          final latest = original.copyWith(
            recurrence: original.recurrence.copyWith(
              excludedDates: [original.startAt.add(const Duration(days: 1))],
            ),
          );
          await repository.save(latest);
          final commands = EventCommandService(
            repository: repository,
            settingsRepository: settings,
            notificationService: _CountingNotificationService(),
            syncService: _CountingSyncService(),
          );
          final result = await commands.editRecurringOccurrence(
            occurrence: occurrence,
            draft: EventDraft(
              title: 'edited',
              startAt: occurrence.startAt,
              endAt: occurrence.endAt,
              categoryChanged: false,
              recurrence: original.recurrence,
            ),
            scope: scope,
          );
          expect(result.followUpFailed, isFalse);
          final expander = RecurrenceExpander();
          final begin = original.startAt.subtract(const Duration(days: 1));
          final end = original.startAt.add(const Duration(days: 15));
          final expected = expander
              .expand(latest, begin, end)
              .map((e) => e.startAt)
              .toList();
          final actual =
              (await repository.allEventsForSync())
                  .expand((e) => expander.expand(e, begin, end))
                  .map((e) => e.startAt)
                  .toList()
                ..sort();
          expect(actual, expected);
          expect(
            result.event.recurrence.count,
            scope == RecurringEditScope.all ? 5 : 5 - index,
          );
          expect(result.event.category, latest.category);
        },
      );
    }
  }
  test(
    'explicit future count and all-series date changes remain intentional',
    () async {
      final base = _event('edit', EventCategory.basic).copyWith(
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          count: 5,
          excludedDates: [DateTime(2026, 7, 30)],
        ),
      );
      final occurrence = base.copyWith(
        startAt: DateTime(2026, 7, 31, 9),
        endAt: DateTime(2026, 7, 31, 10),
      );
      final explicit = EventDraft(
        title: 'edited',
        startAt: DateTime(2026, 8, 1, 14),
        endAt: DateTime(2026, 8, 1, 15),
        recurrence: base.recurrence,
        recurrenceCountChanged: true,
      );
      final future = applyRecurringEventDraft(
        latest: base,
        occurrence: occurrence,
        draft: explicit,
        scope: RecurringEditScope.future,
      );
      expect(future.recurrence.count, 5);
      final all = applyRecurringEventDraft(
        latest: base,
        occurrence: occurrence,
        draft: explicit,
        scope: RecurringEditScope.all,
      );
      expect(all.startAt, DateTime(2026, 7, 30, 14));
      expect(all.recurrence.excludes(DateTime(2026, 7, 31)), isTrue);
      final noRepeat = applyRecurringEventDraft(
        latest: base,
        occurrence: occurrence,
        draft: explicit.copyWith(recurrence: const RecurrenceRule()),
        scope: RecurringEditScope.future,
      );
      expect(noRepeat.recurrence.isRepeating, isFalse);
      expect(noRepeat.recurrence.excludedDates, isEmpty);
    },
  );

  for (final scope in RecurringMoveScope.values) {
    for (final timeShift in [false, true]) {
      test(
        'atomic recurring move $scope timeShift=$timeShift survives retry',
        () async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsRepository(
            preferences: await SharedPreferences.getInstance(),
          );
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final repository = DriftEventRepository(database);
          final original = _event('move-source', EventCategory.basic).copyWith(
            recurrence: RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              count: 10,
              excludedDates: [DateTime(2026, 8, 2)],
            ),
            completed: true,
          );
          await repository.save(original);
          final occurrence = original.copyWith(
            startAt: DateTime(2026, 7, 31, 9),
            endAt: DateTime(2026, 7, 31, 10),
            occurrenceId: 'move-source@2026-07-31',
          );
          final target = DateTime(2026, 8, 1, timeShift ? 14 : 9);
          final notifications = _FailingMoveNotifications();
          final sync = _CountingSyncService();
          EventCommandService commands() => EventCommandService(
            repository: repository,
            settingsRepository: settings,
            notificationService: notifications,
            syncService: sync,
          );
          final result = await commands().moveRecurringOccurrence(
            occurrence: occurrence,
            targetStart: target,
            scope: scope,
          );
          expect(result.followUpFailed, isTrue);
          expect(result.event.startAt, target);
          expect(result.event.completed, isTrue);
          expect((await repository.allEventsForSync()).length, 2);
          expect(sync.upsertedIds.toSet(), {original.id, result.event.id});
          final savedSource = (await repository.findById(original.id))!;
          if (scope == RecurringMoveScope.onlyThis) {
            expect(savedSource.recurrence.excludes(occurrence.startAt), isTrue);
            expect(result.event.recurrence.isRepeating, isFalse);
          } else {
            expect(savedSource.recurrence.until, DateTime(2026, 7, 30));
            expect(result.event.recurrence.count, 8);
            expect(
              result.event.recurrence.excludes(DateTime(2026, 8, 3)),
              isTrue,
            );
          }
          notifications.fail = false;
          // A new command instance represents retry after restart, not an in-memory cache.
          final retry = await commands().moveRecurringOccurrence(
            occurrence: occurrence,
            targetStart: target,
            scope: scope,
          );
          expect(retry.followUpFailed, isFalse);
          expect(retry.event.id, result.event.id);
          expect((await repository.allEventsForSync()).length, 2);
        },
      );
    }
    for (final failSource in [true, false]) {
      test(
        'recurring move $scope rolls back on ${failSource ? "source" : "detached"} write failure',
        () async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsRepository(
            preferences: await SharedPreferences.getInstance(),
          );
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final repository = DriftEventRepository(database);
          final original = _event('move-source', EventCategory.basic).copyWith(
            recurrence: const RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              count: 10,
            ),
          );
          await repository.save(original);
          await database.customStatement(
            "CREATE TRIGGER fail_move BEFORE INSERT ON event_records "
            "WHEN NEW.id ${failSource ? '=' : '!='} 'move-source' "
            "BEGIN SELECT RAISE(ABORT, 'injected write failure'); END",
          );
          final notifications = _CountingNotificationService();
          final commands = EventCommandService(
            repository: repository,
            settingsRepository: settings,
            notificationService: notifications,
            syncService: _CountingSyncService(),
          );
          await expectLater(
            commands.moveRecurringOccurrence(
              occurrence: original,
              targetStart: DateTime(2026, 8, 1, 9),
              scope: scope,
            ),
            throwsA(anything),
          );
          final all = await repository.allEventsForSync();
          expect(all.length, 1);
          expect(all.single.recurrence.count, 10);
          expect(all.single.recurrence.until, isNull);
          expect(all.single.recurrence.excludedDates, isEmpty);
          expect(notifications.cancelCalls, 0);
          expect(notifications.scheduleCalls, 0);
        },
      );
    }
  }

  for (final type in ['assignment', 'quiz', 'lecture']) {
    for (final (sourceCompleted, latestCompleted, preserveSource)
        in <(bool?, bool, bool)>[
          (true, false, false),
          (false, true, false),
          (null, true, false),
          (null, false, false),
          (true, false, true),
          (false, true, true),
        ]) {
      test(
        'LMS $type completion $sourceCompleted merges latest $latestCompleted '
        '(category-only $preserveSource)',
        () async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsRepository(
            preferences: await SharedPreferences.getInstance(),
          );
          await settings.saveGoogleAccount(
            const GoogleAccount(email: 'student@example.com'),
          );
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final repository = _RacingLmsRepository(database);
          final metadata = LmsEventMetadata(
            schoolId: 'smu',
            ownerId: 'student@example.com',
            lmsUserId: '42',
            courseId: '123',
            courseTitle: '자료구조',
            activityType: type,
            activityId: '456',
            sourceUrl:
                'https://ecampus.smu.ac.kr/mod/${type == 'assignment'
                    ? 'assign'
                    : type == 'lecture'
                    ? 'vod'
                    : 'quiz'}/view.php?id=456',
          );
          final original = _event(
            'lms:completion-race',
            EventCategory.basic,
          ).copyWith(lms: metadata, completed: !latestCompleted);
          await repository.save(original);
          final incoming = original.copyWith(
            title: '새 학교 제목',
            lms: metadata.copyWith(sourceCompleted: sourceCompleted),
          );
          final current = original.copyWith(
            completed: latestCompleted,
            memo: '동시에 저장한 개인 메모',
            reminderMinutesBeforeList: [15, 60],
          );
          repository.beforeMerge = () => repository.save(current);
          final notifications = _CountingNotificationService();
          final alarms = _CountingAlarmService();
          final sync = _CountingSyncService();
          final commands = EventCommandService(
            repository: repository,
            settingsRepository: settings,
            notificationService: notifications,
            alarmService: alarms,
            syncService: sync,
          );

          expect(
            await commands.importBatch([
              incoming,
            ], preserveLmsSource: preserveSource),
            {original.id},
          );

          final saved = (await repository.findById(original.id))!;
          final expected = preserveSource
              ? latestCompleted
              : sourceCompleted ?? latestCompleted;
          expect(saved.completed, expected);
          expect(saved.memo, current.memo);
          expect(saved.reminderMinutesBeforeList, [15, 60]);
          expect(saved.lms, preserveSource ? current.lms : incoming.lms);
          expect(saved.title, preserveSource ? current.title : incoming.title);
          expect(sync.upsertedIds, [original.id]);
          expect(notifications.cancelCalls, expected ? 1 : 0);
          expect(alarms.cancelCalls, expected ? 1 : 0);
          expect(notifications.scheduleCalls, expected ? 0 : 1);
          expect(alarms.scheduleCalls, expected ? 0 : 1);
        },
      );
    }
  }
  for (final type in ['assignment', 'quiz', 'lecture']) {
    test(
      'manual $type completion survives concurrent negative LMS import and clears on uncheck',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        await settings.saveGoogleAccount(
          const GoogleAccount(email: 'student@example.com'),
        );
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _RacingLmsRepository(database);
        final metadata = LmsEventMetadata(
          schoolId: 'smu',
          ownerId: 'student@example.com',
          lmsUserId: '42',
          courseId: '123',
          courseTitle: '수업',
          activityType: type,
          activityId: '456',
          sourceUrl: 'https://ecampus.smu.ac.kr/mod/quiz/view.php?id=456',
          sourceCompleted: true,
        );
        final original = _event(
          'lms:manual',
          EventCategory.basic,
        ).copyWith(lms: metadata, completed: true);
        await repository.save(original);
        final sync = _CountingSyncService();
        final commands = EventCommandService(
          repository: repository,
          settingsRepository: settings,
          notificationService: _CountingNotificationService(),
          alarmService: _CountingAlarmService(),
          syncService: sync,
        );
        // Explicit completion also records intent when already automatically done.
        await commands.setCompleted(original, true);
        final manual = (await repository.findById(original.id))!;
        expect(manual.lms!.manuallyCompleted, isTrue);
        final incoming = original.copyWith(
          lms: metadata.copyWith(
            sourceCompleted: false,
            submissionStatus: '미제출',
          ),
        );
        // Stale incoming does not know the user's marker; atomic latest must win.
        repository.beforeMerge = () =>
            repository.save(manual.copyWith(memo: 'kept'));
        await commands.importBatch([incoming]);
        final imported = (await repository.findById(original.id))!;
        expect(imported.completed, isTrue);
        expect(imported.lms!.manuallyCompleted, isTrue);
        expect(imported.lms!.sourceCompleted, isFalse);
        expect(imported.memo, 'kept');
        expect(sync.upsertedIds, contains(original.id));
        repository.beforeMerge = null;
        // Stale editor cannot strip the manual marker.
        await commands.save(original.copyWith(memo: 'edited'));
        expect(
          (await repository.findById(original.id))!.lms!.manuallyCompleted,
          isTrue,
        );
        await commands.setCompleted(imported, false);
        final unchecked = (await repository.findById(original.id))!;
        expect(unchecked.completed, isFalse);
        expect(unchecked.lms!.manuallyCompleted, isFalse);
        await commands.importBatch([incoming.copyWith(lms: metadata)]);
        expect((await repository.findById(original.id))!.completed, isTrue);
      },
    );
  }
  for (final operation in [
    'editor',
    'import',
    'completion',
    'other-owner',
    'recover-source',
  ]) {
    test(
      'LMS $operation preserves latest atomic source and personal state',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        await settings.saveGoogleAccount(
          const GoogleAccount(email: 'student@example.com'),
        );
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _RacingLmsRepository(database);
        final metadata = LmsEventMetadata(
          schoolId: 'smu',
          ownerId: 'student@example.com',
          lmsUserId: '42',
          courseId: '123',
          courseTitle: '자료구조',
          activityType: 'assignment',
          activityId: '456',
          sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=456',
          submissionStatus: '미제출',
        );
        final original = _event(
          'lms:race',
          EventCategory.basic,
        ).copyWith(lms: metadata, memo: '원래 메모');
        await repository.save(original);
        final notifications = _CountingNotificationService();
        final alarms = _CountingAlarmService();
        final sync = _CountingSyncService();
        final commands = EventCommandService(
          repository: repository,
          settingsRepository: settings,
          notificationService: notifications,
          alarmService: alarms,
          syncService: sync,
        );
        const personalCategory = EventCategory(
          id: 'personal',
          label: '개인',
          colorValue: 0xff123456,
        );
        final source = original.copyWith(
          title: '최신 학교 제목',
          startAt: DateTime(2099, 9, 1),
          endAt: DateTime(2099, 9, 1),
          updatedAt: DateTime(2099, 8, 1),
          lms: metadata.copyWith(submissionStatus: '제출 완료'),
        );
        if (operation == 'editor') {
          repository.beforeMerge = () => repository.save(
            source.copyWith(
              completed: true,
              lms: source.lms!.copyWith(sourceCompleted: true),
            ),
          );
          await commands.save(
            original.copyWith(
              memo: '새 개인 메모',
              category: personalCategory,
              colorValue: personalCategory.colorValue,
              reminderMinutesBeforeList: [10],
              clearLms: true,
            ),
          );
          final result = (await repository.findById(original.id))!;
          expect(result.title, source.title);
          expect(result.startAt, source.startAt);
          expect(result.endAt, source.endAt);
          expect(result.lms, source.lms!.copyWith(sourceCompleted: true));
          expect(result.memo, '새 개인 메모');
          expect(result.category.label, personalCategory.label);
          expect(result.reminderMinutesBeforeList, [10]);
          expect(result.completed, isTrue);
          expect(result.updatedAt.isAfter(source.updatedAt), isTrue);
        } else if (operation == 'import') {
          repository.beforeMerge = () => repository.save(
            original.copyWith(
              memo: '동시에 저장한 개인 메모',
              category: personalCategory,
              colorValue: personalCategory.colorValue,
              completed: true,
              reminderMinutesBeforeList: [15],
            ),
          );
          expect(await commands.importBatch([source]), {source.id});
          final result = (await repository.findById(original.id))!;
          expect(result.title, source.title);
          expect(result.startAt, source.startAt);
          expect(result.lms, source.lms);
          expect(result.memo, '동시에 저장한 개인 메모');
          expect(result.category.label, personalCategory.label);
          expect(result.reminderMinutesBeforeList, [15]);
          expect(result.completed, isTrue);
        } else if (operation == 'completion') {
          repository.beforeMerge = () => repository.save(source);
          await commands.setCompleted(original, true);
          final result = (await repository.findById(original.id))!;
          expect(result.title, source.title);
          expect(result.startAt, source.startAt);
          expect(result.lms, source.lms!.copyWith(manuallyCompleted: true));
          expect(result.completed, isTrue);
        } else if (operation == 'recover-source') {
          await repository.save(original.copyWith(clearLms: true));
          expect(await commands.importBatch([source]), {source.id});
          final result = (await repository.findById(original.id))!;
          expect(result.lms, source.lms);
          expect(result.title, source.title);
          expect(result.memo, original.memo);
          expect(result.isVisibleToOwner('student@example.com'), isTrue);
        } else {
          await settings.saveGoogleAccount(
            const GoogleAccount(email: 'other@example.com'),
          );
          await commands.save(original.copyWith(memo: '잘못된 계정'));
          await commands.setCompleted(original, true);
          await commands.delete(original.id);
          final result = (await repository.findById(original.id))!;
          expect(result.memo, original.memo);
          expect(result.completed, isFalse);
          expect(result.isDeleted, isFalse);
          expect(sync.upsertedIds, isEmpty);
          expect(sync.deletedIds, isEmpty);
          expect(notifications.cancelCalls, 0);
          expect(alarms.cancelCalls, 0);
        }
      },
    );
  }
  for (final operation in [
    'import',
    'delete-after-find',
    'delete-after-write',
  ]) {
    test('stale LMS session stops $operation side effects', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var current = true;
      final repository = _GuardedRepository(
        _event('guarded', EventCategory.basic),
      );
      if (operation == 'import') repository.afterSave = () => current = false;
      if (operation == 'delete-after-find') {
        repository.afterFind = () => current = false;
      }
      if (operation == 'delete-after-write') {
        repository.afterDelete = () => current = false;
      }
      final notifications = _CountingNotificationService();
      final alarms = _CountingAlarmService();
      final sync = _CountingSyncService();
      var refreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        alarmService: alarms,
        syncService: sync,
        onEventsChanged: () async => refreshes++,
      );
      if (operation == 'import') {
        var prepareCalls = 0;
        final ids = await service.importBatch(
          [repository.event, repository.event.copyWith(id: 'next')],
          prepare: (event) async {
            prepareCalls++;
            return event;
          },
          isCurrent: () => current,
        );
        expect(ids, {'guarded'});
        expect(prepareCalls, 1);
      } else {
        await service.delete(repository.event.id, isCurrent: () => current);
        expect(
          repository.deleteCalls,
          operation == 'delete-after-find' ? 0 : 1,
        );
      }
      expect(notifications.scheduleCalls, 0);
      expect(notifications.cancelCalls, 0);
      expect(alarms.scheduleCalls, 0);
      expect(alarms.cancelCalls, 0);
      expect(sync.upsertedIds, isEmpty);
      expect(sync.deletedIds, isEmpty);
      expect(refreshes, 0);
    });
  }
  test(
    'category appearance updates skip OS notification rescheduling',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final previous = EventCategory.basic;
      const updated = EventCategory(
        id: 'basic',
        label: '기본 일정',
        colorValue: 0xff123456,
      );
      final affected = [_event('one', previous), _event('two', previous)];
      final repository = _CategoryUpdateRepository(affected);
      final notifications = _CountingNotificationService();
      final sync = _CountingSyncService();
      var widgetRefreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        syncService: sync,
        onEventsChanged: () async => widgetRefreshes += 1,
      );

      await service.updateCategoryUsage(previous: previous, updated: updated);

      expect(notifications.cancelCalls, 0);
      expect(notifications.scheduleCalls, 0);
      expect(sync.upsertedIds, ['one', 'two']);
      expect(widgetRefreshes, 1);
    },
  );

  test('a failed upload queue does not fail the category update', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final previous = EventCategory.basic;
    const updated = EventCategory(
      id: 'basic',
      label: '기본 일정',
      colorValue: 0xff123456,
    );
    final repository = _CategoryUpdateRepository([_event('one', previous)]);
    var widgetRefreshes = 0;
    final service = EventCommandService(
      repository: repository,
      settingsRepository: SettingsRepository(preferences: preferences),
      notificationService: _CountingNotificationService(),
      syncService: _ThrowingUpsertSyncService(),
      onEventsChanged: () async => widgetRefreshes += 1,
    );

    await service.updateCategoryUsage(previous: previous, updated: updated);

    expect(widgetRefreshes, 1);
  });

  test(
    'Todo completion persists, syncs, and updates scheduled delivery',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _CompletionRepository(
        _event('todo', EventCategory.basic),
      );
      final notifications = _CountingNotificationService();
      final alarms = _CountingAlarmService();
      final sync = _CountingSyncService();
      final analytics = _RecordingAnalytics();
      var widgetRefreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        alarmService: alarms,
        syncService: sync,
        analytics: analytics,
        onEventsChanged: () async => widgetRefreshes += 1,
      );

      await service.setCompleted(repository.event, true);

      expect(repository.event.completed, isTrue);
      expect(repository.event.syncStatus, 'pending');
      expect(notifications.cancelCalls, 1);
      expect(notifications.scheduleCalls, 0);
      expect(alarms.cancelCalls, 1);
      expect(alarms.scheduleCalls, 0);

      await service.setCompleted(repository.event, false);

      expect(repository.event.completed, isFalse);
      expect(notifications.cancelCalls, 2);
      expect(notifications.scheduleCalls, 1);
      expect(alarms.cancelCalls, 2);
      expect(alarms.scheduleCalls, 1);
      expect(sync.upsertedIds, ['todo', 'todo']);
      expect(widgetRefreshes, 2);
      expect(
        analytics.records.map((record) => record.attributes['operation']),
        ['complete', 'uncomplete'],
      );
    },
  );

  test(
    'Todo completion changes only the selected event with a shared title',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = _event(
        'first',
        EventCategory.basic,
      ).copyWith(title: '같은 제목');
      final second = _event(
        'second',
        EventCategory.basic,
      ).copyWith(title: '같은 제목', startAt: DateTime(2026, 7, 30, 9));
      final repository = _MultiCompletionRepository([first, second]);
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: _CountingNotificationService(),
        alarmService: _CountingAlarmService(),
        syncService: _CountingSyncService(),
      );

      await service.setCompleted(first, true);

      expect(repository.events['first']?.completed, isTrue);
      expect(repository.events['second']?.completed, isFalse);
    },
  );

  test(
    'Todo completion detaches only the selected recurring occurrence',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final source = _event('series', EventCategory.basic).copyWith(
        title: '반복 제목',
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          count: 3,
        ),
      );
      final occurrenceStart = source.startAt.add(const Duration(days: 1));
      final occurrence = source.copyWith(
        occurrenceId: 'series@${occurrenceStart.toIso8601String()}',
        startAt: occurrenceStart,
        endAt: occurrenceStart.add(const Duration(hours: 1)),
      );
      final repository = _MultiCompletionRepository([source]);
      final sync = _CountingSyncService();
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: _CountingNotificationService(),
        alarmService: _CountingAlarmService(),
        syncService: sync,
      );

      await service.setCompleted(occurrence, true);

      final updatedSeries = repository.events['series']!;
      final detached = repository.events.values.singleWhere(
        (event) => event.id != 'series',
      );
      expect(updatedSeries.completed, isFalse);
      expect(updatedSeries.recurrence.excludes(occurrenceStart), isTrue);
      expect(detached.title, '반복 제목');
      expect(detached.startAt, occurrenceStart);
      expect(detached.completed, isTrue);
      expect(detached.occurrenceId, isNull);
      expect(detached.recurrence.isRepeating, isFalse);
      expect(sync.upsertedIds, containsAll(<String>['series', detached.id]));
    },
  );

  test('analytics failure never changes an event command result', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _CompletionRepository(
      _event('isolated', EventCategory.basic),
    );
    final service = EventCommandService(
      repository: repository,
      settingsRepository: SettingsRepository(preferences: preferences),
      notificationService: _CountingNotificationService(),
      alarmService: _CountingAlarmService(),
      syncService: _CountingSyncService(),
      analytics: const _ThrowingAnalytics(),
    );

    await service.setCompleted(repository.event, true);
    await Future<void>.delayed(Duration.zero);

    expect(repository.event.completed, isTrue);
  });
}

CalendarEvent _event(String id, EventCategory category) {
  final start = DateTime(2026, 7, 29, 9);
  return CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    allDay: false,
    category: category,
    colorValue: category.colorValue,
    createdAt: start,
    updatedAt: start,
  );
}

class _CategoryUpdateRepository implements EventRepository {
  _CategoryUpdateRepository(this.affected);

  final List<CalendarEvent> affected;

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    return affected
        .map(
          (event) => event.copyWith(
            category: updated,
            colorValue: updated.colorValue,
            updatedAt: updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => const [];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => const [];

  @override
  Future<CalendarEvent?> findById(String id) async => null;

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => const [];

  @override
  Future<void> save(CalendarEvent event) async {}

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {}

  @override
  Future<List<CalendarEvent>> search(String query) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => const Stream.empty();
}

class _CountingNotificationService implements NotificationService {
  var cancelCalls = 0;
  var scheduleCalls = 0;

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    cancelCalls += 1;
  }

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    scheduleCalls += 1;
  }

  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<String> permissionSummary() async => '';

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
}

class _CountingAlarmService implements AlarmService {
  var cancelCalls = 0;
  var scheduleCalls = 0;

  @override
  Future<AlarmAuthorizationState> authorizationState() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<void> cancelAllEventAlarms() async {}

  @override
  Future<void> cancelEventAlarm(String eventId) async => cancelCalls += 1;

  @override
  Future<AlarmAuthorizationState> requestAuthorization() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async =>
      scheduleCalls += 1;
}

class _CompletionRepository implements EventRepository {
  _CompletionRepository(this.event);

  CalendarEvent event;

  @override
  Future<CalendarEvent?> findById(String id) async =>
      event.id == id ? event : null;

  @override
  Future<void> save(CalendarEvent value) async => event = value;

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {
    for (final value in events) {
      event = value;
    }
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => [event];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => [event];

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => [event];

  @override
  Future<List<CalendarEvent>> search(String query) async => [event];

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value([event]);
}

class _GuardedRepository extends _CompletionRepository {
  _GuardedRepository(super.event);
  void Function()? afterFind;
  void Function()? afterSave;
  void Function()? afterDelete;
  int deleteCalls = 0;

  @override
  Future<CalendarEvent?> findById(String id) async {
    final found = await super.findById(id);
    afterFind?.call();
    return found;
  }

  @override
  Future<void> save(CalendarEvent value) async {
    await super.save(value);
    afterSave?.call();
  }

  @override
  Future<void> delete(String eventId) async {
    deleteCalls++;
    afterDelete?.call();
  }
}

class _RacingLmsRepository extends DriftEventRepository {
  _RacingLmsRepository(super.database);
  Future<void> Function()? beforeMerge;

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async {
    final action = beforeMerge;
    beforeMerge = null;
    await action?.call();
    return super.mergeRestoredEventsAtomically(remoteEvents, resolve: resolve);
  }
}

class _MultiCompletionRepository implements EventRepository {
  _MultiCompletionRepository(Iterable<CalendarEvent> events)
    : events = {for (final event in events) event.id: event};

  final Map<String, CalendarEvent> events;

  @override
  Future<CalendarEvent?> findById(String id) async => events[id];

  @override
  Future<void> save(CalendarEvent event) async {
    events[event.id] = event;
  }

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> values) async {
    for (final event in values) {
      events[event.id] = event;
    }
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async =>
      events.values.toList();

  @override
  Future<void> clearAll() async => events.clear();

  @override
  Future<void> delete(String eventId) async => events.remove(eventId);

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => events.values.toList();

  @override
  Future<void> hardDelete(String eventId) async => events.remove(eventId);

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async {
    final staged = Map<String, CalendarEvent>.from(events);
    final changes = <EventRestoreMutation>[];
    for (final incoming in remoteEvents) {
      final previous = staged[incoming.id];
      final current = resolve(previous, incoming);
      staged[current.id] = current;
      changes.add(EventRestoreMutation(previous: previous, current: current));
    }
    events
      ..clear()
      ..addAll(staged);
    return changes;
  }

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async =>
      events.values.toList();

  @override
  Future<List<CalendarEvent>> search(String query) async =>
      events.values.toList();

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value(events.values.toList());
}

class _CountingSyncService implements SyncService {
  @override
  Future<void> queueSettingsBackup() async {}

  final upsertedIds = <String>[];
  final deletedIds = <String>[];

  @override
  Future<void> queueEventDelete(String eventId) async =>
      deletedIds.add(eventId);

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {
    upsertedIds.add(event.id);
  }

  @override
  Future<void> start() async {}
}

class _ThrowingUpsertSyncService extends _CountingSyncService {
  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {
    throw StateError('upload queue unavailable');
  }
}

class _RecordingAnalytics extends NoopProductAnalytics {
  final records = <AnalyticsRecord>[];

  @override
  Future<void> record(AnalyticsRecord record) async => records.add(record);
}

class _ThrowingAnalytics extends NoopProductAnalytics {
  const _ThrowingAnalytics();

  @override
  Future<void> record(AnalyticsRecord record) async {
    throw StateError('analytics unavailable');
  }
}

class _FailingMoveNotifications extends _CountingNotificationService {
  bool fail = true;
  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    if (fail) throw StateError('injected platform scheduling failure');
    await super.scheduleEventReminder(event, allowImmediate: allowImmediate);
  }
}

class _FailingSaveAlarms extends _CountingAlarmService {
  bool fail = false;
  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async {
    if (fail) throw StateError('injected alarm failure');
    await super.scheduleEventAlarm(event);
  }
}

class _FailingSaveSync extends _CountingSyncService {
  bool fail = false;
  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {
    if (fail) throw StateError('injected sync failure');
    await super.queueEventUpsert(event);
  }
}
