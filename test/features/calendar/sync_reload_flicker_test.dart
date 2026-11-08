import 'dart:async';

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAuth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

class _CountingRepository extends Fake implements EventRepository {
  _CountingRepository(this.events);

  final List<CalendarEvent> events;
  var subscriptions = 0;

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(DateTime start, DateTime end) {
    subscriptions++;
    return Stream.value(events);
  }
}

class _Commands extends Fake implements EventCommandService {}

class _NoSession extends LmsWebSession {
  _NoSession(String owner, String school)
    : super(ownerId: owner, schoolId: school);
}

/// Stands in for LMS progress notifications sent during a sync.
class _NotifyingLmsController extends LmsController {
  _NotifyingLmsController({required super.settings, required super.repository})
    : super(
        commands: _Commands(),
        createSession: (owner, school) => _NoSession(owner, school),
      );

  void progress() => notifyListeners();
}

CalendarEvent _event(DateTime day) => CalendarEvent(
  id: 'sync-flicker-event',
  title: '깜빡임 확인 일정',
  startAt: DateTime(day.year, day.month, day.day, 10),
  endAt: DateTime(day.year, day.month, day.day, 11),
  allDay: false,
  category: EventCategory.basic,
  colorValue: EventCategory.basic.colorValue,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _reloadTick = StateProvider<int>((_) => 0);

// #790: syncs and LMS notifications used to recreate the range streams and
// show the loading branch, so events vanished and the view jumped.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('LMS progress notifications keep the range stream and its data', () async {
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final repository = _CountingRepository([_event(day)]);
    final lms = _NotifyingLmsController(
      settings: settings,
      repository: repository,
    );
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        appSettingsProvider.overrideWith((_) => settings.load()),
        eventRepositoryProvider.overrideWithValue(repository),
        lmsControllerProvider.overrideWith((_) => lms),
      ],
    );
    addTearDown(container.dispose);
    final provider = eventsInRangeProvider(
      CalendarRange(day, day.add(const Duration(days: 1))),
    );
    final states = <AsyncValue<List<CalendarEvent>>>[];
    container.listen(provider, (_, next) => states.add(next));
    await container.read(provider.future);
    states.clear();

    for (var i = 0; i < 5; i++) {
      lms.progress();
      await Future<void>.delayed(Duration.zero);
    }

    expect(repository.subscriptions, 1);
    expect(states, isEmpty);
    expect(
      container.read(provider).value?.map((event) => event.id),
      contains('sync-flicker-event'),
    );
  });

  Future<ProviderContainer> pumpCalendar(
    WidgetTester tester,
    StreamController<List<CalendarEvent>> reloads,
    List<CalendarEvent> events,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({'defaultCalendarView': 'month'});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.save(
      settings.load().copyWith(
        monthNavigationMode: MonthNavigationMode.vertical,
      ),
    );
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily.test',
      version: '4.1.1',
      buildNumber: '411',
      buildSignature: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          appSettingsProvider.overrideWith((_) => settings.load()),
          timetableStoreProvider.overrideWithValue(settings.timetableStore),
          // A dependency change makes Riverpod reload the range; the new
          // stream answers only when the test says so.
          eventsInRangeProvider.overrideWith(
            (ref, _) => ref.watch(_reloadTick) == 0
                ? Stream.value(events)
                : reloads.stream,
          ),
          googleDriveAuthServiceProvider.overrideWithValue(_SilentAuth()),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: DailyTheme.light(),
          home: const MonthCalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(MonthCalendarPage)),
    );
  }

  testWidgets(
    'month view keeps its events and scroll position while ranges reload',
    (tester) async {
      final reloads = StreamController<List<CalendarEvent>>.broadcast();
      addTearDown(reloads.close);
      final today = DateTime.now();
      final events = [_event(today)];
      final container = await pumpCalendar(tester, reloads, events);

      final list = find.byKey(const ValueKey('continuous-month-scroll'));
      await tester.drag(list, const Offset(0, -120));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      final offset = scrollable.position.pixels;
      final title = find.text('깜빡임 확인 일정', findRichText: true, skipOffstage: false);
      final titlesBefore = title.evaluate().length;
      expect(titlesBefore, greaterThan(0));

      container.read(_reloadTick.notifier).state++;
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(title.evaluate().length, titlesBefore);
      expect(scrollable.position.pixels, offset);

      reloads.add(events);
      await tester.pumpAndSettle();
      expect(title.evaluate().length, titlesBefore);
      expect(scrollable.position.pixels, offset);
    },
  );

  testWidgets('week view does not show the loading spinner on reload', (
    tester,
  ) async {
    final reloads = StreamController<List<CalendarEvent>>.broadcast();
    addTearDown(reloads.close);
    final today = DateTime.now();
    final container = await pumpCalendar(tester, reloads, [_event(today)]);
    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.week;
    await tester.pumpAndSettle();
    final title = find.text('깜빡임 확인 일정', findRichText: true, skipOffstage: false);
    expect(title, findsWidgets);

    container.read(_reloadTick.notifier).state++;
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(title, findsWidgets);
  });
}
